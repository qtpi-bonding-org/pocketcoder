package contract

import (
	"os"
	"path/filepath"
	"testing"
)

func fixture(t *testing.T, name string) []byte {
	t.Helper()
	data, err := os.ReadFile(filepath.Join("..", "..", "..", "release", name))
	if err != nil {
		t.Fatal(err)
	}
	return data
}

func TestManifestExampleDecodesAndValidates(t *testing.T) {
	var manifest Manifest
	if err := DecodeStrict(fixture(t, "release-manifest.example.json"), &manifest); err != nil {
		t.Fatal(err)
	}
	if err := ValidateManifest(manifest); err != nil {
		t.Fatal(err)
	}
}

func TestChannelExampleDecodesAndValidates(t *testing.T) {
	var pointer ChannelPointer
	if err := DecodeStrict(fixture(t, "release-channel-pointer.example.json"), &pointer); err != nil {
		t.Fatal(err)
	}
	if err := ValidatePointer(pointer, "stable", "stable", "https://images.relay.pocketcoder.org", 1<<20); err != nil {
		t.Fatal(err)
	}
}

func TestStrictDecodeRejectsUnknownAndDuplicateMembers(t *testing.T) {
	for name, data := range map[string][]byte{
		"unknown":   []byte(`{"schemaVersion":1,"unknown":true}`),
		"duplicate": []byte(`{"schemaVersion":1,"schemaVersion":1}`),
	} {
		t.Run(name, func(t *testing.T) {
			var pointer ChannelPointer
			if err := DecodeStrict(data, &pointer); err == nil {
				t.Fatal("expected strict decoding to fail")
			}
		})
	}
}

// DecodeForward is what the box uses to parse a channel pointer, release
// manifest, or revocations list freshly fetched from the relay -- it must
// tolerate fields a future publisher adds that this binary's compiled
// struct doesn't know about yet, or every already-provisioned box would be
// permanently unable to parse any manifest published after it shipped
// (see decode.go's DecodeForward doc comment for why that's unrecoverable).
func TestForwardDecodeToleratesUnknownFieldsButRejectsDuplicatesAndTrailing(t *testing.T) {
	var pointer ChannelPointer
	if err := DecodeForward([]byte(`{"schemaVersion":1,"channel":"stable","aFutureField":{"nested":true}}`), &pointer); err != nil {
		t.Fatalf("expected unknown field to be tolerated, got %v", err)
	}
	if pointer.Channel != "stable" {
		t.Fatalf("expected known fields to still decode, got channel %q", pointer.Channel)
	}

	if err := DecodeForward([]byte(`{"schemaVersion":1,"schemaVersion":1}`), &pointer); err == nil {
		t.Fatal("expected duplicate member rejection to still apply")
	}

	if err := DecodeForward([]byte(`{"schemaVersion":1}{"trailing":true}`), &pointer); err == nil {
		t.Fatal("expected trailing JSON rejection to still apply")
	}
}

func TestValidateManifestRejectsInvalidOrMissingNixosVersion(t *testing.T) {
	var manifest Manifest
	if err := DecodeForward(fixture(t, "release-manifest.example.json"), &manifest); err != nil {
		t.Fatal(err)
	}

	for name, version := range map[string]string{
		"empty":            "",
		"missing-dot":      "2605",
		"branch-style":     "nixos-26.05",
		"three-components": "26.05.1",
	} {
		t.Run(name, func(t *testing.T) {
			broken := manifest
			broken.Compatibility.OS.NixosVersion = version
			if err := ValidateManifest(broken); err == nil {
				t.Fatalf("expected nixosVersion %q to be rejected", version)
			}
		})
	}

	valid := manifest
	valid.Compatibility.OS.NixosVersion = "26.05"
	if err := ValidateManifest(valid); err != nil {
		t.Fatalf("expected a valid nixosVersion to pass, got %v", err)
	}
}
