package hooks

import (
	"archive/tar"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"path"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/agent/pocoprompt"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/dockerapi"
)

// archiveCopier is intentionally smaller than dockerapi.Client so the
// materializer remains unit-testable without a Docker daemon.
type archiveCopier interface {
	CopyArchive(context.Context, string, string, io.Reader) error
}

// MaterializeUserHarnessFiles copies PocketBase-owned skills and the user's
// default prompt into a running harness container. The container's workspace
// is already a user-scoped Docker volume; Docker's archive API writes into it
// without granting PocketBase exec access.
func MaterializeUserHarnessFiles(ctx context.Context, app core.App, client archiveCopier, instance *core.Record) error {
	if instance == nil || instance.GetString("user") == "" || instance.GetString("container_name") == "" {
		return fmt.Errorf("materialization requires a user-owned harness instance")
	}
	userID := instance.GetString("user")
	files := map[string]string{}
	body := pocoprompt.Default

	skills, err := app.FindRecordsByFilter("skills", "active = true && (user = {:user} || is_system = true)", "name", 0, 0, map[string]any{"user": userID})
	if err != nil {
		return fmt.Errorf("query skills: %w", err)
	}
	for _, skill := range skills {
		name := skill.GetString("name")
		if !validSkillName(name) {
			return fmt.Errorf("skill %q has invalid name", name)
		}
		content := skill.GetString("content")
		root, err := skillMaterializationRoot(skill)
		if err != nil {
			return err
		}
		files[path.Join(root, ".agents", "skills", name, "SKILL.md")] = content
		files[path.Join(root, ".claude", "skills", name, "SKILL.md")] = content
	}

	profiles, err := app.FindRecordsByFilter("agent_profiles", "is_default = true && user = {:user}", "name", 0, 0, map[string]any{"user": userID})
	if err != nil {
		return fmt.Errorf("query default agent profile: %w", err)
	}
	if len(profiles) == 0 {
		profiles, err = app.FindRecordsByFilter("agent_profiles", "is_default = true && is_system = true", "name", 0, 0)
		if err != nil {
			return fmt.Errorf("query system default agent profile: %w", err)
		}
	}
	if len(profiles) > 0 {
		promptID := profiles[0].GetString("system_prompt")
		if promptID != "" {
			prompt, promptErr := app.FindRecordById("prompts", promptID)
			if promptErr != nil {
				return fmt.Errorf("resolve prompt %s: %w", promptID, promptErr)
			}
			if ownerID := prompt.GetString("user"); ownerID != "" && ownerID != userID && !prompt.GetBool("is_system") {
				return fmt.Errorf("prompt %s does not belong to user", promptID)
			}
			if promptBody := strings.TrimSpace(prompt.GetString("body")); promptBody != "" {
				body = promptBody
			}
		}
	}
	files["AGENTS.md"] = body
	files["CLAUDE.md"] = body
	files[".goosehints"] = body
	managed := make([]string, 0, len(files))
	for name := range files {
		managed = append(managed, name)
	}
	sort.Strings(managed)
	manifest, err := json.Marshal(map[string]any{"schemaVersion": 1, "files": managed})
	if err != nil {
		return fmt.Errorf("encode managed-file manifest: %w", err)
	}
	files[path.Join(".pocketcoder", "managed-agent-files.json")] = string(manifest)

	archive, err := tarArchive(files)
	if err != nil {
		return err
	}
	if err := client.CopyArchive(ctx, instance.GetString("container_name"), "/workspace", archive); err != nil {
		return fmt.Errorf("materialize harness files: %w", err)
	}
	return nil
}

func skillMaterializationRoot(skill *core.Record) (string, error) {
	var metadata map[string]any
	_ = skill.UnmarshalJSONField("metadata", &metadata)
	projectDir, _ := metadata["projectDir"].(string)
	projectDir = strings.TrimSpace(projectDir)
	if projectDir == "" || filepath.Clean(projectDir) == workspaceRoot {
		return "", nil
	}
	clean := filepath.Clean(projectDir)
	if !strings.HasPrefix(clean, workspaceRoot+string(filepath.Separator)) {
		return "", fmt.Errorf("skill %q projectDir is outside %s", skill.GetString("name"), workspaceRoot)
	}
	return filepath.ToSlash(strings.TrimPrefix(clean, workspaceRoot+string(filepath.Separator))), nil
}

