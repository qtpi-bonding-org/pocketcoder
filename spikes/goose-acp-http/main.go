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
	"io"
	"log/slog"
	"net"
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
	fmt.Fprintf(os.Stderr, "request_permission received: options=%d\n", len(p.Options))
	if !c.autoApprove || len(p.Options) == 0 {
		fmt.Fprintln(os.Stderr, "permission auto-approve disabled -> cancelled")
		return acp.RequestPermissionResponse{Outcome: acp.RequestPermissionOutcome{
			Cancelled: &acp.RequestPermissionOutcomeCancelled{},
		}}, nil
	}

	for _, option := range p.Options {
		if option.Kind == acp.PermissionOptionKindAllowOnce || option.Kind == acp.PermissionOptionKindAllowAlways {
			fmt.Fprintf(os.Stderr, "permission auto-approved option=%s kind=%s\n", option.OptionId, option.Kind)
			return acp.RequestPermissionResponse{Outcome: acp.RequestPermissionOutcome{
				Selected: &acp.RequestPermissionOutcomeSelected{OptionId: option.OptionId},
			}}, nil
		}
	}

	fmt.Fprintf(os.Stderr, "permission auto-approved fallback option=%s\n", p.Options[0].OptionId)
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
	transport := flag.String("transport", "stdio", "ACP transport: stdio, tcp, or http")
	goose := flag.String("goose", "goose", "path to the pinned goose binary")
	tcpAddr := flag.String("tcp-addr", "", "host:port of a goose acp byte-stream bridge when --transport=tcp")
	wsURL := flag.String("ws-url", "", "ws:// URL of goose serve /acp when --transport=ws")
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
	ctx, cancel := context.WithTimeout(context.Background(), *timeout)
	defer cancel()
	cl := &client{autoApprove: *autoApprove}

	switch *transport {
	case "stdio":
		cmd := exec.CommandContext(ctx, *goose, "acp")
		cmd.Stderr = os.Stderr
		stdin, err := cmd.StdinPipe()
		failIf(err)
		stdout, err := cmd.StdoutPipe()
		failIf(err)
		failIf(cmd.Start())
		defer func() { _ = cmd.Process.Kill(); _ = cmd.Wait() }()
		runOverStreams(ctx, cl, stdin, stdout, *prompt, *sessionID, *cwd, *mode, *cancelAfter)
	case "tcp":
		if *tcpAddr == "" {
			failIf(fmt.Errorf("--tcp-addr host:port is required for --transport=tcp"))
		}
		conn, err := net.Dial("tcp", *tcpAddr)
		failIf(err)
		defer conn.Close()
		fmt.Fprintf(os.Stderr, "dialed tcp=%s\n", *tcpAddr)
		runOverStreams(ctx, cl, conn, conn, *prompt, *sessionID, *cwd, *mode, *cancelAfter)
	case "ws":
		if *wsURL == "" {
			failIf(fmt.Errorf("--ws-url is required for --transport=ws"))
		}
		ws, err := dialWS(ctx, *wsURL, *secret)
		failIf(err)
		defer ws.Close()
		fmt.Fprintf(os.Stderr, "dialed ws=%s\n", *wsURL)
		runOverStreams(ctx, cl, ws, ws, *prompt, *sessionID, *cwd, *mode, *cancelAfter)
	default:
		failIf(fmt.Errorf("unknown transport %q", *transport))
	}
}

// runOverStreams drives the robust SDK ClientSideConnection over any byte
// stream — a subprocess pipe (stdio) or a TCP socket (the cross-container
// bridge). This is the whole point of the stdio-vs-HTTP question: the SDK
// only needs an io.Writer/io.Reader.
func runOverStreams(ctx context.Context, cl *client, peerIn io.Writer, peerOut io.Reader, prompt, sessionID, cwd, mode string, cancelAfter time.Duration) {
	connection := acp.NewClientSideConnection(cl, peerIn, peerOut)
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

	activeSessionID := acp.SessionId(sessionID)
	if activeSessionID == "" {
		created, err := connection.NewSession(ctx, acp.NewSessionRequest{Cwd: cwd, McpServers: []acp.McpServer{}})
		failIf(err)
		activeSessionID = created.SessionId
		fmt.Fprintf(os.Stderr, "session_id=%s\n", activeSessionID)
	} else {
		fmt.Fprintf(os.Stderr, "loading_session_id=%s\n", activeSessionID)
		_, err := connection.LoadSession(ctx, acp.LoadSessionRequest{SessionId: activeSessionID, Cwd: cwd, McpServers: []acp.McpServer{}})
		failIf(err)
		fmt.Fprintf(os.Stderr, "loaded_session_id=%s\n", activeSessionID)
	}

	if mode != "" {
		_, err := connection.SetSessionMode(ctx, acp.SetSessionModeRequest{SessionId: activeSessionID, ModeId: acp.SessionModeId(mode)})
		failIf(err)
		fmt.Fprintf(os.Stderr, "mode_set=%s\n", mode)
	}

	if cancelAfter > 0 {
		go func() {
			select {
			case <-time.After(cancelAfter):
				fmt.Fprintf(os.Stderr, "sending session/cancel after %s\n", cancelAfter)
				_ = connection.Cancel(ctx, acp.CancelNotification{SessionId: activeSessionID})
			case <-ctx.Done():
			}
		}()
	}

	result, err := connection.Prompt(ctx, acp.PromptRequest{
		SessionId: activeSessionID,
		Prompt:    []acp.ContentBlock{acp.TextBlock(prompt)},
	})
	failIf(err)
	fmt.Fprintf(os.Stderr, "prompt_completed=true stopReason=%s\n", result.StopReason)
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
