package api

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestOllamaModelInstalledUsesLiveTags(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/tags" {
			t.Fatalf("path = %q, want /api/tags", r.URL.Path)
		}
		_, _ = w.Write([]byte(`{"models":[{"name":"qwen3:0.6b","size":523000000}]}`))
	}))
	defer server.Close()
	t.Setenv("OLLAMA_API_URL", server.URL)

	installed, err := ollamaModelInstalled(context.Background(), server.Client(), "qwen3:0.6b")
	if err != nil {
		t.Fatal(err)
	}
	if !installed {
		t.Fatal("expected tag returned by /api/tags to be installed")
	}
	missing, err := ollamaModelInstalled(context.Background(), server.Client(), "qwen2.5:0.5b")
	if err != nil {
		t.Fatal(err)
	}
	if missing {
		t.Fatal("tag absent from /api/tags must not be considered installed")
	}
}
