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
