package executor

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	acp "github.com/coder/acp-go-sdk"
)

func TestSandboxRejectsOutsideWorkspaceWithoutCallingService(t *testing.T) {
	called := false
	server := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { called = true }))
	defer server.Close()
	sandbox, err := New(Config{URL: server.URL, Workspace: "/workspace"})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := sandbox.ReadTextFile(context.Background(), acp.ReadTextFileRequest{Path: "/etc/passwd"}); err == nil {
		t.Fatal("expected path rejection")
	}
	if called {
		t.Fatal("outside path reached sandbox")
	}
}

func TestSandboxForwardsFilesystemRequest(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/acp/fs/read" {
			t.Fatalf("path = %s", r.URL.Path)
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"content":"sandbox only"}`))
	}))
	defer server.Close()
	sandbox, err := New(Config{URL: server.URL, Workspace: "/workspace"})
	if err != nil {
		t.Fatal(err)
	}
	result, err := sandbox.ReadTextFile(context.Background(), acp.ReadTextFileRequest{Path: "/workspace/file.txt"})
	if err != nil || result.Content != "sandbox only" {
		t.Fatalf("result=%#v err=%v", result, err)
	}
}
