package manager

import (
	"os"
	"path/filepath"
	"testing"
)

func TestRestoreDataFailsWithNoBackupPresent(t *testing.T) {
	dataDir := t.TempDir()
	backupDir := t.TempDir()
	err := RestoreData(RestoreDataConfig{
		DataDir: dataDir, BackupDir: backupDir,
		Docker: &fakeDocker{},
	})
	if err == nil {
		t.Fatal("expected an error when no backup file exists")
	}
}

func TestRestoreDataCopiesBackupOverLiveData(t *testing.T) {
	dataDir := t.TempDir()
	backupDir := t.TempDir()
	if err := os.WriteFile(filepath.Join(backupDir, "data.db"), []byte("backup-content"), 0o644); err != nil {
		t.Fatal(err)
	}
	docker := &fakeDocker{}
	err := RestoreData(RestoreDataConfig{
		DataDir: dataDir, BackupDir: backupDir,
		Docker: docker,
	})
	if err != nil {
		t.Fatalf("RestoreData: %v", err)
	}
	got, err := os.ReadFile(filepath.Join(dataDir, "data.db"))
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != "backup-content" {
		t.Fatalf("data.db = %q, want %q", got, "backup-content")
	}
	if !docker.stopped || !docker.started {
		t.Fatalf("expected container stop then start, got stopped=%v started=%v", docker.stopped, docker.started)
	}
}

type fakeDocker struct{ stopped, started bool }

func (f *fakeDocker) Stop(container string) error  { f.stopped = true; return nil }
func (f *fakeDocker) Start(container string) error { f.started = true; return nil }
