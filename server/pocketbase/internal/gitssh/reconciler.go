package gitssh

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"sort"
	"strings"
	"sync"

	"github.com/pocketbase/pocketbase/core"
)

// Materializer is intentionally narrow: the reconciler owns desired-state
// decisions while the Docker-backed implementation owns secret-volume writes.
type Materializer interface {
	Materialize(context.Context, string, Manifest) error
}

type Manifest struct {
	Generation string
	Config     []byte
	KnownHosts []byte
	Keys       map[string][]byte
}

type Reconciler struct {
	Materializer Materializer
}

func (r *Reconciler) ReconcileUser(ctx context.Context, app core.App, userID string) error {
	if err := r.linkGeneratedDeployCredentials(app, userID); err != nil {
		return fmt.Errorf("link generated-deploy credentials: %w", err)
	}

	newKeys, err := r.generateKeysForPendingCredentials(app, userID)
	if err != nil {
		return fmt.Errorf("generate keys: %w", err)
	}

	if err := r.pinCustomHostKeys(ctx, app, userID); err != nil {
		return fmt.Errorf("pin custom host keys: %w", err)
	}

	return r.materialize(ctx, app, userID, newKeys)
}

func (r *Reconciler) linkGeneratedDeployCredentials(app core.App, userID string) error {
	rows, err := app.FindRecordsByFilter("git_repository_access",
		"user = {:user} && credential_mode = 'generated_deploy' && credential = ''",
		"", 0, 0, map[string]any{"user": userID})
	if err != nil {
		return err
	}
	credColl, err := app.FindCollectionByNameOrId("git_ssh_credentials")
	if err != nil {
		return err
	}
	for _, access := range rows {
		cred := core.NewRecord(credColl)
		cred.Set("user", userID)
		cred.Set("label", fmt.Sprintf("%s/%s deploy key", access.GetString("provider"), access.GetString("repository")))
		cred.Set("kind", "deploy")
		cred.Set("source", "generated")
		cred.Set("algorithm", "ed25519")
		cred.Set("status", "pending")
		if err := app.Save(cred); err != nil {
			return fmt.Errorf("create deploy credential for access %s: %w", access.Id, err)
		}
		access.Set("credential", cred.Id)
		if err := app.Save(access); err != nil {
			return fmt.Errorf("link credential to access %s: %w", access.Id, err)
		}
	}
	return nil
}

func (r *Reconciler) generateKeysForPendingCredentials(app core.App, userID string) (map[string][]byte, error) {
	rows, err := app.FindRecordsByFilter("git_ssh_credentials",
		"user = {:user} && status = 'pending'",
		"", 0, 0, map[string]any{"user": userID})
	if err != nil {
		return nil, err
	}
	newKeys := map[string][]byte{}
	for _, cred := range rows {
		if cred.GetString("source") != "generated" {
			cred.Set("status", "error")
			cred.Set("last_error", "imported credentials are not yet supported")
			if err := app.Save(cred); err != nil {
				return nil, fmt.Errorf("mark credential %s unsupported: %w", cred.Id, err)
			}
			continue
		}
		key, err := GenerateKey("pocketcoder-" + cred.Id)
		if err != nil {
			cred.Set("status", "error")
			cred.Set("last_error", err.Error())
			_ = app.Save(cred)
			continue
		}
		cred.Set("public_key", key.Public)
		cred.Set("fingerprint", key.Fingerprint)
		cred.Set("status", "ready")
		cred.Set("last_error", "")
		if err := app.Save(cred); err != nil {
			return nil, fmt.Errorf("save generated credential %s: %w", cred.Id, err)
		}
		newKeys[cred.Id] = key.Private
	}
	return newKeys, nil
}

