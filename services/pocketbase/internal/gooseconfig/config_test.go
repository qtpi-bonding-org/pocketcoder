package gooseconfig

import "testing"

func TestRenderConfigYAML_NoExtensionsKey(t *testing.T) {
	got, err := RenderConfigYAML(ConfigInput{
		Provider: "anthropic", Model: "MiniMax-M2.5", Mode: "approve",
	})
	if err != nil {
		t.Fatal(err)
	}
	want := "GOOSE_MODE: approve\nGOOSE_MODEL: MiniMax-M2.5\nGOOSE_PROVIDER: anthropic\n"
	if string(got) != want {
		t.Fatalf("config.yaml mismatch:\n--- got ---\n%s\n--- want ---\n%s", got, want)
	}
}
