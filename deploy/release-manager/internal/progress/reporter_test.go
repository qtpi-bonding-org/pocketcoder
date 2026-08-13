package progress

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestReporterPreservesRunAndAdvancesPhase(t *testing.T) {
	path := filepath.Join(t.TempDir(), "status.json")
	reporter := New(
		path,
		"run-1",
		"unknown",
		"ssh-ed25519",
		"MD5:00:11:22:33:44:55:66:77:88:99:aa:bb:cc:dd:ee:ff",
		nil,
	)
	reporter.SetSourceCommit("0123456789abcdef")
	reporter.Report("loading_images", "required.core")

	value := readDocument(t, path)
	if value.RunID != "run-1" || value.Phase != "loading_images" ||
		value.Detail != "required.core" || value.SourceCommit != "0123456789abcdef" {
		t.Fatalf("unexpected status document: %#v", value)
	}
	if value.Error != "" {
		t.Fatalf("unexpected error: %q", value.Error)
	}
	if value.SSHHostKey == nil || value.SSHHostKey.Type != "ssh-ed25519" {
		t.Fatalf("SSH host identity was not retained: %#v", value.SSHHostKey)
	}

	reporter.Fail("release_install_failed")
	value = readDocument(t, path)
	if value.Phase != "loading_images" || value.Error != "release_install_failed" {
		t.Fatalf("unexpected failure document: %#v", value)
	}
}

func TestReporterHeartbeatRefreshesStatus(t *testing.T) {
	path := filepath.Join(t.TempDir(), "status.json")
	reporter := New(path, "run-2", "commit", "", "", nil)
	reporter.Report("compose_up", "starting")
	first := readDocument(t, path).UpdatedAt

	stop := reporter.StartHeartbeat(10 * time.Millisecond)
	t.Cleanup(stop)
	time.Sleep(1100 * time.Millisecond)
	second := readDocument(t, path).UpdatedAt
	if first == second {
		t.Fatalf("heartbeat did not refresh updatedAt: %q", first)
	}
}

func readDocument(t *testing.T, path string) document {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var value document
	if err := json.Unmarshal(data, &value); err != nil {
		t.Fatal(err)
	}
	return value
}
