// goose-acp-http is a disposable compatibility harness for PocketCoder c1.
//
// It first proves the Go ACP SDK against goose's supported stdio endpoint.
// HTTP probing is deliberately kept separate because acp-go-sdk currently owns
// a line-delimited JSON-RPC transport, while goose serve exposes streamable HTTP.
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log/slog"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	acp "github.com/coder/acp-go-sdk"
)

type client struct {
	autoApprove bool
}

var _ acp.Client = (*client)(nil)

func (c *client) RequestPermission(_ context.Context, p acp.RequestPermissionRequest) (acp.RequestPermissionResponse, error) {
	if !c.autoApprove || len(p.Options) == 0 {
		return acp.RequestPermissionResponse{Outcome: acp.RequestPermissionOutcome{
			Cancelled: &acp.RequestPermissionOutcomeCancelled{},
		}}, nil
	}

	for _, option := range p.Options {
		if option.Kind == acp.PermissionOptionKindAllowOnce || option.Kind == acp.PermissionOptionKindAllowAlways {
			return acp.RequestPermissionResponse{Outcome: acp.RequestPermissionOutcome{
				Selected: &acp.RequestPermissionOutcomeSelected{OptionId: option.OptionId},
			}}, nil
		}
	}

	return acp.RequestPermissionResponse{Outcome: acp.RequestPermissionOutcome{
		Selected: &acp.RequestPermissionOutcomeSelected{OptionId: p.Options[0].OptionId},
	}}, nil
}

func (c *client) SessionUpdate(_ context.Context, notification acp.SessionNotification) error {
	payload, err := json.Marshal(notification)
	if err != nil {
		return err
	}
	fmt.Println(string(payload))
	return nil
}

func (*client) ReadTextFile(_ context.Context, p acp.ReadTextFileRequest) (acp.ReadTextFileResponse, error) {
	if !filepath.IsAbs(p.Path) {
		return acp.ReadTextFileResponse{}, fmt.Errorf("refusing relative path %q", p.Path)
	}
	content, err := os.ReadFile(p.Path)
	if err != nil {
		return acp.ReadTextFileResponse{}, err
	}
	return acp.ReadTextFileResponse{Content: string(content)}, nil
}

func (*client) WriteTextFile(_ context.Context, p acp.WriteTextFileRequest) (acp.WriteTextFileResponse, error) {
	if !filepath.IsAbs(p.Path) {
		return acp.WriteTextFileResponse{}, fmt.Errorf("refusing relative path %q", p.Path)
	}
	if err := os.MkdirAll(filepath.Dir(p.Path), 0o755); err != nil {
		return acp.WriteTextFileResponse{}, err
	}
	return acp.WriteTextFileResponse{}, os.WriteFile(p.Path, []byte(p.Content), 0o644)
}

func (*client) CreateTerminal(_ context.Context, _ acp.CreateTerminalRequest) (acp.CreateTerminalResponse, error) {
	return acp.CreateTerminalResponse{TerminalId: "spike-terminal"}, nil
}

func (*client) KillTerminal(_ context.Context, _ acp.KillTerminalRequest) (acp.KillTerminalResponse, error) {
	return acp.KillTerminalResponse{}, nil
}

func (*client) TerminalOutput(_ context.Context, _ acp.TerminalOutputRequest) (acp.TerminalOutputResponse, error) {
	return acp.TerminalOutputResponse{Output: "", Truncated: false}, nil
}

func (*client) ReleaseTerminal(_ context.Context, _ acp.ReleaseTerminalRequest) (acp.ReleaseTerminalResponse, error) {
	return acp.ReleaseTerminalResponse{}, nil
}

func (*client) WaitForTerminalExit(_ context.Context, _ acp.WaitForTerminalExitRequest) (acp.WaitForTerminalExitResponse, error) {
	return acp.WaitForTerminalExitResponse{}, nil
}

