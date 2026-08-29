package transaction

import (
	"errors"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/state"
)

type Candidate struct {
	Digest      string
	DataVersion int
}

type Snapshot struct {
	Path string
}

type Operations interface {
	Preflight(previous, candidate Candidate) error
	CreateSnapshot(previous Candidate) (Snapshot, error)
	StopPrevious(previous Candidate) error
	Activate(candidate Candidate) error
	Commit(previous, candidate Candidate) error
	RestoreSnapshot(previous Candidate, snapshot Snapshot) error
	RestorePrevious(previous Candidate) error
}

type Manager struct {
	JournalPath string
	LockPath    string
	Operations  Operations
	Now         func() time.Time
	NewID       func() string
}

func (manager Manager) Update(previous, candidate Candidate) error {
	lock, err := state.AcquireLock(manager.LockPath)
	if err != nil {
		return err
	}
	defer func() {
		if err := lock.Close(); err != nil {
			log.Printf("[Transaction] failed to close release lock: %v", err)
		}
	}()
	return manager.UpdateLocked(previous, candidate)
}

// UpdateLocked runs a mutation while the caller holds the global release
// lock. The CLI uses this to keep signed resolution, recovery, activation,
// and retention in one indivisible OS-level operation.
func (manager Manager) UpdateLocked(previous, candidate Candidate) error {
	if previous.Digest == candidate.Digest {
		return nil
	}
	if _, err := os.Stat(manager.JournalPath); err == nil {
		return fmt.Errorf("unfinished release transaction requires recovery")
	} else if !errors.Is(err, os.ErrNotExist) {
		return err
	}
	if err := manager.Operations.Preflight(previous, candidate); err != nil {
		return err
	}
	now := manager.now()
	transaction := state.Transaction{
		SchemaVersion: 1, ID: manager.id(), PreviousRelease: previous.Digest,
		CandidateRelease: candidate.Digest, PreviousDataVersion: previous.DataVersion,
		CandidateDataVersion: candidate.DataVersion, Phase: state.PhasePrepared,
		StartedAt: now, UpdatedAt: now,
	}
	if err := manager.write(transaction); err != nil {
		return err
	}
	var (
		snapshot Snapshot
		err      error
	)
	if previous.Digest != "" && previous.DataVersion != candidate.DataVersion {
		transaction.Phase = state.PhaseSnapshotCreating
		if err := manager.write(transaction); err != nil {
			return err
		}
		snapshot, err = manager.Operations.CreateSnapshot(previous)
		if err != nil {
			return err
		}
		transaction.SnapshotPath = snapshot.Path
		transaction.Phase = state.PhaseSnapshotCreated
		if err := manager.write(transaction); err != nil {
			return err
		}
	}
	if previous.Digest != "" {
		if err := manager.Operations.StopPrevious(previous); err != nil {
			return err
		}
		transaction.Phase = state.PhasePreviousStopped
		if err := manager.write(transaction); err != nil {
			return err
		}
	}
	transaction.Phase = state.PhaseCandidateStarted
	if err := manager.write(transaction); err != nil {
		return err
	}
	if err := manager.Operations.Activate(candidate); err != nil {
		return manager.restore(transaction, previous, snapshot, err)
	}
	if err := manager.Operations.Commit(previous, candidate); err != nil {
		return manager.restore(transaction, previous, snapshot, err)
	}
	transaction.Phase = state.PhaseCommitted
	if err := manager.write(transaction); err != nil {
		return err
	}
	return removeDurable(manager.JournalPath)
}

// Recover deterministically restores the previous release for every unfinished
// mutation phase. Retrying the candidate is a new explicit user operation.
func (manager Manager) Recover() error {
	lock, err := state.AcquireLock(manager.LockPath)
	if err != nil {
		return err
	}
	defer func() {
		if err := lock.Close(); err != nil {
			log.Printf("[Transaction] failed to close release lock: %v", err)
		}
	}()
	return manager.RecoverLocked()
}

func (manager Manager) RecoverLocked() error {
	transaction, err := loadJournal(manager.JournalPath)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	if transaction.Phase == state.PhaseCommitted || transaction.Phase == state.PhasePrepared {
		return removeDurable(manager.JournalPath)
	}
	previous := Candidate{Digest: transaction.PreviousRelease, DataVersion: transaction.PreviousDataVersion}
	snapshot := Snapshot{Path: transaction.SnapshotPath}
	return manager.restore(transaction, previous, snapshot, errors.New("interrupted release transaction"))
}

func (manager Manager) restore(transaction state.Transaction, previous Candidate, snapshot Snapshot, cause error) error {
	transaction.Phase = state.PhaseRestoring
	if err := manager.write(transaction); err != nil {
		return errors.Join(cause, err)
	}
	if snapshot.Path != "" {
		if err := manager.Operations.RestoreSnapshot(previous, snapshot); err != nil {
			return errors.Join(cause, fmt.Errorf("restore database snapshot: %w", err))
		}
	}
	if previous.Digest != "" {
		if err := manager.Operations.RestorePrevious(previous); err != nil {
			return errors.Join(cause, fmt.Errorf("restore previous release: %w", err))
		}
	}
	if err := removeDurable(manager.JournalPath); err != nil {
		return errors.Join(cause, err)
	}
	return cause
}

func (manager Manager) write(transaction state.Transaction) error {
	transaction.UpdatedAt = manager.now()
	return state.WriteJSONAtomic(manager.JournalPath, transaction, 0o600)
}

func (manager Manager) now() time.Time {
	if manager.Now != nil {
		return manager.Now().UTC()
	}
	return time.Now().UTC()
}

func (manager Manager) id() string {
	if manager.NewID != nil {
		return manager.NewID()
	}
	return fmt.Sprintf("release-%d", manager.now().UnixNano())
}
