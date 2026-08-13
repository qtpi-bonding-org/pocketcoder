package state

import (
	"os"
	"path/filepath"
	"testing"
)

func TestWriteAtomicAndSequenceReplay(t *testing.T) {
	path := filepath.Join(t.TempDir(), "state", "sequences.json")
	want := Sequences{"channel-stable": 4, "revocation": 2}
	if err := WriteJSONAtomic(path, want, 0o600); err != nil {
		t.Fatal(err)
	}
	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o600 {
		t.Fatalf("mode = %o", info.Mode().Perm())
	}
	got, err := LoadSequences(path)
	if err != nil {
		t.Fatal(err)
	}
	if err := got.Accept("channel-stable", 3, 1); err == nil {
		t.Fatal("expected replay rejection")
	}
	if err := got.Accept("channel-stable", 4, 1); err != nil {
		t.Fatal(err)
	}
}

func TestMutationLockIsExclusive(t *testing.T) {
	path := filepath.Join(t.TempDir(), "mutation.lock")
	first, err := AcquireLock(path)
	if err != nil {
		t.Fatal(err)
	}
	defer first.Close()
	if second, err := AcquireLock(path); err == nil {
		second.Close()
		t.Fatal("expected concurrent lock acquisition to fail")
	}
}
