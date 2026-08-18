package osctl

import "github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/transaction"

// dataVersionSentinel is a fixed, arbitrary constant every Candidate this
// adapter builds shares. OS version changes have no PocketBase data version to
// snapshot against, so transaction.Manager's database snapshot steps never
// run for this adapter.
const dataVersionSentinel = 0

// TransactionOperations adapts an osctl.Controller to transaction.Manager.
type TransactionOperations struct {
	Controller Controller
}

func (ops TransactionOperations) dataVersionSentinel() int { return dataVersionSentinel }

// Candidate builds a transaction.Candidate carrying the OS version in Digest.
// The transaction package uses Digest as the release identity, while an OS
// controller represents that identity as its version string.
func (ops TransactionOperations) Candidate(version string) transaction.Candidate {
	return transaction.Candidate{Digest: version, DataVersion: dataVersionSentinel}
}

func (ops TransactionOperations) Preflight(_, _ transaction.Candidate) error { return nil }

func (ops TransactionOperations) CreateSnapshot(_ transaction.Candidate) (transaction.Snapshot, error) {
	return transaction.Snapshot{}, nil
}

func (ops TransactionOperations) StopPrevious(_ transaction.Candidate) error { return nil }

func (ops TransactionOperations) Activate(candidate transaction.Candidate) error {
	return ops.Controller.Upgrade(Candidate{Version: candidate.Digest})
}

func (ops TransactionOperations) Commit(_, _ transaction.Candidate) error { return nil }

func (ops TransactionOperations) RestoreSnapshot(_ transaction.Candidate, _ transaction.Snapshot) error {
	return nil
}

func (ops TransactionOperations) RestorePrevious(_ transaction.Candidate) error {
	return ops.Controller.RestorePrevious()
}
