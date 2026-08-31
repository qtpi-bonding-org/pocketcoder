//go:build integration

package runtime

import (
	"fmt"
	"os"
	"os/exec"
	"testing"
)

// TestEnsureNetworkCreatesAMissingNetworkAndIsIdempotent is a regression test
// for a live incident: pocketcoder-harness-egress is declared in
// docker-compose.yml's top-level networks but deliberately not attached to
// any static service there -- only dynamically-created harness containers
// join it later, outside Compose's own service graph. Compose only
// materializes a declared network if some service in the same file
// references it (confirmed empirically: an unreferenced top-level network is
// never created by `docker compose up`), so a freshly deployed box never got
// this network at all, and every harness container creation failed with
// "docker API returned 404 Not Found: ... network pocketcoder-harness-egress
// not found". ComposeUp now calls ensureNetwork(harnessEgressNetwork) to fix
// this; this test exercises ensureNetwork's own create/idempotent behavior
// directly, against a throwaway test-scoped name -- NOT the real
// "pocketcoder-harness-egress" literal, since a real local dev stack on this
// machine already has live containers attached to that exact network name,
// and removing it out from under them would be destructive.
func TestEnsureNetworkCreatesAMissingNetworkAndIsIdempotent(t *testing.T) {
	if os.Getenv("POCKETCODER_DOCKER_INTEGRATION") != "1" {
		t.Skip("set POCKETCODER_DOCKER_INTEGRATION=1 to run Docker integration tests")
	}

	name := fmt.Sprintf("pc-egress-it-%d-test-only", os.Getpid())
	t.Cleanup(func() {
		_ = exec.Command("docker", "network", "rm", name).Run()
	})

	if err := exec.Command("docker", "network", "inspect", name).Run(); err == nil {
		t.Fatalf("test network %s already exists before the test runs", name)
	}

	docker := Docker{Stdout: os.Stdout, Stderr: os.Stderr}
	if err := docker.ensureNetwork(name); err != nil {
		t.Fatal(err)
	}
	if err := exec.Command("docker", "network", "inspect", name).Run(); err != nil {
		t.Fatalf("ensureNetwork(%s) did not create the network", name)
	}

	// A later call (e.g. a second release activation on the same box) must
	// not fail just because the network already exists.
	if err := docker.ensureNetwork(name); err != nil {
		t.Fatal("second ensureNetwork call failed:", err)
	}
}
