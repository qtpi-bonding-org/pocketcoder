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

// @pocketcoder-core: ACP Transport. WebSocket adapter bridging the coder/acp-go-sdk connection to goose serve.
package acp

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/url"
	"strings"
	"sync"

	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/coder/websocket"
)

// wsURLWithToken carries the Goose secret in the WS URL as ?token=<secret>.
// Goose enforces auth on the WebSocket upgrade via this query parameter (the
// browser WebSocket API cannot set headers); the X-Secret-Key header remains
// for HTTP parity. An empty secret leaves the URL untouched.
func wsURLWithToken(rawURL, secret string) (string, error) {
	if secret == "" {
		return rawURL, nil
	}
	u, err := url.Parse(rawURL)
	if err != nil {
		return "", fmt.Errorf("parse ACP URL: %w", err)
	}
	q := u.Query()
	q.Set("token", secret)
	u.RawQuery = q.Encode()
	return u.String(), nil
}

type DialConfig struct{ URL, Secret string }

type Conn interface {
	Initialize(context.Context, acpsdk.InitializeRequest) (acpsdk.InitializeResponse, error)
	NewSession(context.Context, acpsdk.NewSessionRequest) (acpsdk.NewSessionResponse, error)
	LoadSession(context.Context, acpsdk.LoadSessionRequest) (acpsdk.LoadSessionResponse, error)
	ResumeSession(context.Context, acpsdk.ResumeSessionRequest) (acpsdk.ResumeSessionResponse, error)
	SetSessionMode(context.Context, acpsdk.SetSessionModeRequest) (acpsdk.SetSessionModeResponse, error)
	SetSessionConfigOption(context.Context, acpsdk.SetSessionConfigOptionRequest) (acpsdk.SetSessionConfigOptionResponse, error)
	CallExtension(ctx context.Context, method string, params any) (json.RawMessage, error)
	Prompt(context.Context, acpsdk.PromptRequest) (acpsdk.PromptResponse, error)
	Cancel(context.Context, acpsdk.CancelNotification) error
	UnstableDeleteSession(context.Context, acpsdk.UnstableDeleteSessionRequest) (acpsdk.UnstableDeleteSessionResponse, error)
	Done() <-chan struct{}
	Close() error
}

var _ Conn = (*sdkConn)(nil)

type wsStream struct {
	ctx  context.Context
	conn *websocket.Conn
	rbuf bytes.Buffer
	wmu  sync.Mutex
	wbuf bytes.Buffer
}

func (w *wsStream) Read(p []byte) (int, error) {
	if w.rbuf.Len() == 0 {
		_, data, err := w.conn.Read(w.ctx)
		if err != nil {
			return 0, err
		}
		w.rbuf.Write(data)
		w.rbuf.WriteByte('\n')
	}
	return w.rbuf.Read(p)
}

func (w *wsStream) Write(p []byte) (int, error) {
	w.wmu.Lock()
	defer w.wmu.Unlock()
	w.wbuf.Write(p)
	for {
		line, err := w.wbuf.ReadString('\n')
		if err != nil {
			w.wbuf.Reset()
			w.wbuf.WriteString(line)
			break
		}
		msg := strings.TrimRight(line, "\r\n")
		if msg != "" {
			if err := w.conn.Write(w.ctx, websocket.MessageText, []byte(msg)); err != nil {
				return 0, err
			}
		}
	}
	return len(p), nil
}

func (w *wsStream) Close() error { return w.conn.Close(websocket.StatusNormalClosure, "") }

type sdkConn struct {
	*acpsdk.ClientSideConnection
	stream *wsStream
}

func dialWS(ctx context.Context, rawURL, secret string) (*wsStream, error) {
	dialURL, err := wsURLWithToken(rawURL, secret)
	if err != nil {
		return nil, err
	}
	opts := &websocket.DialOptions{}
	if secret != "" {
		opts.HTTPHeader = map[string][]string{"X-Secret-Key": {secret}}
	}
	conn, _, err := websocket.Dial(ctx, dialURL, opts)
	if err != nil {
		return nil, err
	}
	conn.SetReadLimit(64 << 20)
	return &wsStream{ctx: ctx, conn: conn}, nil
}

func (c *sdkConn) Close() error { return c.stream.Close() }

func Dial(ctx context.Context, cfg DialConfig, client acpsdk.Client) (Conn, error) {
	if cfg.URL == "" {
		return nil, fmt.Errorf("ACP URL is required")
	}
	// TODO(ws-auth): Goose v1.36.0 does not enforce this header on its WS
	// endpoint; network isolation is the effective control until upstream does.
	stream, err := dialWS(ctx, cfg.URL, cfg.Secret)
	if err != nil {
		return nil, err
	}
	return &sdkConn{ClientSideConnection: acpsdk.NewClientSideConnection(client, stream, stream), stream: stream}, nil
}
