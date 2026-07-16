package main

// This is intentionally a small, raw Streamable-HTTP ACP adapter for the
// compatibility spike. Production c1 should use upstream SDK transport support
// when it becomes available, or move this behind a tested package boundary.

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"
)

type rpcMessage struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      json.RawMessage `json:"id,omitempty"`
	Method  string          `json:"method,omitempty"`
	Params  json.RawMessage `json:"params,omitempty"`
	Result  json.RawMessage `json:"result,omitempty"`
	Error   json.RawMessage `json:"error,omitempty"`
}

type httpACP struct {
	url, secret, connectionID string
	client                    *http.Client
}

func runHTTP(rawURL, secret, prompt, existingSession, cwd string, autoApprove bool, timeout time.Duration) error {
	if rawURL == "" || secret == "" {
		return fmt.Errorf("--http-url and --secret are required for --transport=http")
	}
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	h := &httpACP{url: rawURL, secret: secret, client: &http.Client{}}
	if err := h.initialize(ctx); err != nil {
		return err
	}
	fmt.Fprintf(stderr(), "initialized transport=goose-http session_header_id=%s\n", h.connectionID)

	sessionID := existingSession
	if sessionID == "" {
		result, err := h.callLegacy(ctx, "session/new", map[string]any{"cwd": cwd, "mcpServers": []any{}}, autoApprove)
		if err != nil {
			return err
		}
		var created struct {
			SessionID string `json:"sessionId"`
		}
		if err := json.Unmarshal(result.Result, &created); err != nil {
			return err
		}
		sessionID = created.SessionID
		if sessionID == "" {
			return fmt.Errorf("session/new response missing sessionId")
		}
		fmt.Fprintf(stderr(), "session_id=%s\n", sessionID)
	} else {
		fmt.Fprintf(stderr(), "loading_session_id=%s\n", sessionID)
	}
	if existingSession != "" {
		if _, err := h.callLegacy(ctx, "session/load", map[string]any{"sessionId": sessionID, "cwd": cwd}, autoApprove); err != nil {
			return err
		}
		fmt.Fprintf(stderr(), "loaded_session_id=%s\n", sessionID)
	}
	_, err := h.callLegacy(ctx, "session/prompt", map[string]any{"sessionId": sessionID, "prompt": []map[string]string{{"type": "text", "text": prompt}}}, autoApprove)
	if err != nil {
		return err
	}
	fmt.Fprintln(stderr(), "prompt_completed=true")
	return nil
}

func stderr() io.Writer { return os.Stderr }

func (h *httpACP) initialize(ctx context.Context) error {
	msg := rpcMessage{JSONRPC: "2.0", ID: json.RawMessage("1"), Method: "initialize"}
	msg.Params, _ = json.Marshal(map[string]any{"protocolVersion": 1, "clientCapabilities": map[string]any{"fs": map[string]bool{"readTextFile": true, "writeTextFile": true}, "terminal": true}})
	resp, err := h.post(ctx, msg, "")
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("initialize status=%s body=%s", resp.Status, b)
	}
	h.connectionID = resp.Header.Get("Acp-Session-Id")
	if h.connectionID == "" {
		return fmt.Errorf("initialize response missing Acp-Session-Id: headers=%v", resp.Header)
	}
	_, err = readSSEReply(resp.Body, "1", func(rpcMessage) {})
	return err
}

// Goose v1.35's /acp endpoint predates ACP's long-lived GET stream RFD. Each
// POST returns an SSE response stream and Acp-Session-Id identifies its server
// connection. This adapter deliberately proves that observed contract only.
func (h *httpACP) callLegacy(ctx context.Context, method string, params any, autoApprove bool) (rpcMessage, error) {
	id := fmt.Sprintf("%d", time.Now().UnixNano())
	encoded, _ := json.Marshal(params)
	msg := rpcMessage{JSONRPC: "2.0", ID: json.RawMessage(id), Method: method, Params: encoded}
	b, _ := json.Marshal(msg)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, h.url, bytes.NewReader(b))
	if err != nil {
		return rpcMessage{}, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json, text/event-stream")
	req.Header.Set("X-Secret-Key", h.secret)
	req.Header.Set("Acp-Session-Id", h.connectionID)
	resp, err := h.client.Do(req)
	if err != nil {
		return rpcMessage{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return rpcMessage{}, fmt.Errorf("%s status=%s body=%s", method, resp.Status, body)
	}
	return readSSEReply(resp.Body, id, func(message rpcMessage) {
		if message.Method != "" {
			fmt.Println(mustJSON(message))
		}
	})
}

func readSSEReply(body io.Reader, requestID string, notify func(rpcMessage)) (rpcMessage, error) {
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
			notify(msg)
			continue
		}
		if string(msg.ID) == requestID {
			if len(msg.Error) > 0 {
				return rpcMessage{}, fmt.Errorf("rpc error=%s", msg.Error)
			}
			return msg, nil
		}
	}
	if err := s.Err(); err != nil {
		return rpcMessage{}, err
	}
	return rpcMessage{}, io.EOF
}

func mustJSON(v any) string { b, _ := json.Marshal(v); return string(b) }

func (h *httpACP) post(ctx context.Context, msg rpcMessage, sessionID string) (*http.Response, error) {
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