func main() {
	transport := flag.String("transport", "stdio", "ACP transport: stdio or http")
	goose := flag.String("goose", "goose", "path to the pinned goose binary")
	httpURL := flag.String("http-url", "", "Goose serve /acp URL when --transport=http")
	secret := flag.String("secret", "", "GOOSE_SERVER__SECRET_KEY when --transport=http")
	httpDialect := flag.String("http-dialect", "legacy", "Goose HTTP dialect: legacy or streamable")
	prompt := flag.String("prompt", "Reply with exactly: goose ACP spike connected", "prompt to send")
	sessionID := flag.String("session", "", "existing ACP session ID to load before prompting")
	mode := flag.String("mode", "", "ACP session mode to set before prompting (streamable HTTP only)")
	mcpSSEURL := flag.String("mcp-sse-url", "", "SSE MCP server URL supplied when creating/loading a streamable HTTP session")
	cwd := flag.String("cwd", mustGetwd(), "absolute workspace path supplied to goose")
	autoApprove := flag.Bool("auto-approve", false, "select an allow option when goose requests permission")
	permissionDelay := flag.Duration("permission-delay", 0, "hold a permission request before selecting an allow option (streamable HTTP only)")
	cancelAfter := flag.Duration("cancel-after", 0, "send session/cancel after the first streamed update (streamable HTTP only)")
	timeout := flag.Duration("timeout", 2*time.Minute, "timeout for initialize, load, and prompt")
	flag.Parse()
	if *transport == "http" {
		if *httpDialect == "streamable" {
			failIf(runStreamableHTTP(*httpURL, *secret, *prompt, *sessionID, *cwd, *mode, *mcpSSEURL, *autoApprove, *permissionDelay, *cancelAfter, *timeout))
		} else if *httpDialect == "legacy" {
			failIf(runHTTP(*httpURL, *secret, *prompt, *sessionID, *cwd, *autoApprove, *timeout))
		} else {
			failIf(fmt.Errorf("unknown HTTP dialect %q", *httpDialect))
		}
		return
	}
	if *transport != "stdio" {
		failIf(fmt.Errorf("unknown transport %q", *transport))
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), *timeout)
	defer cancel()

	cmd := exec.CommandContext(ctx, *goose, "acp")
	cmd.Stderr = os.Stderr
	stdin, err := cmd.StdinPipe()
	failIf(err)
	stdout, err := cmd.StdoutPipe()
	failIf(err)
	failIf(cmd.Start())
	defer func() { _ = cmd.Process.Kill(); _ = cmd.Wait() }()

	connection := acp.NewClientSideConnection(&client{autoApprove: *autoApprove}, stdin, stdout)
	connection.SetLogger(slog.New(slog.NewTextHandler(os.Stderr, nil)))

	initialized, err := connection.Initialize(ctx, acp.InitializeRequest{
		ProtocolVersion: acp.ProtocolVersionNumber,
		ClientCapabilities: acp.ClientCapabilities{
			Fs:       acp.FileSystemCapabilities{ReadTextFile: true, WriteTextFile: true},
			Terminal: true,
		},
	})
	failIf(err)
	agentName := "unknown"
	if initialized.AgentInfo != nil {
		agentName = initialized.AgentInfo.Name
	}
	fmt.Fprintf(os.Stderr, "initialized protocol=%d agent=%s\n", initialized.ProtocolVersion, agentName)

	activeSessionID := acp.SessionId(*sessionID)
	if activeSessionID == "" {
		created, err := connection.NewSession(ctx, acp.NewSessionRequest{Cwd: *cwd, McpServers: []acp.McpServer{}})
		failIf(err)
		activeSessionID = created.SessionId
		fmt.Fprintf(os.Stderr, "session_id=%s\n", activeSessionID)
	} else {
		fmt.Fprintf(os.Stderr, "loading_session_id=%s\n", activeSessionID)
		_, err := connection.LoadSession(ctx, acp.LoadSessionRequest{SessionId: activeSessionID, Cwd: *cwd})
		failIf(err)
		fmt.Fprintf(os.Stderr, "loaded_session_id=%s\n", activeSessionID)
	}

	_, err = connection.Prompt(ctx, acp.PromptRequest{
		SessionId: activeSessionID,
		Prompt:    []acp.ContentBlock{acp.TextBlock(*prompt)},
	})
	failIf(err)
	fmt.Fprintln(os.Stderr, "prompt_completed=true")
}

func mustGetwd() string {
	wd, err := os.Getwd()
	failIf(err)
	return wd
}

func failIf(err error) {
	if err == nil {
		return
	}
	fmt.Fprintln(os.Stderr, "spike failed:", err)
	os.Exit(1)
}
