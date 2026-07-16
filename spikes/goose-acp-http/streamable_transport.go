package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// streamableACP is a minimal implementation of the current ACP Streamable
// HTTP profile. It exists solely to test a pinned Goose release.
type streamableACP struct {
	url, secret, connectionID string
	client                    *http.Client
	mu                        sync.Mutex
	waiters                   map[string]chan rpcMessage
	updates                   chan rpcMessage
	autoApprove               bool
	permissionDelay           time.Duration
	terminals                 map[string]terminalResult
}

type terminalResult struct {
	output   string
	exitCode int
}

func runStreamableHTTP(rawURL, secret, prompt, existingSession, cwd, mode, mcpSSEURL string, autoApprove bool, permissionDelay, cancelAfter, timeout time.Duration) error {
	if rawURL == "" || secret == "" {
		return fmt.Errorf("--http-url and --secret are required for --transport=http")
	}
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	h := &streamableACP{url: rawURL, secret: secret, client: &http.Client{}, waiters: map[string]chan rpcMessage{}, updates: make(chan rpcMessage, 64), autoApprove: autoApprove, permissionDelay: permissionDelay, terminals: map[string]terminalResult{}}
	if err := h.initialize(ctx); err != nil {
		return err
	}
	fmt.Fprintf(stderr(), "initialized transport=streamable-http connection_id=%s\n", h.connectionID)
	if err := h.openStream(ctx, ""); err != nil {
		return fmt.Errorf("open connection stream: %w", err)
	}

	sessionID := existingSession
	mcpServers := []any{}
	if mcpSSEURL != "" {
		mcpServers = append(mcpServers, map[string]any{"name": "gateway", "type": "sse", "url": mcpSSEURL, "headers": []any{}})
	}
	if sessionID == "" {
		reply, err := h.call(ctx, "session/new", map[string]any{"cwd": cwd, "mcpServers": mcpServers}, "")
		if err != nil {
			return err
		}
		fmt.Fprintf(stderr(), "session_new_result=%s\n", reply.Result)
		var result struct {
			SessionID string `json:"sessionId"`
		}
		if err := json.Unmarshal(reply.Result, &result); err != nil {
			return err
		}
		sessionID = result.SessionID
		if sessionID == "" {
			return fmt.Errorf("session/new response missing sessionId")
		}
		fmt.Fprintf(stderr(), "session_id=%s\n", sessionID)
	}
	if err := h.openStream(ctx, sessionID); err != nil {
		return fmt.Errorf("open session stream: %w", err)
	}
	if existingSession != "" {
		fmt.Fprintf(stderr(), "loading_session_id=%s\n", sessionID)
		if _, err := h.call(ctx, "session/load", map[string]any{"sessionId": sessionID, "cwd": cwd, "mcpServers": mcpServers}, sessionID); err != nil {
			return err
		}
		fmt.Fprintf(stderr(), "loaded_session_id=%s\n", sessionID)
	}
	if mode != "" {
		if _, err := h.call(ctx, "session/set_mode", map[string]any{"sessionId": sessionID, "modeId": mode}, sessionID); err != nil {
			return err
		}
		fmt.Fprintf(stderr(), "session_mode=%s\n", mode)
	}
	if prompt == "" {
		return nil
	}
	promptDone := make(chan error, 1)
	go func() {
		reply, err := h.call(ctx, "session/prompt", map[string]any{"sessionId": sessionID, "prompt": []map[string]string{{"type": "text", "text": prompt}}}, sessionID)
		if err == nil {
			fmt.Fprintf(stderr(), "prompt_terminal_result=%s\n", reply.Result)
		}
		promptDone <- err
	}()
	if cancelAfter > 0 {
		for {
			select {
			case update := <-h.updates:
				if !isAgentOutput(update) {
					continue
				}
				fmt.Fprintf(stderr(), "cancel_trigger_update=%s\n", update.Method)
				goto cancel
			case <-time.After(cancelAfter):
				fmt.Fprintln(stderr(), "cancel_trigger_update=timer")
				goto cancel
			case <-ctx.Done():
				return ctx.Err()
			}
		}
	cancel:
		if err := h.notify(ctx, "session/cancel", map[string]any{"sessionId": sessionID}, sessionID); err != nil {
			return err
		}
		fmt.Fprintln(stderr(), "cancel_accepted=true")
	}
	if err := <-promptDone; err != nil {
		return err
	}
	fmt.Fprintln(stderr(), "prompt_completed=true")
	return nil
}

func isAgentOutput(msg rpcMessage) bool {
	var params struct {
		Update struct {
			SessionUpdate string `json:"sessionUpdate"`
		} `json:"update"`
	}
	return json.Unmarshal(msg.Params, &params) == nil && (params.Update.SessionUpdate == "agent_message_chunk" || params.Update.SessionUpdate == "agent_thought_chunk")
}

