package runtime

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestPullImagePullsMissingImageAndVerifiesIt(t *testing.T) {
	directory := t.TempDir()
	marker := filepath.Join(directory, "pulled")
	script := `#!/bin/sh
set -eu
case "${1:-}:${2:-}" in
  image:inspect) test -f "$FAKE_DOCKER_PULLED" ;;
  pull:*) : > "$FAKE_DOCKER_PULLED" ;;
  *) exit 1 ;;
esac
`
	dockerPath := filepath.Join(directory, "docker")
	if err := os.WriteFile(dockerPath, []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("FAKE_DOCKER_PULLED", marker)
	t.Setenv("PATH", directory+string(os.PathListSeparator)+os.Getenv("PATH"))

	image := "example/runtime@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	if err := (Docker{}).PullImage(image); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(marker); err != nil {
		t.Fatalf("registry image was not pulled: %v", err)
	}
}

func TestComposeUpDoesNotHidePluginFailureWithLegacyFallback(t *testing.T) {
	directory := t.TempDir()
	dockerPath := filepath.Join(directory, "docker")
	script := `#!/bin/sh
set -eu
if [ "${1:-}" = network ]; then
  exit 0
fi
if [ "${1:-}" = compose ] && [ "${2:-}" = version ]; then
  exit 0
fi
if [ "${1:-}" = compose ]; then
  exit 42
fi
exit 1
`
	if err := os.WriteFile(dockerPath, []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", directory+string(os.PathListSeparator)+os.Getenv("PATH"))

	err := (Docker{}).ComposeUp("compose.yml", "runtime.env", nil)
	if err == nil || !strings.Contains(err.Error(), "exit status 42") {
		t.Fatalf("ComposeUp error = %v, want plugin failure", err)
	}
}

func TestComposeUpCapturesComposeLogsOnFailure(t *testing.T) {
	directory := t.TempDir()
	dockerPath := filepath.Join(directory, "docker")
	const logsMarker = "FAKE-COMPOSE-LOGS-OUTPUT-abc123"
	script := `#!/bin/sh
set -eu
if [ "${1:-}" = network ]; then
  exit 0
fi
if [ "${1:-}" = compose ] && [ "${2:-}" = version ]; then
  exit 0
fi
found_logs=0
for arg in "$@"; do
  if [ "$arg" = logs ]; then
    found_logs=1
  fi
done
if [ "$found_logs" = 1 ]; then
  echo "` + logsMarker + `"
  exit 0
fi
exit 1
`
	if err := os.WriteFile(dockerPath, []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", directory+string(os.PathListSeparator)+os.Getenv("PATH"))

	var stdout bytes.Buffer
	docker := Docker{Stdout: &stdout}
	err := docker.ComposeUp("compose.yml", "runtime.env", nil)
	if err == nil {
		t.Fatal("ComposeUp error = nil, want the up failure")
	}
	if !strings.Contains(stdout.String(), logsMarker) {
		t.Fatalf("ComposeUp did not capture compose logs on failure; Stdout = %q", stdout.String())
	}
}
