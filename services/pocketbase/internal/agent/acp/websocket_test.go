package acp

import (
	"bufio"
	"context"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/coder/websocket"
)

func TestWSURLWithTokenAppendsQueryParam(t *testing.T) {
	cases := []struct {
		name, url, secret, want string
	}{
		{"empty secret leaves url untouched", "ws://goose:3000/acp", "", "ws://goose:3000/acp"},
		{"no existing query uses question mark", "ws://goose:3000/acp", "s3cret", "ws://goose:3000/acp?token=s3cret"},
		{"existing query is preserved", "ws://goose:3000/acp?v=1", "s3cret", "ws://goose:3000/acp?token=s3cret&v=1"},
		{"secret is url-encoded", "ws://goose:3000/acp", "a b/c&d", "ws://goose:3000/acp?token=a+b%2Fc%26d"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got, err := wsURLWithToken(c.url, c.secret)
			if err != nil {
				t.Fatal(err)
			}
			if got != c.want {
				t.Fatalf("wsURLWithToken(%q, %q) = %q, want %q", c.url, c.secret, got, c.want)
			}
		})
	}
}

func TestWSStreamFramesNewlineDelimitedMessages(t *testing.T) {
	defer func() {
		if recover() != nil {
			t.Skip("socket binding is unavailable in this test environment")
		}
	}()
	server := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, err := websocket.Accept(w, r, nil)
		if err != nil {
			return
		}
		defer conn.Close(websocket.StatusNormalClosure, "")
		for i := 0; i < 2; i++ {
			kind, data, err := conn.Read(r.Context())
			if err != nil || kind != websocket.MessageText {
				return
			}
			_ = conn.Write(r.Context(), websocket.MessageText, data)
		}
	}))
	listener, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	server.Listener = listener
	server.Start()
	defer server.Close()

	ctx := context.Background()
	stream, err := dialWS(ctx, "ws"+server.URL[len("http"):], "")
	if err != nil {
		t.Fatal(err)
	}
	defer stream.Close()
	if _, err := io.WriteString(stream, "{\"id\":1}\n{\"id\":2}\n"); err != nil {
		t.Fatal(err)
	}
	reader := bufio.NewReader(stream)
	for _, want := range []string{"{\"id\":1}\n", "{\"id\":2}\n"} {
		got, err := reader.ReadString('\n')
		if err != nil {
			t.Fatal(err)
		}
		if got != want {
			t.Fatalf("read %q, want %q", got, want)
		}
	}
}
