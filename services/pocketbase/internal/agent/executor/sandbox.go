// Package executor preserves the sandbox ACP adapter for a future Goose tool
// integration. The selected c1 runtime does not currently advertise or call
// it because Goose's built-in shell executes in c2 rather than via ACP.
package executor

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"path/filepath"
	"strings"

	acp "github.com/coder/acp-go-sdk"
)

type Config struct {
	URL       string
	Workspace string
	Client    *http.Client
}

type Sandbox struct {
	baseURL, workspace string
	client             *http.Client
}

func New(cfg Config) (*Sandbox, error) {
	if cfg.URL == "" || cfg.Workspace == "" {
		return nil, fmt.Errorf("SANDBOX_PROXY_URL and GOOSE_WORKSPACE are required")
	}
	if _, err := url.ParseRequestURI(cfg.URL); err != nil {
		return nil, fmt.Errorf("invalid SANDBOX_PROXY_URL: %w", err)
	}
	return &Sandbox{baseURL: strings.TrimRight(cfg.URL, "/"), workspace: filepath.Clean(cfg.Workspace), client: cfg.Client}, nil
}

// Capabilities are advertised only because every handler below reaches the
// sandbox API and each requested path is restricted to Workspace.
func Capabilities() acp.ClientCapabilities {
	return acp.ClientCapabilities{Fs: acp.FileSystemCapabilities{ReadTextFile: true, WriteTextFile: true}, Terminal: true}
}

func (s *Sandbox) ReadTextFile(ctx context.Context, request acp.ReadTextFileRequest) (acp.ReadTextFileResponse, error) {
	if err := s.pathAllowed(request.Path); err != nil {
		return acp.ReadTextFileResponse{}, err
	}
	var result struct {
		Content string `json:"content"`
	}
	if err := s.call(ctx, http.MethodPost, "/acp/fs/read", map[string]any{"path": request.Path, "line": request.Line, "limit": request.Limit}, &result); err != nil {
		return acp.ReadTextFileResponse{}, err
	}
	return acp.ReadTextFileResponse{Content: result.Content}, nil
}

func (s *Sandbox) WriteTextFile(ctx context.Context, request acp.WriteTextFileRequest) (acp.WriteTextFileResponse, error) {
	if err := s.pathAllowed(request.Path); err != nil {
		return acp.WriteTextFileResponse{}, err
	}
	if err := s.call(ctx, http.MethodPost, "/acp/fs/write", map[string]string{"path": request.Path, "content": request.Content}, nil); err != nil {
		return acp.WriteTextFileResponse{}, err
	}
	return acp.WriteTextFileResponse{}, nil
}

func (s *Sandbox) CreateTerminal(ctx context.Context, request acp.CreateTerminalRequest) (acp.CreateTerminalResponse, error) {
	cwd := s.workspace
	if request.Cwd != nil {
		cwd = *request.Cwd
	}
	if err := s.pathAllowed(cwd); err != nil {
		return acp.CreateTerminalResponse{}, err
	}
	var result struct {
		TerminalID string `json:"terminalId"`
	}
	if err := s.call(ctx, http.MethodPost, "/acp/terminals", map[string]any{"command": request.Command, "args": request.Args, "cwd": cwd, "env": request.Env, "outputByteLimit": request.OutputByteLimit}, &result); err != nil {
		return acp.CreateTerminalResponse{}, err
	}
	if result.TerminalID == "" {
		return acp.CreateTerminalResponse{}, fmt.Errorf("sandbox returned no terminal id")
	}
	return acp.CreateTerminalResponse{TerminalId: result.TerminalID}, nil
}

func (s *Sandbox) TerminalOutput(ctx context.Context, request acp.TerminalOutputRequest) (acp.TerminalOutputResponse, error) {
	var result struct {
		Output     string                  `json:"output"`
		Truncated  bool                    `json:"truncated"`
		ExitStatus *acp.TerminalExitStatus `json:"exitStatus"`
	}
	if err := s.call(ctx, http.MethodGet, "/acp/terminals/"+url.PathEscape(request.TerminalId)+"/output", nil, &result); err != nil {
		return acp.TerminalOutputResponse{}, err
	}
	return acp.TerminalOutputResponse{Output: result.Output, Truncated: result.Truncated, ExitStatus: result.ExitStatus}, nil
}

func (s *Sandbox) WaitForTerminalExit(ctx context.Context, request acp.WaitForTerminalExitRequest) (acp.WaitForTerminalExitResponse, error) {
	var result acp.WaitForTerminalExitResponse
	if err := s.call(ctx, http.MethodGet, "/acp/terminals/"+url.PathEscape(request.TerminalId)+"/wait", nil, &result); err != nil {
		return acp.WaitForTerminalExitResponse{}, err
	}
	return result, nil
}

func (s *Sandbox) KillTerminal(ctx context.Context, request acp.KillTerminalRequest) (acp.KillTerminalResponse, error) {
	if err := s.call(ctx, http.MethodDelete, "/acp/terminals/"+url.PathEscape(request.TerminalId), nil, nil); err != nil {
		return acp.KillTerminalResponse{}, err
	}
	return acp.KillTerminalResponse{}, nil
}

func (s *Sandbox) ReleaseTerminal(ctx context.Context, request acp.ReleaseTerminalRequest) (acp.ReleaseTerminalResponse, error) {
	if err := s.call(ctx, http.MethodPost, "/acp/terminals/"+url.PathEscape(request.TerminalId)+"/release", nil, nil); err != nil {
		return acp.ReleaseTerminalResponse{}, err
	}
	return acp.ReleaseTerminalResponse{}, nil
}

func (s *Sandbox) pathAllowed(value string) error {
	if !filepath.IsAbs(value) {
		return fmt.Errorf("ACP path must be absolute")
	}
	clean := filepath.Clean(value)
	if clean != s.workspace && !strings.HasPrefix(clean, s.workspace+string(filepath.Separator)) {
		return fmt.Errorf("ACP path is outside workspace")
	}
	return nil
}

func (s *Sandbox) call(ctx context.Context, method, path string, input, output any) error {
	var body io.Reader
	if input != nil {
		encoded, err := json.Marshal(input)
		if err != nil {
			return err
		}
		body = bytes.NewReader(encoded)
	}
	req, err := http.NewRequestWithContext(ctx, method, s.baseURL+path, body)
	if err != nil {
		return err
	}
	if input != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	client := s.client
	if client == nil {
		client = http.DefaultClient
	}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("call sandbox: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		data, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		return fmt.Errorf("sandbox %s %s: %s", method, path, strings.TrimSpace(string(data)))
	}
	if output != nil {
		if err := json.NewDecoder(resp.Body).Decode(output); err != nil {
			return fmt.Errorf("decode sandbox response: %w", err)
		}
	}
	return nil
}