func (h *streamableACP) notify(ctx context.Context, method string, params any, sessionID string) error {
	b, _ := json.Marshal(params)
	resp, err := h.post(ctx, rpcMessage{JSONRPC: "2.0", Method: method, Params: b}, sessionID)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusAccepted {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("%s status=%s body=%s", method, resp.Status, body)
	}
	return nil
}

func (h *streamableACP) initialize(ctx context.Context) error {
	params, _ := json.Marshal(map[string]any{"protocolVersion": 1, "clientCapabilities": map[string]any{"fs": map[string]bool{"readTextFile": true, "writeTextFile": true}, "terminal": true}})
	resp, err := h.post(ctx, rpcMessage{JSONRPC: "2.0", ID: json.RawMessage("1"), Method: "initialize", Params: params}, "")
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("initialize status=%s body=%s", resp.Status, body)
	}
	h.connectionID = resp.Header.Get("Acp-Connection-Id")
	if h.connectionID == "" {
		return fmt.Errorf("initialize missing Acp-Connection-Id")
	}
	return nil
}
func (h *streamableACP) call(ctx context.Context, method string, params any, sessionID string) (rpcMessage, error) {
	id := fmt.Sprintf("%d", time.Now().UnixNano())
	b, _ := json.Marshal(params)
	ch := make(chan rpcMessage, 1)
	h.mu.Lock()
	h.waiters[id] = ch
	h.mu.Unlock()
	defer func() { h.mu.Lock(); delete(h.waiters, id); h.mu.Unlock() }()
	resp, err := h.post(ctx, rpcMessage{JSONRPC: "2.0", ID: json.RawMessage(id), Method: method, Params: b}, sessionID)
	if err != nil {
		return rpcMessage{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusAccepted {
		body, _ := io.ReadAll(resp.Body)
		return rpcMessage{}, fmt.Errorf("%s status=%s body=%s", method, resp.Status, body)
	}
	select {
	case reply := <-ch:
		if len(reply.Error) > 0 {
			return rpcMessage{}, fmt.Errorf("%s rpc error=%s", method, reply.Error)
		}
		return reply, nil
	case <-ctx.Done():
		return rpcMessage{}, ctx.Err()
	}
}
func (h *streamableACP) post(ctx context.Context, msg rpcMessage, sessionID string) (*http.Response, error) {
	b, _ := json.Marshal(msg)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, h.url, bytes.NewReader(b))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json, text/event-stream")
	req.Header.Set("X-Secret-Key", h.secret)
	if h.connectionID != "" {
		req.Header.Set("Acp-Connection-Id", h.connectionID)
	}
	if sessionID != "" {
		req.Header.Set("Acp-Session-Id", sessionID)
	}
	return h.client.Do(req)
}
func (h *streamableACP) openStream(ctx context.Context, sessionID string) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, h.url, nil)
	if err != nil {
		return err
	}
	req.Header.Set("Accept", "text/event-stream")
	req.Header.Set("X-Secret-Key", h.secret)
	req.Header.Set("Acp-Connection-Id", h.connectionID)
	if sessionID != "" {
		req.Header.Set("Acp-Session-Id", sessionID)
	}
	resp, err := h.client.Do(req)
	if err != nil {
		return err
	}
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		resp.Body.Close()
		return fmt.Errorf("stream status=%s body=%s", resp.Status, body)
	}
	go h.readStream(ctx, resp.Body, sessionID)
	return nil
}
func (h *streamableACP) readStream(ctx context.Context, body io.ReadCloser, sessionID string) {
	defer body.Close()
	s := bufio.NewScanner(body)
	s.Buffer(make([]byte, 4096), 4<<20)
	var data []string
	for s.Scan() {
		line := s.Text()
		if line != "" {
			if strings.HasPrefix(line, "data:") {
				data = append(data, strings.TrimSpace(strings.TrimPrefix(line, "data:")))
			}
			continue
		}
		if len(data) == 0 {
			continue
		}
		var msg rpcMessage
		raw := strings.Join(data, "\n")
		data = nil
		if json.Unmarshal([]byte(raw), &msg) != nil {
			continue
		}
		if msg.Method != "" {
			fmt.Println(raw)
			select {
			case h.updates <- msg:
			default:
			}
			if msg.Method == "session/request_permission" || msg.Method == "request_permission" {
				go h.respondPermission(ctx, msg, sessionID)
			}
			if msg.Method == "fs/write_text_file" || msg.Method == "fs/read_text_file" {
				go h.respondFileRequest(ctx, msg, sessionID)
			}
			if strings.HasPrefix(msg.Method, "terminal/") {
				go h.respondTerminalRequest(ctx, msg, sessionID)
			}
			continue
		}
		h.mu.Lock()
		ch := h.waiters[string(msg.ID)]
		h.mu.Unlock()
		if ch != nil {
			ch <- msg
		}
	}
}

