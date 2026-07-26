package gooseconfig

import "testing"

func TestRenderKeysEnv_SortsAndMerges(t *testing.T) {
	got := string(RenderKeysEnv([]map[string]any{
		{"ANTHROPIC_API_KEY": "sk-a", "FOO": "1"},
		{"FOO": "2", "BAR": "x"}, // FOO overridden by later set
	}))
	want := "ANTHROPIC_API_KEY=sk-a\nBAR=x\nFOO=2\n"
	if got != want {
		t.Fatalf("got %q want %q", got, want)
	}
}
