package main

import (
	"bytes"
	"context"
	"strings"
	"sync"

	"github.com/coder/websocket"
)

// wsStream adapts a WebSocket connection to the io.Reader/io.Writer byte stream
// the ACP SDK's ClientSideConnection expects. Each WS text frame carries one
// JSON-RPC message; we present them to the SDK as newline-delimited JSON, and
// send each newline-delimited message the SDK writes as its own WS frame.
//
// This is the whole WS question: if a ~40-line adapter lets the robust SDK
// connection run unmodified over goose serve's WebSocket, WS retires both the
// hand-rolled streamable.go and the stdio socat/shim.
type wsStream struct {
	ctx  context.Context
	conn *websocket.Conn
	rbuf bytes.Buffer
	wmu  sync.Mutex
	wbuf bytes.Buffer
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
			// No complete message yet; hold the remainder for the next Write.
			remainder := line
			w.wbuf.Reset()
			w.wbuf.WriteString(remainder)
			break
		}
		msg := strings.TrimRight(line, "\r\n")
		if msg == "" {
			continue
		}
		if err := w.conn.Write(w.ctx, websocket.MessageText, []byte(msg)); err != nil {
			return 0, err
		}
	}
	return len(p), nil
}

func (w *wsStream) Close() error {
	return w.conn.Close(websocket.StatusNormalClosure, "")
}
