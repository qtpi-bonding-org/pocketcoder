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
	if anthropic.PrimaryAPIKeyEnv() != "ANTHROPIC_API_KEY" {
		t.Errorf("anthropic.PrimaryAPIKeyEnv() = %q, want ANTHROPIC_API_KEY", anthropic.PrimaryAPIKeyEnv())
	}
	google, ok := providers["google"]
	if !ok {
		t.Fatal("live catalog missing google provider")
	}
	if len(google.APIKeyEnvs) < 2 {
		t.Errorf("live google.APIKeyEnvs = %v, want at least 2 accepted names (this is the motivating multi-name case)", google.APIKeyEnvs)
	}
	if len(anthropic.Models) == 0 {
		t.Error("live anthropic provider has no models")
	}
	t.Logf("fetched %d providers live; anthropic has %d models; google accepts %v", len(providers), len(anthropic.Models), google.APIKeyEnvs)
}
