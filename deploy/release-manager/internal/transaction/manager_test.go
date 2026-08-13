package transaction

import (
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"testing"
	"time"

	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/state"
)

type fakeOperations struct {
	calls         []string
	activateError error
}

func (fake *fakeOperations) call(value string)              { fake.calls = append(fake.calls, value) }
func (fake *fakeOperations) Preflight(_, _ Candidate) error { fake.call("preflight"); return nil }
func (fake *fakeOperations) CreateSnapshot(_ Candidate) (Snapshot, error) {
	fake.call("snapshot")
	return Snapshot{Path: "backup"}, nil
}
func (fake *fakeOperations) StopPrevious(_ Candidate) error { fake.call("stop"); return nil }
func (fake *fakeOperations) Activate(_ Candidate) error {
	fake.call("activate")
	return fake.activateError
}
func (fake *fakeOperations) Commit(_, _ Candidate) error {
	fake.call("commit")
	return nil
}
func (fake *fakeOperations) RestoreSnapshot(_ Candidate, _ Snapshot) error {
	fake.call("restore-snapshot")
	return nil
}
func (fake *fakeOperations) RestorePrevious(_ Candidate) error {
	fake.call("restore-previous")
	return nil
}

func newManager(root string, operations Operations) Manager {
	return Manager{
		JournalPath: filepath.Join(root, "transaction.json"), LockPath: filepath.Join(root, "mutation.lock"),
		Operations: operations, Now: func() time.Time { return time.Unix(1, 0).UTC() }, NewID: func() string { return "test" },
	}
}

func TestUpdateCommitsSameDataWithoutSnapshot(t *testing.T) {
	fake := &fakeOperations{}
	err := newManager(t.TempDir(), fake).Update(Candidate{Digest: "a", DataVersion: 1}, Candidate{Digest: "b", DataVersion: 1})
	if err != nil {
		t.Fatal(err)
	}
	want := []string{"preflight", "stop", "activate", "commit"}
	if !reflect.DeepEqual(fake.calls, want) {
		t.Fatalf("calls = %#v", fake.calls)
	}
}

func TestFailedCrossDataActivationRestoresSnapshotBeforePrevious(t *testing.T) {
	fake := &fakeOperations{activateError: errors.New("unhealthy")}
	err := newManager(t.TempDir(), fake).Update(Candidate{Digest: "a", DataVersion: 1}, Candidate{Digest: "b", DataVersion: 2})
	if err == nil {
		t.Fatal("expected activation failure")
	}
	want := []string{"preflight", "snapshot", "stop", "activate", "restore-snapshot", "restore-previous"}
	if !reflect.DeepEqual(fake.calls, want) {
		t.Fatalf("calls = %#v", fake.calls)
	}
}

func TestSameDigestIsIdempotent(t *testing.T) {
	fake := &fakeOperations{}
	if err := newManager(t.TempDir(), fake).Update(Candidate{Digest: "a", DataVersion: 1}, Candidate{Digest: "a", DataVersion: 1}); err != nil {
		t.Fatal(err)
	}
	if len(fake.calls) != 0 {
		t.Fatalf("calls = %#v", fake.calls)
	}
}

func TestConcurrentMutationIsRejected(t *testing.T) {
	root := t.TempDir()
	manager := newManager(root, &fakeOperations{})
	lock, err := state.AcquireLock(manager.LockPath)
	if err != nil {
		t.Fatal(err)
	}
	defer lock.Close()
	if err := manager.Update(
		Candidate{Digest: "a", DataVersion: 1},
		Candidate{Digest: "b", DataVersion: 1},
	); err == nil {
		t.Fatal("expected concurrent mutation rejection")
	}
}

func TestRecoveryDispositionForEveryDurablePhase(t *testing.T) {
	for _, test := range []struct {
		name         string
		phase        state.TransactionPhase
		snapshotPath string
		wantCalls    []string
		wantError    bool
	}{
		{name: "prepared", phase: state.PhasePrepared},
		{name: "snapshot creating", phase: state.PhaseSnapshotCreating, wantCalls: []string{"restore-previous"}, wantError: true},
		{name: "snapshot created", phase: state.PhaseSnapshotCreated, snapshotPath: "backup", wantCalls: []string{"restore-snapshot", "restore-previous"}, wantError: true},
		{name: "previous stopped", phase: state.PhasePreviousStopped, snapshotPath: "backup", wantCalls: []string{"restore-snapshot", "restore-previous"}, wantError: true},
		{name: "candidate started", phase: state.PhaseCandidateStarted, snapshotPath: "backup", wantCalls: []string{"restore-snapshot", "restore-previous"}, wantError: true},
		{name: "restoring", phase: state.PhaseRestoring, snapshotPath: "backup", wantCalls: []string{"restore-snapshot", "restore-previous"}, wantError: true},
		{name: "committed", phase: state.PhaseCommitted},
	} {
		t.Run(test.name, func(t *testing.T) {
			root := t.TempDir()
			fake := &fakeOperations{}
			manager := newManager(root, fake)
			journal := state.Transaction{
				SchemaVersion: 1, ID: "interrupted", PreviousRelease: "a",
				CandidateRelease: "b", PreviousDataVersion: 1,
				CandidateDataVersion: 2, SnapshotPath: test.snapshotPath,
				Phase: test.phase, StartedAt: time.Unix(1, 0), UpdatedAt: time.Unix(1, 0),
			}
			if err := state.WriteJSONAtomic(manager.JournalPath, journal, 0o600); err != nil {
				t.Fatal(err)
			}
			err := manager.Recover()
			if (err != nil) != test.wantError {
				t.Fatalf("error = %v", err)
			}
			if !reflect.DeepEqual(fake.calls, test.wantCalls) {
				t.Fatalf("calls = %#v, want %#v", fake.calls, test.wantCalls)
			}
			if _, err := os.Stat(manager.JournalPath); !errors.Is(err, os.ErrNotExist) {
				t.Fatalf("journal remains after recovery: %v", err)
			}
		})
	}
}