// Never re-probes an already-pinned row: a transient network blip must not
// look like a changed/MITM host key.
func (r *Reconciler) pinCustomHostKeys(ctx context.Context, app core.App, userID string) error {
	rows, err := app.FindRecordsByFilter("git_repository_access",
		"user = {:user} && provider = 'custom' && known_host_key = '' && status != 'error'",
		"", 0, 0, map[string]any{"user": userID})
	if err != nil {
		return err
	}
	for _, access := range rows {
		host := access.GetString("host")
		port := access.GetInt("port")
		if port == 0 {
			port = 22
		}
		if host == "" {
			access.Set("status", "error")
			access.Set("last_error", "custom provider requires a host")
			_ = app.Save(access)
			continue
		}
		line, err := ProbeHostKey(ctx, host, port)
		if err != nil {
			access.Set("status", "error")
			access.Set("last_error", "could not verify host key: "+err.Error())
			_ = app.Save(access)
			continue
		}
		access.Set("known_host_key", line)
		access.Set("last_error", "")
		if err := app.Save(access); err != nil {
			return fmt.Errorf("pin host key for access %s: %w", access.Id, err)
		}
	}
	return nil
}

func (r *Reconciler) materialize(ctx context.Context, app core.App, userID string, newKeys map[string][]byte) error {
	rows, err := app.FindRecordsByFilter("git_repository_access",
		"user = {:user} && credential != '' && status != 'error'",
		"", 0, 0, map[string]any{"user": userID})
	if err != nil {
		return err
	}

	var accessList []Access
	knownHostsSeen := map[string]bool{}
	var knownHosts []string
	for _, access := range rows {
		cred, err := app.FindRecordById("git_ssh_credentials", access.GetString("credential"))
		if err != nil || cred.GetString("status") != "ready" {
			continue // still pending on its credential; next pass will pick it up
		}
		provider := access.GetString("provider")
		a := Access{
			ID:           access.Id,
			Provider:     provider,
			Repository:   access.GetString("repository"),
			CredentialID: cred.Id,
			Host:         access.GetString("host"),
			Port:         access.GetInt("port"),
		}
		accessList = append(accessList, a)

		if provider == CustomProviderID {
			if line := access.GetString("known_host_key"); line != "" && !knownHostsSeen[line] {
				knownHostsSeen[line] = true
				knownHosts = append(knownHosts, line)
			}
		} else if !knownHostsSeen[provider] {
			knownHostsSeen[provider] = true
			knownHosts = append(knownHosts, BuiltinKnownHosts(provider)...)
		}

		if access.GetString("status") != "ready" {
			access.Set("status", "ready")
			access.Set("last_error", "")
			if err := app.Save(access); err != nil {
				return fmt.Errorf("mark access %s ready: %w", access.Id, err)
			}
		}
	}

	if r.Materializer == nil {
		return nil
	}

	config, err := RenderConfig(accessList)
	if err != nil {
		return fmt.Errorf("render ssh config: %w", err)
	}
	sort.Strings(knownHosts)

	manifest := Manifest{
		Generation: generationHash(config, knownHosts, newKeys),
		Config:     []byte(config),
		KnownHosts: []byte(strings.Join(knownHosts, "\n") + "\n"),
		Keys:       newKeys,
	}
	if err := r.Materializer.Materialize(ctx, userID, manifest); err != nil {
		return fmt.Errorf("materialize: %w", err)
	}

	for credID := range newKeys {
		cred, err := app.FindRecordById("git_ssh_credentials", credID)
		if err != nil {
			continue
		}
		cred.Set("materialized_generation", manifest.Generation)
		_ = app.Save(cred)
	}
	return nil
}

func generationHash(config string, knownHosts []string, newKeys map[string][]byte) string {
	h := sha256.New()
	h.Write([]byte(config))
	for _, line := range knownHosts {
		h.Write([]byte(line))
	}
	ids := make([]string, 0, len(newKeys))
	for id := range newKeys {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	for _, id := range ids {
		h.Write([]byte(id))
	}
	return hex.EncodeToString(h.Sum(nil))[:16]
}

// Queue coalesces rapid CRUD notifications by full PocketBase user id.
type Queue struct {
	mu      sync.Mutex
	pending map[string]struct{}
}

func NewQueue() *Queue { return &Queue{pending: map[string]struct{}{}} }

func (q *Queue) Enqueue(userID string) {
	if userID == "" {
		return
	}
	q.mu.Lock()
	q.pending[userID] = struct{}{}
	q.mu.Unlock()
}

func (q *Queue) Drain() []string {
	q.mu.Lock()
	defer q.mu.Unlock()
	ids := make([]string, 0, len(q.pending))
	for id := range q.pending {
		ids = append(ids, id)
		delete(q.pending, id)
	}
	return ids
}
