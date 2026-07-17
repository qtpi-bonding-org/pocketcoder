// Package acp implements the Streamable HTTP transport used by Goose's ACP
// server. The upstream ACP Go SDK provides generated protocol types, but its
// connection helper is stdio-oriented; the HTTP lifecycle belongs here.
package acp

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/cookiejar"
	"strings"
	"sync"
	"sync/atomic"
)

const (
	connectionHeader = "Acp-Connection-Id"
	sessionHeader    = "Acp-Session-Id"
)

// Config is the private c1-to-c2 connection configuration. Secret must never
// be sent to a browser client or included in an AG-UI event.
type Config struct {
	URL    string
	Secret string
	Client *http.Client
}

// Message is a JSON-RPC 2.0 envelope sent over the Streamable HTTP profile.
type Message struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      json.RawMessage `json:"id,omitempty"`
	Method  string          `json:"method,omitempty"`
	Params  json.RawMessage `json:"params,omitempty"`
	Result  json.RawMessage `json:"result,omitempty"`
	Error   json.RawMessage `json:"error,omitempty"`
}

// NotificationHandler receives ACP notifications and agent-originated
// requests. Permission and tool callbacks are deliberately handled by c1's
// coordinator, not by this transport.
type NotificationHandler func(Message)

// Client owns one Streamable HTTP connection to Goose. It is safe for
// concurrent calls after Initialize completes.
type Client struct {
	url, secret string
	http        *http.Client

	connectionID string
	nextID       atomic.Uint64

	mu       sync.Mutex
	waiters  map[string]chan Message
	handlers []NotificationHandler
}

// NewClient validates static configuration and creates a cookie-aware client
// when the caller did not provide one.
func NewClient(cfg Config) (*Client, error) {
	if cfg.URL == "" {
		return nil, fmt.Errorf("ACP URL is required")
	}
	if cfg.Secret == "" {
		return nil, fmt.Errorf("ACP secret is required")
	}
	client := cfg.Client
	if client == nil {
		jar, err := cookiejar.New(nil)
		if err != nil {
			return nil, fmt.Errorf("create cookie jar: %w", err)
		}
		client = &http.Client{Jar: jar}
	}
	return &Client{url: cfg.URL, secret: cfg.Secret, http: client, waiters: make(map[string]chan Message)}, nil
}

// Initialize establishes the c2 connection. Goose returns the connection ID
// synchronously; every later request is accepted (202) and answered on SSE.
func (c *Client) Initialize(ctx context.Context, clientCapabilities any) (json.RawMessage, error) {
	params, err := json.Marshal(map[string]any{
		"protocolVersion":    1,
		"clientCapabilities": clientCapabilities,
	})
	if err != nil {
		return nil, fmt.Errorf("encode initialize: %w", err)
	}
	resp, err := c.post(ctx, Message{JSONRPC: "2.0", ID: json.RawMessage("1"), Method: "initialize", Params: params}, "")
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, responseError("initialize", resp)
	}
	c.connectionID = resp.Header.Get(connectionHeader)
	if c.connectionID == "" {
		return nil, fmt.Errorf("initialize response missing %s", connectionHeader)
	}
	var message Message
	if err := json.NewDecoder(resp.Body).Decode(&message); err != nil {
		return nil, fmt.Errorf("decode initialize response: %w", err)
	}
	if len(message.Error) > 0 {
		return nil, fmt.Errorf("initialize RPC error: %s", message.Error)
	}
	return message.Result, nil
}

// OnNotification registers a process-local callback. Callbacks must return
// quickly; use the coordinator for work that may block on phone approval.
func (c *Client) OnNotification(handler NotificationHandler) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.handlers = append(c.handlers, handler)
}

// OpenStream starts the connection-wide stream (sessionID empty) or the
// stream for an ACP session. Its lifetime is controlled by ctx.
func (c *Client) OpenStream(ctx context.Context, sessionID string) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.url, nil)
	if err != nil {
		return fmt.Errorf("create ACP stream request: %w", err)
	}
	req.Header.Set("Accept", "text/event-stream")
	req.Header.Set("X-Secret-Key", c.secret)
	req.Header.Set(connectionHeader, c.connectionID)
	if sessionID != "" {
		req.Header.Set(sessionHeader, sessionID)
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return fmt.Errorf("open ACP stream: %w", err)
	}
	if resp.StatusCode != http.StatusOK {
		defer resp.Body.Close()
		return responseError("open ACP stream", resp)
	}
	go c.readStream(ctx, resp.Body)
	return nil
}

