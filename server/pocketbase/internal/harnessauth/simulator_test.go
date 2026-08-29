package harnessauth

import "testing"

func TestParseCodexChallengeStripsANSISequences(t *testing.T) {
	challenge := parseCodexChallenge("\x1b[94mhttps://auth.openai.com/codex/device\x1b[0m\n" +
		"Enter this one-time code \x1b[94m9OCA-MITN8\x1b[0m")

	if challenge == nil {
		t.Fatal("expected a Codex device challenge")
	}
	if challenge.Target != "https://auth.openai.com/codex/device" {
		t.Fatalf("challenge.Target = %q", challenge.Target)
	}
	if challenge.Text != "Enter this code: 9OCA-MITN8" {
		t.Fatalf("challenge.Text = %q", challenge.Text)
	}
}

func TestParseCodexChallengeReturnsBrowserDeviceCode(t *testing.T) {
	got := parseCodexChallenge("https://auth.openai.com/codex/device\nEnter this one-time code 9OCA-MITN8")
	if got.Kind != "device_code" || got.UserCode != "9OCA-MITN8" || got.CodeDestination != "browser" {
		t.Fatalf("unexpected Codex challenge: %+v", got)
	}
}

func TestParseClaudeChallengeReturnsAppCodeDestination(t *testing.T) {
	got := parseClaudeChallenge("https://example.test/authorize")
	if got.Kind != "browser_code" || got.CodeDestination != "app" {
		t.Fatalf("unexpected Claude challenge: %+v", got)
	}
}
