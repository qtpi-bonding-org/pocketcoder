package acp

import (
	"bytes"
	"context"
	"fmt"
	"strings"
	"sync"

	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/coder/websocket"
)

type DialConfig struct{ URL, Secret string }

type Conn interface {
	Initialize(context.Context, acpsdk.InitializeRequest) (acpsdk.InitializeResponse, error)
	NewSession(context.Context, acpsdk.NewSessionRequest) (acpsdk.NewSessionResponse, error)
	LoadSession(context.Context, acpsdk.LoadSessionRequest) (acpsdk.LoadSessionResponse, error)
	SetSessionMode(context.Context, acpsdk.SetSessionModeRequest) (acpsdk.SetSessionModeResponse, error)
	Prompt(context.Context, acpsdk.PromptRequest) (acpsdk.PromptResponse, error)
	Cancel(context.Context, acpsdk.CancelNotification) error
	Close() error
}

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

func dialWS(ctx context.Context, url, secret string) (*wsStream, error) {
	opts := &websocket.DialOptions{}
	if secret != "" {
		opts.HTTPHeader = map[string][]string{"X-Secret-Key": {secret}}
	}
	conn, _, err := websocket.Dial(ctx, url, opts)
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