// Call sends a request and waits for the matching JSON-RPC response on the
// already-open SSE stream. The prompt response is the authoritative terminal
// event for a run, including a cancelled run.
func (c *Client) Call(ctx context.Context, method string, params any, sessionID string) (json.RawMessage, error) {
	id := fmt.Sprintf("%d", c.nextID.Add(1)+1)
	body, err := json.Marshal(params)
	if err != nil {
		return nil, fmt.Errorf("encode %s params: %w", method, err)
	}
	waiter := make(chan Message, 1)
	c.mu.Lock()
	c.waiters[id] = waiter
	c.mu.Unlock()
	defer func() {
		c.mu.Lock()
		delete(c.waiters, id)
		c.mu.Unlock()
	}()

	resp, err := c.post(ctx, Message{JSONRPC: "2.0", ID: json.RawMessage(id), Method: method, Params: body}, sessionID)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusAccepted {
		return nil, responseError(method, resp)
	}
	select {
	case reply := <-waiter:
		if len(reply.Error) > 0 {
			return nil, fmt.Errorf("%s RPC error: %s", method, reply.Error)
		}
		return reply.Result, nil
	case <-ctx.Done():
		return nil, ctx.Err()
	}
}

// Notify sends a JSON-RPC notification such as session/cancel.
func (c *Client) Notify(ctx context.Context, method string, params any, sessionID string) error {
	body, err := json.Marshal(params)
	if err != nil {
		return fmt.Errorf("encode %s params: %w", method, err)
	}
	resp, err := c.post(ctx, Message{JSONRPC: "2.0", Method: method, Params: body}, sessionID)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusAccepted {
		return responseError(method, resp)
	}
	return nil
}

// Respond resolves an agent-originated request, including
// session/request_permission, over the session stream.
func (c *Client) Respond(ctx context.Context, id json.RawMessage, result any, sessionID string) error {
	body, err := json.Marshal(result)
	if err != nil {
		return fmt.Errorf("encode ACP response: %w", err)
	}
	resp, err := c.post(ctx, Message{JSONRPC: "2.0", ID: id, Result: body}, sessionID)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusAccepted {
		return responseError("ACP response", resp)
	}
	return nil
}

// RespondError rejects an agent-originated request without attempting a local
// fallback. c1 uses this when the sandbox boundary rejects an ACP callback.
func (c *Client) RespondError(ctx context.Context, id json.RawMessage, code int, message string, sessionID string) error {
	errBody, err := json.Marshal(map[string]any{"code": code, "message": message})
	if err != nil {
		return fmt.Errorf("encode ACP error response: %w", err)
	}
	resp, err := c.post(ctx, Message{JSONRPC: "2.0", ID: id, Error: errBody}, sessionID)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusAccepted {
		return responseError("ACP error response", resp)
	}
	return nil
}

func (c *Client) post(ctx context.Context, message Message, sessionID string) (*http.Response, error) {
	body, err := json.Marshal(message)
	if err != nil {
		return nil, fmt.Errorf("encode ACP request: %w", err)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.url, bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("create ACP request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json, text/event-stream")
	req.Header.Set("X-Secret-Key", c.secret)
	if c.connectionID != "" {
		req.Header.Set(connectionHeader, c.connectionID)
	}
	if sessionID != "" {
		req.Header.Set(sessionHeader, sessionID)
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("send ACP request: %w", err)
	}
	return resp, nil
}

func (c *Client) readStream(ctx context.Context, body io.ReadCloser) {
	defer body.Close()
	scanner := bufio.NewScanner(body)
	scanner.Buffer(make([]byte, 4096), 4<<20)
	var data []string
	for scanner.Scan() {
		line := scanner.Text()
		if line != "" {
			if strings.HasPrefix(line, "data:") {
				data = append(data, strings.TrimSpace(strings.TrimPrefix(line, "data:")))
			}
			continue
		}
		if len(data) == 0 {
			continue
		}
		var message Message
		raw := strings.Join(data, "\n")
		data = nil
		if json.Unmarshal([]byte(raw), &message) != nil {
			continue
		}
		if message.Method != "" {
			c.mu.Lock()
			handlers := append([]NotificationHandler(nil), c.handlers...)
			c.mu.Unlock()
			for _, handler := range handlers {
				handler(message)
			}
			continue
		}
		c.mu.Lock()
		waiter := c.waiters[string(message.ID)]
		c.mu.Unlock()
		if waiter != nil {
			select {
			case waiter <- message:
			case <-ctx.Done():
			}
		}
	}
}

func responseError(operation string, resp *http.Response) error {
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 64<<10))
	return fmt.Errorf("%s status=%s body=%s", operation, resp.Status, strings.TrimSpace(string(body)))
}