func validSkillName(name string) bool {
	if len(name) == 0 || len(name) > 64 || strings.HasPrefix(name, "-") || strings.HasSuffix(name, "-") || strings.Contains(name, "--") {
		return false
	}
	for _, r := range name {
		if (r < 'a' || r > 'z') && (r < '0' || r > '9') && r != '-' {
			return false
		}
	}
	return true
}

func tarArchive(files map[string]string) (*bytes.Reader, error) {
	var buf bytes.Buffer
	tw := tar.NewWriter(&buf)
	for name, content := range files {
		if name == "" || path.IsAbs(name) || strings.HasPrefix(path.Clean(name), "../") {
			return nil, fmt.Errorf("invalid materialized path %q", name)
		}
		data := []byte(content)
		if err := tw.WriteHeader(&tar.Header{Name: name, Mode: 0o644, Size: int64(len(data))}); err != nil {
			return nil, fmt.Errorf("write archive header %s: %w", name, err)
		}
		if _, err := tw.Write(data); err != nil {
			return nil, fmt.Errorf("write archive file %s: %w", name, err)
		}
	}
	if err := tw.Close(); err != nil {
		return nil, fmt.Errorf("close archive: %w", err)
	}
	return bytes.NewReader(buf.Bytes()), nil
}

var _ archiveCopier = (*dockerapi.Client)(nil)

// RegisterAgentFileHooks refreshes every running harness for a user whenever
// PocketBase-owned prompt, profile, or skill content changes.
func RegisterAgentFileHooks(app core.App) {
	app.OnRecordCreateRequest("skills").BindFunc(func(e *core.RecordRequestEvent) error {
		if e.Auth == nil || e.Auth.Id == "" {
			return fmt.Errorf("authentication required")
		}
		e.Record.Set("user", e.Auth.Id)
		e.Record.Set("is_system", false)
		e.Record.Set("active", true)
		return e.Next()
	})
	app.OnRecordUpdateRequest("skills").BindFunc(func(e *core.RecordRequestEvent) error {
		if e.Auth == nil || e.Auth.Id == "" || e.Record.Original() == nil || e.Record.Original().GetString("user") != e.Auth.Id {
			return fmt.Errorf("skill must belong to the authenticated user")
		}
		e.Record.Set("user", e.Record.Original().Get("user"))
		e.Record.Set("is_system", e.Record.Original().Get("is_system"))
		return e.Next()
	})
	validateSkill := func(e *core.RecordEvent) error {
		if !validSkillName(e.Record.GetString("name")) {
			return fmt.Errorf("invalid skill name")
		}
		if !e.Record.GetBool("is_system") && e.Record.GetString("user") == "" {
			return fmt.Errorf("skill owner is required")
		}
		if strings.TrimSpace(e.Record.GetString("description")) == "" || strings.TrimSpace(e.Record.GetString("content")) == "" {
			return fmt.Errorf("skill description and content are required")
		}
		if _, err := skillMaterializationRoot(e.Record); err != nil {
			return err
		}
		return e.Next()
	}
	app.OnRecordCreate("skills").BindFunc(validateSkill)
	app.OnRecordUpdate("skills").BindFunc(validateSkill)

	handler := func(e *core.RecordEvent) error {
		userID := e.Record.GetString("user")
		filter := "status = 'running'"
		params := map[string]any{}
		if userID != "" {
			filter = "user = {:user} && status = 'running'"
			params["user"] = userID
		}
		instances, err := app.FindRecordsByFilter("harness_instances", filter, "", 0, 0, params)
		if err != nil {
			return e.Next()
		}
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()
		client := dockerapi.New()
		materializedUsers := map[string]bool{}
		for _, instance := range instances {
			instanceUser := instance.GetString("user")
			if materializedUsers[instanceUser] {
				continue
			}
			if err := MaterializeUserHarnessFiles(ctx, app, client, instance); err != nil {
				// A stale or stopped harness must not make a successful PocketBase
				// record update fail. The next provisioning/start refresh retries.
				continue
			}
			// All of a user's sibling harness containers mount the same workspace,
			// so one successful copy refreshes every harness without repeated work.
			materializedUsers[instanceUser] = true
		}
		return e.Next()
	}
	for _, collection := range []string{"prompts", "agent_profiles", "skills"} {
		registerCrudHooks(app, collection, handler)
	}
}
