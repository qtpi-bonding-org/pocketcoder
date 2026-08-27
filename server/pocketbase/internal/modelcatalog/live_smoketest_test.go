package modelcatalog

import (
	"context"
	"net/http"
	"os"
	"testing"
)

// TestLiveModelsDevSmoke hits the real models.dev endpoint once to confirm
// Fetch's minimal decode still matches the live schema. Skipped unless
// POCKETCODER_LIVE_MODELCATALOG_TEST=1, since it needs real network access
// and shouldn't run in normal CI.
func TestLiveModelsDevSmoke(t *testing.T) {
	if os.Getenv("POCKETCODER_LIVE_MODELCATALOG_TEST") != "1" {
		t.Skip("set POCKETCODER_LIVE_MODELCATALOG_TEST=1 to hit the real models.dev endpoint")
	}
	providers, err := Fetch(context.Background(), http.DefaultClient, DefaultCatalogURL)
	if err != nil {
		t.Fatal(err)
	}
	if len(providers) < 50 {
		t.Fatalf("got %d providers from live models.dev, want at least 50", len(providers))
	}
	anthropic, ok := providers["anthropic"]
	if !ok {
		t.Fatal("live catalog missing anthropic provider")
	}
	if anthropic.APIKeyEnv != "ANTHROPIC_API_KEY" {
		t.Errorf("anthropic.APIKeyEnv = %q, want ANTHROPIC_API_KEY", anthropic.APIKeyEnv)
	}
	if len(anthropic.Models) == 0 {
		t.Error("live anthropic provider has no models")
	}
	t.Logf("fetched %d providers live; anthropic has %d models", len(providers), len(anthropic.Models))
}
