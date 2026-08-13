package runtime

import (
	"os"
	"path/filepath"
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
