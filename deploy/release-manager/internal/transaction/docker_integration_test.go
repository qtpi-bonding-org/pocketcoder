//go:build integration

package transaction

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/runtime"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/snapshot"
)

type dockerFixtureOperations struct {
	docker      runtime.Docker
	snapshot    snapshot.Manager
	composeA    string
	composeB    string
	environment string
	container   string
	hostname    string
}

func (operations *dockerFixtureOperations) Preflight(_, _ Candidate) error { return nil }

func (operations *dockerFixtureOperations) CreateSnapshot(previous Candidate) (Snapshot, error) {
	path, err := operations.snapshot.Create(previous.Digest, previous.DataVersion)
	return Snapshot{Path: path}, err
}

func (operations *dockerFixtureOperations) StopPrevious(_ Candidate) error {
	return operations.docker.ComposeDown(operations.composeA, operations.environment)
}

func (operations *dockerFixtureOperations) Activate(_ Candidate) error {
	if err := operations.docker.ComposeUp(operations.composeB, operations.environment, false); err != nil {
		return err
	}
	return operations.waitHealthy(4 * time.Second)
}

func (operations *dockerFixtureOperations) Commit(_, _ Candidate) error { return nil }

func (operations *dockerFixtureOperations) RestoreSnapshot(_ Candidate, value Snapshot) error {
	return operations.snapshot.Restore(value.Path)
}

func (operations *dockerFixtureOperations) RestorePrevious(_ Candidate) error {
	if err := operations.docker.ComposeUp(operations.composeA, operations.environment, false); err != nil {
		return err
	}
	return operations.waitHealthy(10 * time.Second)
}

func (operations *dockerFixtureOperations) waitHealthy(timeout time.Duration) error {
	url, err := operations.url("/fixture/health")
	if err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	return runtime.WaitHealthy(ctx, url, 100*time.Millisecond)
}

func (operations *dockerFixtureOperations) url(path string) (string, error) {
	output, err := exec.Command("docker", "port", operations.container, "8090/tcp").Output()
	if err != nil {
		return "", fmt.Errorf("resolve fixture port: %w", err)
	}
	line := strings.Split(strings.TrimSpace(string(output)), "\n")[0]
	index := strings.LastIndex(line, ":")
	if index < 0 || index == len(line)-1 {
		return "", fmt.Errorf("unexpected fixture port %q", line)
	}
	return "http://" + operations.hostname + ":" + line[index+1:] + path, nil
}

func TestDockerPocketBaseSuccessfulDataMigration(t *testing.T) {
	fixture := newDockerFixture(t, "success", true)
	fixture.startA(t)
	fixture.seed(t)
	assertFixtureState(t, fixture.state(t), false)

	manager := fixture.manager(t)
	if err := manager.Update(Candidate{Digest: "release-a", DataVersion: 1}, Candidate{Digest: "release-b", DataVersion: 2}); err != nil {
		t.Fatal(err)
	}
	state := fixture.state(t)
	if state.Value != "preserved-across-release" || !state.MigrationApplied {
		t.Fatalf("state after migration = %#v", state)
	}
}

func TestDockerPocketBaseFailedMigrationRestoresSnapshotAndPreviousRelease(t *testing.T) {
	fixture := newDockerFixture(t, "restore", false)
	fixture.startA(t)
	fixture.seed(t)
	assertFixtureState(t, fixture.state(t), false)

	manager := fixture.manager(t)
	err := manager.Update(Candidate{Digest: "release-a", DataVersion: 1}, Candidate{Digest: "release-b", DataVersion: 2})
	if err == nil {
		t.Fatal("expected unhealthy candidate to fail")
	}
	state := fixture.state(t)
	if state.Value != "preserved-across-release" || state.MigrationApplied {
		t.Fatalf("state after restore = %#v", state)
	}
	if _, statErr := os.Stat(manager.JournalPath); !errors.Is(statErr, os.ErrNotExist) {
		t.Fatalf("transaction journal remains after restore: %v", statErr)
	}
}

func assertFixtureState(t *testing.T, state fixtureState, migrationApplied bool) {
	t.Helper()
	if state.Value != "preserved-across-release" || state.MigrationApplied != migrationApplied {
		t.Fatalf("fixture state = %#v, migrationApplied want %t", state, migrationApplied)
	}
}

type dockerFixture struct {
	operations *dockerFixtureOperations
	project    string
	root       string
}

