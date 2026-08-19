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
	if value.Schema != 3 || value.RunID != "run-1" || value.Operation != "loading_images" ||
		value.Detail != "required.core" || value.SourceCommit != "0123456789abcdef" {
		t.Fatalf("unexpected status document: %#v", value)
	}
	if value.ErrorCode != "" {
		t.Fatalf("unexpected error: %q", value.ErrorCode)
	}
	if value.SSHHostKey == nil || value.SSHHostKey.Type != "ssh-ed25519" {
		t.Fatalf("SSH host identity was not retained: %#v", value.SSHHostKey)
	}

	reporter.Fail("release_install_failed")
	value = readDocument(t, path)
	if value.Operation != "loading_images" || value.ErrorCode != "release_install_failed" {
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

type testDocument struct {
	Schema       int         `json:"schema"`
	RunID        string      `json:"runId"`
	Operation    string      `json:"operation"`
	Detail       string      `json:"detail"`
	SourceCommit string      `json:"sourceCommit"`
	UpdatedAt    string      `json:"updatedAt"`
	ErrorCode    string      `json:"errorCode"`
	ErrorMessage string      `json:"errorMessage"`
	SSHHostKey   *sshHostKey `json:"sshHostKey"`
}

func readDocument(t *testing.T, path string) testDocument {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var value testDocument
	if err := json.Unmarshal(data, &value); err != nil {
		t.Fatal(err)
	}
	return value
}

func TestReporterPreservesUnknownFields(t *testing.T) {
	path := filepath.Join(t.TempDir(), "status.json")
	if err := os.WriteFile(path, []byte(`{"schema":2,"tls":{"state":"ready"},"future":true}`), 0o644); err != nil {
		t.Fatal(err)
	}
	reporter := New(path, "run-3", "commit", "", "", nil)
	reporter.Report("compose_up", "starting")
	var value map[string]json.RawMessage
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if err := json.Unmarshal(data, &value); err != nil {
		t.Fatal(err)
	}
	var tls map[string]string
	if err := json.Unmarshal(value["tls"], &tls); err != nil || tls["state"] != "ready" || string(value["future"]) != "true" {
		t.Fatalf("reporter discarded fields it does not own: %s", data)
	}
}
