package snapshot

import (
	"os"
	"path/filepath"
	"testing"
)

func TestArchiveRoundTripAndDigest(t *testing.T) {
	source := t.TempDir()
	if err := os.MkdirAll(filepath.Join(source, "nested"), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(source, "nested", "data.db"), []byte("pocketbase-data"), 0o600); err != nil {
		t.Fatal(err)
	}
	archive := filepath.Join(t.TempDir(), "snapshot.tar.gz")
	if err := createArchive(source, archive); err != nil {
		t.Fatal(err)
	}
	digest, bytes, err := digestFile(archive)
	if err != nil {
		t.Fatal(err)
	}
	if len(digest) != 64 || bytes < 1 {
		t.Fatalf("digest=%q bytes=%d", digest, bytes)
	}
	destination := t.TempDir()
	if err := extractArchive(archive, destination); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(destination, "nested", "data.db"))
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != "pocketbase-data" {
		t.Fatalf("restored data = %q", data)
	}
}
