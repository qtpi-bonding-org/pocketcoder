package gooseconfig

import (
	"os"
	"testing"
)

func TestRenderConfigYAML_Golden(t *testing.T) {
	got, err := RenderConfigYAML(ConfigInput{
		Provider: "anthropic", Model: "MiniMax-M2.5", Mode: "approve",
		AvailableTools: map[string][]string{"developer": {"read", "write"}},
	})
	if err != nil {
		t.Fatal(err)
	}
	want, err := os.ReadFile("testdata/config_basic.yaml")
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != string(want) {
		t.Fatalf("config.yaml mismatch:\n--- got ---\n%s\n--- want ---\n%s", got, want)
	}
}
