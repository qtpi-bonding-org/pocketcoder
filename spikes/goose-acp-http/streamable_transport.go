package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
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
}

func runStreamableHTTP(rawURL, secret, prompt, existingSession, cwd string, timeout time.Duration) error {
	if rawURL == "" || secret == "" {
		return fmt.Errorf("--http-url and --secret are required for --transport=http")
	}
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	h := &streamableACP{url: rawURL, secret: secret, client: &http.Client{}, waiters: map[string]chan rpcMessage{}}
	if err := h.initialize(ctx); err != nil {
		return err
	}
	fmt.Fprintf(stderr(), "initialized transport=streamable-http connection_id=%s\n", h.connectionID)
	if err := h.openStream(ctx, ""); err != nil {
		return fmt.Errorf("open connection stream: %w", err)
	}

	sessionID := existingSession
	if sessionID == "" {
		reply, err := h.call(ctx, "session/new", map[string]any{"cwd": cwd, "mcpServers": []any{}}, "")
		if err != nil {
			return err
		}
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
		if _, err := h.call(ctx, "session/load", map[string]any{"sessionId": sessionID, "cwd": cwd, "mcpServers": []any{}}, sessionID); err != nil {
			return err
		}
		fmt.Fprintf(stderr(), "loaded_session_id=%s\n", sessionID)
	}
	if prompt == "" {
		return nil
	}
	if _, err := h.call(ctx, "session/prompt", map[string]any{"sessionId": sessionID, "prompt": []map[string]string{{"type": "text", "text": prompt}}}, sessionID); err != nil {
		return err
	}
	fmt.Fprintln(stderr(), "prompt_completed=true")
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
	go h.readStream(ctx, resp.Body)
	return nil
}
func (h *streamableACP) readStream(ctx context.Context, body io.ReadCloser) {
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
