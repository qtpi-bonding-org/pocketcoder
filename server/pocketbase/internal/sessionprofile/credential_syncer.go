/*
PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
Copyright (C) 2026 Qtpi Bonding LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

package sessionprofile

import (
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"net"
	"sync"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/dockerapi"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/harnessvolume"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/hooks"
)

type CredentialSyncer interface {
	Sync(ctx context.Context, app core.App, instance *core.Record, providerRec *core.Record, credential string) error
}

type NoopCredentialSyncer struct{}

func (NoopCredentialSyncer) Sync(context.Context, core.App, *core.Record, *core.Record, string) error {
	return nil
}

type OpencodeAuthFileSyncer struct{}

var syncLocks sync.Map // instance id -> *sync.Mutex

func lockForInstance(instanceID string) *sync.Mutex {
	v, _ := syncLocks.LoadOrStore(instanceID, &sync.Mutex{})
	return v.(*sync.Mutex)
}

func credentialHash(providerID, credential string) string {
	sum := sha256.Sum256([]byte(providerID + ":" + credential))
	return hex.EncodeToString(sum[:])
}

func (OpencodeAuthFileSyncer) Sync(ctx context.Context, app core.App, instance *core.Record, providerRec *core.Record, credential string) error {
	if credential == "" || providerRec == nil {
		return nil
	}
	providerID := providerRec.GetString("provider_id")
	hash := credentialHash(providerID, credential)
	lock := lockForInstance(instance.Id)
	lock.Lock()
	defer lock.Unlock()

	fresh, err := app.FindRecordById("harness_instances", instance.Id)
	if err != nil {
		return fmt.Errorf("re-fetch harness instance: %w", err)
	}
	existing := map[string]string{}
	_ = fresh.UnmarshalJSONField("synced_credentials", &existing)
	if existing[providerID] == hash {
		return nil
	}

	client := dockerapi.New()
	volumeBase, _, err := hooks.ResolveWorkspaceVolumeAndNetwork(ctx, client)
	if err != nil {
		return fmt.Errorf("resolve workspace volume: %w", err)
	}
	volumes, err := harnessvolume.Resolve(volumeBase, fresh.GetString("user"), "opencode", fresh.GetString("oauth_account"))
	if err != nil {
		return fmt.Errorf("resolve harness volumes: %w", err)
	}
	harnessRec, err := app.FindRecordById("harnesses", fresh.GetString("harness"))
	if err != nil {
		return fmt.Errorf("resolve harness image: %w", err)
	}
	image := harnessRec.GetString("container_image")
	if image == "" {
		return fmt.Errorf("resolve harness image: empty container_image")
	}
	if err := writeOpencodeAuthFile(ctx, client, image, volumes.Auth, providerID, credential); err != nil {
		return fmt.Errorf("write opencode auth file: %w", err)
	}
	// opencode re-syncs its model catalog (~4.5MB) from scratch the first
	// time anything asks for a given provider's models under a fresh
	// HOME -- warming it here, once per credential, writes the result to
	// volumes.Auth (persistent, survives container restarts) so the
	// coordinator's later SetSessionConfigOption("model", ...) doesn't
	// race a catalog sync that's still in flight.
	if err := warmOpencodeModelCache(ctx, client, image, volumes.Auth, providerID); err != nil {
		return fmt.Errorf("warm opencode model cache: %w", err)
	}
	if err := hooks.RestartContainer(fresh.GetString("container_name"), 30*time.Second); err != nil {
		return fmt.Errorf("restart opencode container: %w", err)
	}
	// RestartContainer only waits for Docker to accept the restart request,
	// not for the process inside to re-bind its port -- the coordinator's
	// very next dial otherwise races a container that is still booting.
	var launch struct {
		Port int `json:"port"`
	}
	if err := harnessRec.UnmarshalJSONField("launch_template", &launch); err != nil {
		return fmt.Errorf("parse launch_template.port: %w", err)
	}
	if err := waitForPort(ctx, fresh.GetString("container_name"), launch.Port, 20*time.Second); err != nil {
		return fmt.Errorf("opencode container did not come back up after restart: %w", err)
	}
	existing[providerID] = hash
	return markCredentialSynced(app, instance.Id, existing)
}

// markCredentialSynced re-fetches instanceID immediately before saving:
// ProvisionHarnessInstance can concurrently set acp_endpoint on this same
// row while the caller's slow Docker I/O is in flight, and saving a
// snapshot fetched before that I/O started would silently clobber it back
// to empty.
func markCredentialSynced(app core.App, instanceID string, syncedCredentials map[string]string) error {
	current, err := app.FindRecordById("harness_instances", instanceID)
	if err != nil {
		return fmt.Errorf("re-fetch harness instance before save: %w", err)
	}
	current.Set("synced_credentials", syncedCredentials)
	if err := app.Save(current); err != nil {
		return fmt.Errorf("save synced_credentials: %w", err)
	}
	return nil
}

func waitForPort(ctx context.Context, host string, port int, timeout time.Duration) error {
	deadline := time.Now().Add(timeout)
	addr := fmt.Sprintf("%s:%d", host, port)
	var lastErr error
	for time.Now().Before(deadline) {
		conn, err := (&net.Dialer{Timeout: time.Second}).DialContext(ctx, "tcp", addr)
		if err == nil {
			conn.Close()
			return nil
		}
		lastErr = err
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(300 * time.Millisecond):
		}
	}
	return fmt.Errorf("timed out waiting for %s: %w", addr, lastErr)
}

// warmOpencodeModelCache runs `opencode models <provider>` once in a
// throwaway helper container against the same auth-home volume the real
// harness container mounts, so its ~/.cache/opencode/models.json is already
// populated by the time any session dials in. Best-effort by design: a
// slow/failed warm here just means the coordinator's own setModelWithRetry
// falls back to retrying live, not a fatal sync error.
func warmOpencodeModelCache(ctx context.Context, client *dockerapi.Client, image, authVolume, providerID string) error {
	const mountPath = harnessvolume.AuthHomeMount
	containerName := "pc-opencode-model-warm-" + providerID + "-" + fmt.Sprint(time.Now().UnixNano())
	_, err := client.Create(ctx, containerName, dockerapi.CreateSpec{
		Image: image, Entrypoint: []string{"sh", "-lc"}, Cmd: []string{"opencode models " + providerID + " >/dev/null 2>&1 || true"},
		Env:         []string{"HOME=" + mountPath},
		VolumeBinds: []string{authVolume + ":" + mountPath}, RestartPolicy: "no",
	})
	if err != nil {
		return err
	}
	if err := client.Start(ctx, containerName); err != nil {
		_ = client.Remove(ctx, containerName)
		return err
	}
	defer func() { _ = client.Remove(ctx, containerName) }()
	deadline := time.Now().Add(60 * time.Second)
	for time.Now().Before(deadline) {
		insp, err := client.Inspect(ctx, containerName)
		if err != nil {
			return fmt.Errorf("inspect model-warm helper container: %w", err)
		}
		if !insp.State.Running {
			return nil
		}
		time.Sleep(300 * time.Millisecond)
	}
	return fmt.Errorf("model-warm helper container did not exit within 60s")
}

func selectCredentialSyncer(harness *core.Record) CredentialSyncer {
	if harness.GetString("cli_id") == "opencode" {
		return OpencodeAuthFileSyncer{}
	}
	return NoopCredentialSyncer{}
}

func writeOpencodeAuthFile(ctx context.Context, client *dockerapi.Client, image, authVolume, providerID, credential string) error {
	const mountPath = harnessvolume.AuthHomeMount
	const authFile = mountPath + "/.local/share/opencode/auth.json"
	credB64 := base64.StdEncoding.EncodeToString([]byte(credential))
	script := `node -e '
const fs = require("fs");
const path = process.env.PC_AUTH_FILE;
const providerID = process.env.PC_PROVIDER_ID;
const key = Buffer.from(process.env.PC_CRED_B64, "base64").toString("utf8");
let data = {};
try { data = JSON.parse(fs.readFileSync(path, "utf8")); } catch (e) {}
data[providerID] = { type: "api", key };
fs.mkdirSync(require("path").dirname(path), { recursive: true });
fs.writeFileSync(path, JSON.stringify(data), { mode: 0o600 });
fs.chmodSync(path, 0o600);
'`
	containerName := "pc-opencode-auth-sync-" + providerID + "-" + fmt.Sprint(time.Now().UnixNano())
	_, err := client.Create(ctx, containerName, dockerapi.CreateSpec{
		Image: image, Entrypoint: []string{"sh", "-lc"}, Cmd: []string{script},
		Env:         []string{"PC_AUTH_FILE=" + authFile, "PC_PROVIDER_ID=" + providerID, "PC_CRED_B64=" + credB64},
		VolumeBinds: []string{authVolume + ":" + mountPath}, RestartPolicy: "no",
	})
	if err != nil {
		return err
	}
	if err := client.Start(ctx, containerName); err != nil {
		_ = client.Remove(ctx, containerName)
		return err
	}
	defer func() { _ = client.Remove(ctx, containerName) }()
	deadline := time.Now().Add(15 * time.Second)
	for time.Now().Before(deadline) {
		insp, err := client.Inspect(ctx, containerName)
		if err != nil {
			return fmt.Errorf("inspect helper container: %w", err)
		}
		if !insp.State.Running {
			if insp.State.ExitCode != 0 {
				return fmt.Errorf("auth-file helper container exited %d", insp.State.ExitCode)
			}
			return nil
		}
		time.Sleep(300 * time.Millisecond)
	}
	return fmt.Errorf("auth-file helper container did not exit within 15s")
}