type fixtureState struct {
	Value            string `json:"value"`
	MigrationApplied bool   `json:"migrationApplied"`
}

func newDockerFixture(t *testing.T, suffix string, candidateHealthy bool) *dockerFixture {
	t.Helper()
	if os.Getenv("POCKETCODER_DOCKER_INTEGRATION") != "1" {
		t.Skip("set POCKETCODER_DOCKER_INTEGRATION=1 to run Docker integration tests")
	}
	image := os.Getenv("POCKETCODER_RELEASE_FIXTURE_IMAGE")
	if image == "" {
		t.Fatal("POCKETCODER_RELEASE_FIXTURE_IMAGE is required")
	}
	root := t.TempDir()
	project := fmt.Sprintf("pc-release-it-%d-%s", os.Getpid(), suffix)
	container := project + "-pocketbase-1"
	environment := filepath.Join(root, "runtime.env")
	if err := os.WriteFile(environment, []byte("FIXTURE=integration\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	composeA := filepath.Join(root, "compose-a.yml")
	composeB := filepath.Join(root, "compose-b.yml")
	writeFixtureCompose(t, composeA, image, "1", true)
	writeFixtureCompose(t, composeB, image, "2", candidateHealthy)
	hostname := os.Getenv("POCKETCODER_TEST_DOCKER_HOST")
	if hostname == "" {
		hostname = "127.0.0.1"
	}
	operations := &dockerFixtureOperations{
		docker:      runtime.Docker{ProjectName: project, Stdout: os.Stdout, Stderr: os.Stderr},
		snapshot:    snapshot.Manager{DataVolume: project + "_pb_data", BackupVolume: project + "_pb_backups", StateRoot: filepath.Join(root, "state"), Container: container},
		composeA:    composeA,
		composeB:    composeB,
		environment: environment,
		container:   container,
		hostname:    hostname,
	}
	fixture := &dockerFixture{operations: operations, project: project, root: root}
	t.Cleanup(func() {
		command := exec.Command("docker", "compose", "--project-name", project, "--env-file", environment, "-f", composeB, "down", "-v", "--remove-orphans")
		command.Stdout, command.Stderr = os.Stdout, os.Stderr
		_ = command.Run()
	})
	return fixture
}

func (fixture *dockerFixture) manager(t *testing.T) Manager {
	t.Helper()
	stateRoot := filepath.Join(fixture.root, "state")
	return Manager{
		JournalPath: filepath.Join(stateRoot, "transaction.json"),
		LockPath:    filepath.Join(stateRoot, "mutation.lock"),
		Operations:  fixture.operations,
	}
}

func (fixture *dockerFixture) startA(t *testing.T) {
	t.Helper()
	if err := fixture.operations.docker.ComposeUp(fixture.operations.composeA, fixture.operations.environment, false); err != nil {
		t.Fatal(err)
	}
	if err := fixture.operations.waitHealthy(20 * time.Second); err != nil {
		t.Fatal(err)
	}
}

func (fixture *dockerFixture) seed(t *testing.T) {
	t.Helper()
	url, err := fixture.operations.url("/fixture/seed")
	if err != nil {
		t.Fatal(err)
	}
	response, err := http.Post(url, "application/json", nil)
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusCreated {
		t.Fatalf("seed status = %d", response.StatusCode)
	}
}

func (fixture *dockerFixture) state(t *testing.T) fixtureState {
	t.Helper()
	url, err := fixture.operations.url("/fixture/state")
	if err != nil {
		t.Fatal(err)
	}
	response, err := http.Get(url)
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(response.Body)
		t.Fatalf("state status = %d: %s", response.StatusCode, body)
	}
	var result fixtureState
	if err := json.NewDecoder(response.Body).Decode(&result); err != nil {
		t.Fatal(err)
	}
	return result
}

func writeFixtureCompose(t *testing.T, path, image, dataVersion string, healthy bool) {
	t.Helper()
	content := fmt.Sprintf(`services:
  pocketbase:
    image: %s
    environment:
      FIXTURE_DATA_VERSION: %q
      FIXTURE_HEALTHY: %q
    ports:
      - target: 8090
        published: 0
        protocol: tcp
    volumes:
      - pb_data:/app/pb_data
      - pb_backups:/app/pb_backups
volumes:
  pb_data:
  pb_backups:
`, image, dataVersion, fmt.Sprintf("%t", healthy))
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}
}
