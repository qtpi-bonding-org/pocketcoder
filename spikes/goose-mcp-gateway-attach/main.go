// Disposable raw ACP Streamable-HTTP probe for the goose-mcp-gateway-attach
// spike. It deliberately reimplements only the minimal subset of the dialect
// proven in spikes/goose-acp-http (initialize -> open SSE stream -> POST,
// reply correlated over the stream) plus three extra calls this spike needs:
// _goose/unstable/config/extensions/add, _goose/unstable/tools/list, and a
// session/new that can carry an SSE mcpServers entry. Not production code.
package main

import (
	"bufio"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
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

type client struct {
	url, secret, connID string
	http                *http.Client
	mu                  sync.Mutex
	waiters             map[string]chan rpcMessage
	updates             chan rpcMessage
}

func main() {
	url := flag.String("url", "http://127.0.0.1:3000/acp", "goose serve /acp URL")
	secret := flag.String("secret", "", "GOOSE_SERVER__SECRET_KEY")
	cwd := flag.String("cwd", "/workspace", "container-visible cwd for session/new")
	mcpSSEURL := flag.String("mcp-sse-url", "", "if set, attach this URL as an sse mcpServers entry on session/new")
	mcpHTTPURL := flag.String("mcp-http-url", "", "if set, attach this URL as a streamable-http mcpServers entry on session/new")
	addConfigExtension := flag.String("add-config-extension-sse-url", "", "if set, call _goose/unstable/config/extensions/add with an sse extension pointed at this URL, before session/new")
	addConfigExtensionHTTP := flag.String("add-config-extension-http-url", "", "if set, call _goose/unstable/config/extensions/add with a streamable-http extension pointed at this URL, before session/new")
	listTools := flag.Bool("list-tools", false, "after session/new, call _goose/unstable/tools/list")
	prompt := flag.String("prompt", "", "if set, run session/prompt with this text after session/new")
	timeout := flag.Duration("timeout", 60*time.Second, "overall timeout")
	flag.Parse()

	if *secret == "" {
		log.Fatal("--secret is required")
	}
	ctx, cancel := context.WithTimeout(context.Background(), *timeout)
	defer cancel()

	c := &client{url: *url, secret: *secret, http: &http.Client{}, waiters: map[string]chan rpcMessage{}, updates: make(chan rpcMessage, 256)}

	initResult, err := c.initialize(ctx)
	failIf(err)
	fmt.Printf("initialize: connection_id=%s\n", c.connID)
	fmt.Printf("initialize.agentCapabilities.mcpCapabilities=%s\n", gjson(initResult, "agentCapabilities", "mcpCapabilities"))

	failIf(c.openStream(ctx, ""))

	if *addConfigExtension != "" {
		params := map[string]any{
			"extension": map[string]any{
				"type": "mcp",
				"server": map[string]any{
					"type":    "sse",
					"name":    "gateway",
					"url":     *addConfigExtension,
					"headers": []any{},
				},
			},
			"enabled": true,
		}
		reply, err := c.call(ctx, "_goose/unstable/config/extensions/add", params, "")
		if err != nil {
			fmt.Printf("config/extensions/add: ERROR %v\n", err)
		} else {
			fmt.Printf("config/extensions/add: result=%s\n", string(reply.Result))
		}
	}
	if *addConfigExtensionHTTP != "" {
		params := map[string]any{
			"extension": map[string]any{
				"type": "mcp",
				"server": map[string]any{
					"type":    "http",
					"name":    "gateway",
					"url":     *addConfigExtensionHTTP,
					"headers": []any{},
				},
			},
			"enabled": true,
		}
		reply, err := c.call(ctx, "_goose/unstable/config/extensions/add", params, "")
		if err != nil {
			fmt.Printf("config/extensions/add(http): ERROR %v\n", err)
		} else {
			fmt.Printf("config/extensions/add(http): result=%s\n", string(reply.Result))
		}
	}

	mcpServers := []any{}
	if *mcpSSEURL != "" {
		mcpServers = append(mcpServers, map[string]any{"type": "sse", "name": "gateway", "url": *mcpSSEURL, "headers": []any{}})
	}
	if *mcpHTTPURL != "" {
		mcpServers = append(mcpServers, map[string]any{"type": "http", "name": "gateway", "url": *mcpHTTPURL, "headers": []any{}})
	}
	newReply, err := c.call(ctx, "session/new", map[string]any{"cwd": *cwd, "mcpServers": mcpServers}, "")
	failIf(err)
	var created struct {
		SessionID string `json:"sessionId"`
	}
	failIf(json.Unmarshal(newReply.Result, &created))
	fmt.Printf("session/new: session_id=%s result=%s\n", created.SessionID, string(newReply.Result))

	failIf(c.openStream(ctx, created.SessionID))

	if *listTools {
		reply, err := c.call(ctx, "_goose/unstable/tools/list", map[string]any{"sessionId": created.SessionID}, created.SessionID)
		if err != nil {
			fmt.Printf("tools/list: ERROR %v\n", err)
		} else {
			fmt.Printf("tools/list: result=%s\n", string(reply.Result))
		}
	}

	if *prompt != "" {
		reply, err := c.call(ctx, "session/prompt", map[string]any{
			"sessionId": created.SessionID,
			"prompt":    []map[string]string{{"type": "text", "text": *prompt}},
		}, created.SessionID)
		if err != nil {
			fmt.Printf("session/prompt: ERROR %v\n", err)
		} else {
			fmt.Printf("session/prompt: result=%s\n", string(reply.Result))
		}
	}
}

func gjson(raw json.RawMessage, path ...string) string {
	var m any
	if err := json.Unmarshal(raw, &m); err != nil {
		return string(raw)
	}
	for _, p := range path {
		mm, ok := m.(map[string]any)
		if !ok {
			return ""
		}
		m = mm[p]
	}
	b, _ := json.Marshal(m)
	return string(b)
}

func (c *client) initialize(ctx context.Context) (json.RawMessage, error) {
	params, _ := json.Marshal(map[string]any{
		"protocolVersion":    1,
		"clientCapabilities": map[string]any{"fs": map[string]bool{"readTextFile": true, "writeTextFile": true}, "terminal": true},
	})
	req, err := c.newRequest(ctx, http.MethodPost, rpcMessage{JSONRPC: "2.0", ID: json.RawMessage(`"init"`), Method: "initialize", Params: params}, "")
	if err != nil {
		return nil, err
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("initialize status=%s body=%s", resp.Status, body)
	}
	c.connID = resp.Header.Get("Acp-Connection-Id")
	if c.connID == "" {
		return nil, fmt.Errorf("initialize missing Acp-Connection-Id header")
	}
	var msg rpcMessage
	if err := json.Unmarshal(body, &msg); err != nil {
		return nil, fmt.Errorf("initialize: bad body: %s", body)
	}
	if len(msg.Error) > 0 {
		return nil, fmt.Errorf("initialize rpc error: %s", msg.Error)
	}
	return msg.Result, nil
}

func (c *client) newRequest(ctx context.Context, method string, msg rpcMessage, sessionID string) (*http.Request, error) {
	b, _ := json.Marshal(msg)
	req, err := http.NewRequestWithContext(ctx, method, c.url, strings.NewReader(string(b)))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json, text/event-stream")
	req.Header.Set("X-Secret-Key", c.secret)
	if c.connID != "" {
		req.Header.Set("Acp-Connection-Id", c.connID)
	}
	if sessionID != "" {
		req.Header.Set("Acp-Session-Id", sessionID)
	}
	return req, nil
}

func (c *client) call(ctx context.Context, method string, params any, sessionID string) (rpcMessage, error) {
	id := fmt.Sprintf("%d", time.Now().UnixNano())
	b, _ := json.Marshal(params)
	ch := make(chan rpcMessage, 1)
	c.mu.Lock()
	c.waiters[id] = ch
	c.mu.Unlock()
	defer func() { c.mu.Lock(); delete(c.waiters, id); c.mu.Unlock() }()

	req, err := c.newRequest(ctx, http.MethodPost, rpcMessage{JSONRPC: "2.0", ID: json.RawMessage(`"` + id + `"`), Method: method, Params: b}, sessionID)
	if err != nil {
		return rpcMessage{}, err
	}
	resp, err := c.http.Do(req)
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

func (c *client) openStream(ctx context.Context, sessionID string) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.url, nil)
	if err != nil {
		return err
	}
	req.Header.Set("Accept", "text/event-stream")
	req.Header.Set("X-Secret-Key", c.secret)
	req.Header.Set("Acp-Connection-Id", c.connID)
	if sessionID != "" {
		req.Header.Set("Acp-Session-Id", sessionID)
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		resp.Body.Close()
		return fmt.Errorf("open stream status=%s body=%s", resp.Status, body)
	}
	go c.readStream(resp.Body)
	return nil
}

func (c *client) readStream(body io.ReadCloser) {
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
		raw := strings.Join(data, "\n")
		data = nil
		var msg rpcMessage
		if json.Unmarshal([]byte(raw), &msg) != nil {
			continue
		}
		if msg.Method != "" {
			// A server->client request/notification (e.g. session/update,
			// request_permission). Print it and, for request_permission,
			// we simply don't answer (no session/prompt turns need it here).
			fmt.Fprintf(os.Stderr, "update: method=%s params=%s\n", msg.Method, msg.Params)
			continue
		}
		var idStr string
		_ = json.Unmarshal(msg.ID, &idStr)
		c.mu.Lock()
		ch, ok := c.waiters[idStr]
		c.mu.Unlock()
		if ok {
			ch <- msg
		}
	}
}

func failIf(err error) {
	if err != nil {
		log.Fatal(err)
	}
}