func (h *streamableACP) respondTerminalRequest(ctx context.Context, request rpcMessage, sessionID string) {
	result := map[string]any{}
	switch request.Method {
	case "terminal/create":
		var params struct {
			Command string `json:"command"`
			Cwd     string `json:"cwd"`
		}
		if err := json.Unmarshal(request.Params, &params); err != nil {
			fmt.Fprintf(stderr(), "terminal_response_error=%v\n", err)
			return
		}
		cmd := exec.CommandContext(ctx, "sh", "-lc", params.Command)
		cmd.Dir = params.Cwd
		output, err := cmd.CombinedOutput()
		exitCode := 0
		if err != nil {
			exitCode = 1
		}
		h.mu.Lock()
		h.terminals["spike-terminal"] = terminalResult{output: string(output), exitCode: exitCode}
		h.mu.Unlock()
		result["terminalId"] = "spike-terminal"
	case "terminal/output":
		h.mu.Lock()
		terminal := h.terminals["spike-terminal"]
		h.mu.Unlock()
		result["output"] = terminal.output
		result["truncated"] = false
	case "terminal/wait_for_exit":
		h.mu.Lock()
		terminal := h.terminals["spike-terminal"]
		h.mu.Unlock()
		result["exitCode"] = terminal.exitCode
	}
	b, _ := json.Marshal(result)
	resp, err := h.post(ctx, rpcMessage{JSONRPC: "2.0", ID: request.ID, Result: b}, sessionID)
	if err != nil {
		fmt.Fprintf(stderr(), "terminal_response_error=%v\n", err)
		return
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusAccepted {
		body, _ := io.ReadAll(resp.Body)
		fmt.Fprintf(stderr(), "terminal_response_status=%s body=%s\n", resp.Status, body)
		return
	}
	fmt.Fprintf(stderr(), "terminal_response_method=%s\n", request.Method)
}

func (h *streamableACP) respondFileRequest(ctx context.Context, request rpcMessage, sessionID string) {
	var params struct {
		Path    string `json:"path"`
		Content string `json:"content"`
	}
	if err := json.Unmarshal(request.Params, &params); err != nil || !filepath.IsAbs(params.Path) {
		fmt.Fprintf(stderr(), "file_response_error=%v\n", err)
		return
	}
	result := map[string]any{}
	var err error
	switch request.Method {
	case "fs/write_text_file":
		err = os.MkdirAll(filepath.Dir(params.Path), 0o755)
		if err == nil {
			err = os.WriteFile(params.Path, []byte(params.Content), 0o644)
		}
	case "fs/read_text_file":
		var content []byte
		content, err = os.ReadFile(params.Path)
		result["content"] = string(content)
	}
	if err != nil {
		fmt.Fprintf(stderr(), "file_response_error=%v\n", err)
		return
	}
	b, _ := json.Marshal(result)
	resp, err := h.post(ctx, rpcMessage{JSONRPC: "2.0", ID: request.ID, Result: b}, sessionID)
	if err != nil {
		fmt.Fprintf(stderr(), "file_response_error=%v\n", err)
		return
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusAccepted {
		body, _ := io.ReadAll(resp.Body)
		fmt.Fprintf(stderr(), "file_response_status=%s body=%s\n", resp.Status, body)
		return
	}
	fmt.Fprintf(stderr(), "file_response_method=%s\n", request.Method)
}

func (h *streamableACP) respondPermission(ctx context.Context, request rpcMessage, sessionID string) {
	if !h.autoApprove {
		fmt.Fprintln(stderr(), "permission_held=true")
		return
	}
	if h.permissionDelay > 0 {
		fmt.Fprintf(stderr(), "permission_held_for=%s\n", h.permissionDelay)
		select {
		case <-time.After(h.permissionDelay):
		case <-ctx.Done():
			return
		}
	}
	var params struct {
		Options []struct {
			OptionID string `json:"optionId"`
			Kind     string `json:"kind"`
		} `json:"options"`
	}
	if err := json.Unmarshal(request.Params, &params); err != nil || len(params.Options) == 0 {
		fmt.Fprintf(stderr(), "permission_response_error=%v\n", err)
		return
	}
	selected := params.Options[0].OptionID
	for _, option := range params.Options {
		if option.Kind == "allow_once" || option.Kind == "allow_always" {
			selected = option.OptionID
			break
		}
	}
	result, _ := json.Marshal(map[string]any{"outcome": map[string]any{"outcome": "selected", "optionId": selected}})
	resp, err := h.post(ctx, rpcMessage{JSONRPC: "2.0", ID: request.ID, Result: result}, sessionID)
	if err != nil {
		fmt.Fprintf(stderr(), "permission_response_error=%v\n", err)
		return
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusAccepted {
		body, _ := io.ReadAll(resp.Body)
		fmt.Fprintf(stderr(), "permission_response_status=%s body=%s\n", resp.Status, body)
		return
	}
	fmt.Fprintf(stderr(), "permission_selected_option=%s\n", selected)
}
