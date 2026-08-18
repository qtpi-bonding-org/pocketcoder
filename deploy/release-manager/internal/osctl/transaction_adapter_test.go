package osctl

import (
	"errors"
	"testing"

	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/transaction"
)

type fakeController struct {
	upgradeErr         error
	restorePreviousErr error
	upgradedTo         string
	restoreCalled      bool
}

func (f *fakeController) CurrentVersion() (string, error) { return "", nil }
func (f *fakeController) Update() error                   { return nil }
func (f *fakeController) Restart() error                  { return nil }
func (f *fakeController) Upgrade(candidate Candidate) error {
	f.upgradedTo = candidate.Version
	return f.upgradeErr
}
func (f *fakeController) RestorePrevious() error {
	f.restoreCalled = true
	return f.restorePreviousErr
}

func TestTransactionOperationsActivateCallsUpgrade(t *testing.T) {
	controller := &fakeController{}
	ops := TransactionOperations{Controller: controller}
	if err := ops.Activate(transaction.Candidate{Digest: "26.05"}); err != nil {
		t.Fatalf("Activate: %v", err)
	}
	if controller.upgradedTo != "26.05" {
		t.Fatalf("upgradedTo = %q, want %q", controller.upgradedTo, "26.05")
	}
}

func TestTransactionOperationsRestorePreviousCallsController(t *testing.T) {
	controller := &fakeController{}
	ops := TransactionOperations{Controller: controller}
	if err := ops.RestorePrevious(transaction.Candidate{}); err != nil {
		t.Fatalf("RestorePrevious: %v", err)
	}
	if !controller.restoreCalled {
		t.Fatal("expected Controller.RestorePrevious to be called")
	}
}

func TestTransactionOperationsSnapshotStepsAreUnreachable(t *testing.T) {
	ops := TransactionOperations{Controller: &fakeController{}}
	same := ops.Candidate("26.05")
	if same.DataVersion != ops.Candidate("25.11").DataVersion {
		t.Fatal("DataVersion must be constant across every Candidate this adapter builds, so CreateSnapshot/RestoreSnapshot never fire")
	}
}

func TestManagerUpdateLockedTriggersAutoRestoreOnUpgradeFailure(t *testing.T) {
	controller := &fakeController{upgradeErr: errors.New("switch failed")}
	ops := TransactionOperations{Controller: controller}
	manager := transaction.Manager{
		JournalPath: t.TempDir() + "/journal.json",
		LockPath:    t.TempDir() + "/lock",
		Operations:  ops,
	}
	err := manager.UpdateLocked(
		transaction.Candidate{Digest: "25.11", DataVersion: ops.dataVersionSentinel()},
		transaction.Candidate{Digest: "26.05", DataVersion: ops.dataVersionSentinel()},
	)
	if err == nil {
		t.Fatal("expected the failed Activate to propagate")
	}
	if !controller.restoreCalled {
		t.Fatal("expected transaction.Manager to automatically call RestorePrevious after Activate failed")
	}
}
