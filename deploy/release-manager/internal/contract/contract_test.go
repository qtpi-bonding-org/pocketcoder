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
	if err := ValidatePointer(pointer, "stable", "https://images.pocketcoder.org", 1<<20); err != nil {
		t.Fatal(err)
	}
}

func TestStrictDecodeRejectsUnknownAndDuplicateMembers(t *testing.T) {
	for name, data := range map[string][]byte{
		"unknown":   []byte(`{"schemaVersion":1,"unknown":true}`),
		"duplicate": []byte(`{"schemaVersion":1,"schemaVersion":1}`),
	} {
		t.Run(name, func(t *testing.T) {
			var envelope SignatureEnvelope
			if err := DecodeStrict(data, &envelope); err == nil {
				t.Fatal("expected strict decoding to fail")
			}
		})
	}
}
