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

// @pocketcoder-core: LLM Hooks. Handles API key persistence and OpenCode container restart.
package hooks

import (
	"context"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/pocketbase/pocketbase/core"
)

const (
	llmEnvPath         = "/workspace/.opencode/llm.env"
	llmEnvPathShared   = "/llm_keys/llm.env"
	openCodeContainer  = "pocketcoder-opencode"
)

// RegisterLlmHooks registers hooks on the llm_keys collection.
// When a user saves, updates, or deletes an API key, this hook
// re-renders the llm.env file and restarts the OpenCode container.
func RegisterLlmHooks(app core.App) {
	log.Println("🔑 [LLM] Registering LLM key hooks...")

	handleLlmKeysChange := func(e *core.RecordEvent) error {
		log.Println("🔑 [LLM] LLM keys changed, re-rendering llm.env...")
		if err := renderLlmEnv(app); err != nil {
			log.Printf("❌ [LLM] Failed to render llm.env: %v", err)
			return e.Next()
		}
		if err := restartOpenCode(); err != nil {
			log.Printf("❌ [LLM] Failed to restart OpenCode: %v", err)
		}
		return e.Next()
	}

	app.OnRecordAfterCreateSuccess("llm_keys").BindFunc(handleLlmKeysChange)
	app.OnRecordAfterUpdateSuccess("llm_keys").BindFunc(handleLlmKeysChange)
	app.OnRecordAfterDeleteSuccess("llm_keys").BindFunc(handleLlmKeysChange)

	// Initial render on startup
	app.OnServe().BindFunc(func(e *core.ServeEvent) error {
		log.Println("🔑 [LLM] Performing initial llm.env render...")
		if err := renderLlmEnv(app); err != nil {
			log.Printf("⚠️ [LLM] Initial llm.env render failed: %v", err)
		} else {
			log.Println("✅ [LLM] Initial llm.env rendered successfully")
		}
		return e.Next()
	})
}

// renderLlmEnv queries ALL llm_keys records and writes a flat env file.
func renderLlmEnv(app core.App) error {
	records, err := app.FindRecordsByFilter(
		"llm_keys",
		"1=1",
		"",
		0, 0,
	)
	if err != nil {
		return fmt.Errorf("failed to query llm_keys: %w", err)
	}

	var envFile strings.Builder
	envFile.WriteString("# PocketCoder LLM Keys (auto-generated)\n")
	envFile.WriteString(fmt.Sprintf("# Last rendered: %s\n", time.Now().UTC().Format(time.RFC3339)))
	envFile.WriteString(fmt.Sprintf("# Key records: %d\n", len(records)))

	for _, record := range records {
		envVars := make(map[string]any)
		if err := record.UnmarshalJSONField("env_vars", &envVars); err != nil {
			log.Printf("⚠️ [LLM] Failed to unmarshal env_vars for record %s: %v", record.Id, err)
			continue
		}
		for k, v := range envVars {
			envFile.WriteString(fmt.Sprintf("%s=%v\n", k, v))
		}
	}

	envContent := []byte(envFile.String())

	// Write to OpenCode path
	dir := "/workspace/.opencode"
	if _, err := os.Stat(dir); os.IsNotExist(err) {
		if mkErr := os.MkdirAll(dir, 0755); mkErr != nil {
			return fmt.Errorf("failed to create directory %s: %w", dir, mkErr)
		}
	}
	if err := os.WriteFile(llmEnvPath, envContent, 0644); err != nil {
		return fmt.Errorf("failed to write llm.env to %s: %w", llmEnvPath, err)
	}

	// Write to shared volume (read by sandbox/CAO sandbox agents)
	if err := os.WriteFile(llmEnvPathShared, envContent, 0644); err != nil {
		log.Printf("⚠️ [LLM] Failed to write shared llm.env to %s: %v", llmEnvPathShared, err)
		// Non-fatal: OpenCode still gets its keys even if sandbox copy fails
	}

	log.Printf("✅ [LLM] Rendered llm.env with %d key records", len(records))
	return nil
}

// restartOpenCode sends a restart command to the OpenCode container via the Docker Socket Proxy.
func restartOpenCode() error {
	log.Printf("🔄 [LLM] Restarting OpenCode container '%s'...", openCodeContainer)

	host := os.Getenv("DOCKER_HOST")
	if host == "" {
		host = defaultDockerHost
	}

	proxyAddr := host
	if strings.HasPrefix(host, "tcp://") {
		proxyAddr = strings.TrimPrefix(host, "tcp://")
	}

	client := &http.Client{
		Transport: &http.Transport{
			DialContext: func(ctx context.Context, network, addr string) (net.Conn, error) {
				return net.Dial("tcp", proxyAddr)
			},
		},
		Timeout: 30 * time.Second,
	}

	apiPath := fmt.Sprintf("http://%s/containers/%s/restart", proxyAddr, openCodeContainer)
	resp, err := client.Post(apiPath, "application/json", nil)
	if err != nil {
		return fmt.Errorf("failed to call Docker API via proxy: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusNotFound {
		log.Printf("⚠️ [LLM] OpenCode container '%s' not found, skipping restart", openCodeContainer)
		return nil
	}

	if resp.StatusCode >= 400 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("Docker API returned error %s: %s", resp.Status, string(body))
	}

	log.Printf("✅ [LLM] OpenCode container '%s' restart sent successfully", openCodeContainer)
	return nil
}
