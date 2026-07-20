package api

import (
	"log"

	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/coordinator"
)

// stdioMcp is the stored acp_mcp_servers JSON shape (spec §5.1). Only stdio is
// supported today; http/sse/acp entries are skipped + logged.
type stdioMcp struct {
	Type    string            `json:"type"`
	Name    string            `json:"name"`
	Command string            `json:"command"`
	Args    []string          `json:"args"`
	Env     map[string]string `json:"env"`
}

// buildSessionProfile resolves a chat's agent definition (poco_config, or the
// default per §5.2) into a coordinator.SessionProfile: model/provider,
// system prompt, workspace cwd/additional directories, per-chat MCP servers
// (stdio only), and mode.
func buildSessionProfile(app core.App, chatID string) (coordinator.SessionProfile, error) {
	var p coordinator.SessionProfile

	chat, err := app.FindRecordById("chats", chatID)
	if err != nil {
		return p, err
	}

	// Resolve the agent definition: chat's poco_config, else the default (§5.2).
	pocoID := chat.GetString("poco_config")
	var poco *core.Record
	if pocoID != "" {
		if poco, err = app.FindRecordById("poco_configs", pocoID); err != nil {
			return p, err
		}
	} else if poco, err = defaultPocoConfigAPI(app); err != nil {
		return p, err
	}
	if poco == nil {
		// No definition at all: minimal floor (spec §5.2). Coordinator falls
		// back to c.config.Workspace when Cwd == "".
		p.Mode = acpsdk.SessionModeId("approve")
		return p, nil
	}

	// Model: chat.harness_model_override wins, else the poco's harness_model.
	// (Per-chat model is INERT today — spec §4.1 — but resolved for forward-compat.)
	hmID := chat.GetString("harness_model_override")
	if hmID == "" {
		hmID = poco.GetString("harness_model")
	}
	if hmID != "" {
		if hm, err := app.FindRecordById("harness_models", hmID); err == nil {
			p.Model = hm.GetString("harness_model_id")
			if m, err := app.FindRecordById("models", hm.GetString("model")); err == nil {
				p.Provider = m.GetString("provider")
			}
		}
	}
	if spID := poco.GetString("system_prompt"); spID != "" {
		if sp, err := app.FindRecordById("prompts", spID); err == nil {
			p.Instructions = sp.GetString("body")
		}
	}
	if mode := poco.GetString("mode"); mode != "" {
		p.Mode = acpsdk.SessionModeId(mode)
	} else {
		p.Mode = acpsdk.SessionModeId("approve")
	}

	// workspace_folders (JSON array) -> Cwd (first) + AdditionalDirectories (§S4).
	var folders []string
	_ = poco.UnmarshalJSONField("workspace_folders", &folders)
	if len(folders) > 0 {
		p.Cwd = folders[0]
		p.AdditionalDirectories = folders[1:]
	}

	// acp_mcp_servers (JSON array) -> []acpsdk.McpServer, stdio only (§5.1).
	var raw []stdioMcp
	_ = poco.UnmarshalJSONField("acp_mcp_servers", &raw)
	for _, m := range raw {
		if m.Type != "" && m.Type != "stdio" {
			log.Printf("[Profile] skipping non-stdio MCP server %q (type=%s) — unsupported today", m.Name, m.Type)
			continue
		}
		env := make([]acpsdk.EnvVariable, 0, len(m.Env))
		for k, v := range m.Env {
			env = append(env, acpsdk.EnvVariable{Name: k, Value: v})
		}
		p.McpServers = append(p.McpServers, acpsdk.McpServer{
			Stdio: &acpsdk.McpServerStdio{Name: m.Name, Command: m.Command, Args: m.Args, Env: env},
		})
	}
	return p, nil
}

// defaultPocoConfigAPI mirrors the hook's §5.2 tie-break (is_default=true,
// oldest on multiple, nil on none). Kept separate from the hooks package to
// avoid a hooks→api import; the logic is small and identical.
func defaultPocoConfigAPI(app core.App) (*core.Record, error) {
	recs, err := app.FindRecordsByFilter("poco_configs", "is_default = true", "created", 0, 0)
	if err != nil {
		return nil, err
	}
	if len(recs) == 0 {
		return nil, nil
	}
	if len(recs) > 1 {
		log.Printf("[Profile] %d poco_configs marked is_default; using oldest %q", len(recs), recs[0].GetString("name"))
	}
	return recs[0], nil
}
