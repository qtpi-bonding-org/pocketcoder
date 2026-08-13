package state

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"syscall"
	"time"
)

type Paths struct {
	Root      string
	Releases  string
	Artifacts string
	Current   string
	Sequences string
	Metadata  string
	Journal   string
	Lock      string
}

func NewPaths(root, releases, artifacts, current string) Paths {
	return Paths{
		Root: root, Releases: releases, Artifacts: artifacts, Current: current,
		Sequences: filepath.Join(root, "sequences.json"),
		Metadata:  filepath.Join(root, "metadata-status.json"),
		Journal:   filepath.Join(root, "transaction.json"),
		Lock:      filepath.Join(root, "mutation.lock"),
	}
}

type Lock struct{ file *os.File }

func AcquireLock(path string) (*Lock, error) {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return nil, err
	}
	file, err := os.OpenFile(path, os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return nil, err
	}
	if err := syscall.Flock(int(file.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		file.Close()
		if errors.Is(err, syscall.EWOULDBLOCK) {
			return nil, fmt.Errorf("another release mutation is already running")
		}
		return nil, err
	}
	return &Lock{file: file}, nil
}

func (lock *Lock) Close() error {
	if lock == nil || lock.file == nil {
		return nil
	}
	err := syscall.Flock(int(lock.file.Fd()), syscall.LOCK_UN)
	closeErr := lock.file.Close()
	if err != nil {
		return err
	}
	return closeErr
}

func WriteJSONAtomic(path string, value any, mode os.FileMode) error {
	data, err := json.MarshalIndent(value, "", "  ")
	if err != nil {
		return err
	}
	data = append(data, '\n')
	return WriteAtomic(path, data, mode)
}

func WriteAtomic(path string, data []byte, mode os.FileMode) error {
	directory := filepath.Dir(path)
	if err := os.MkdirAll(directory, 0o755); err != nil {
		return err
	}
	temporary, err := os.CreateTemp(directory, ".pocketcoder-release-*")
	if err != nil {
		return err
	}
	temporaryPath := temporary.Name()
	defer os.Remove(temporaryPath)
	if err := temporary.Chmod(mode); err != nil {
		temporary.Close()
		return err
	}
	if _, err := temporary.Write(data); err != nil {
		temporary.Close()
		return err
	}
	if err := temporary.Sync(); err != nil {
		temporary.Close()
		return err
	}
	if err := temporary.Close(); err != nil {
		return err
	}
	if err := os.Rename(temporaryPath, path); err != nil {
		return err
	}
	return SyncDirectory(directory)
}

func SyncDirectory(directory string) error {
	dir, err := os.Open(directory)
	if err != nil {
		return err
	}
	defer dir.Close()
	return dir.Sync()
}

func RemoveDurable(path string) error {
	if err := os.Remove(path); err != nil && !os.IsNotExist(err) {
		return err
	}
	return SyncDirectory(filepath.Dir(path))
}

type TransactionPhase string

const (
	PhasePrepared         TransactionPhase = "prepared"
	PhaseSnapshotCreating TransactionPhase = "snapshot-creating"
	PhaseSnapshotCreated  TransactionPhase = "snapshot-created"
	PhasePreviousStopped  TransactionPhase = "previous-stopped"
	PhaseCandidateStarted TransactionPhase = "candidate-started"
	PhaseCommitted        TransactionPhase = "committed"
	PhaseRestoring        TransactionPhase = "restoring"
)

type Transaction struct {
	SchemaVersion        int              `json:"schemaVersion"`
	ID                   string           `json:"id"`
	PreviousRelease      string           `json:"previousRelease,omitempty"`
	CandidateRelease     string           `json:"candidateRelease"`
	PreviousDataVersion  int              `json:"previousDataVersion"`
	CandidateDataVersion int              `json:"candidateDataVersion"`
	SnapshotPath         string           `json:"snapshotPath,omitempty"`
	Phase                TransactionPhase `json:"phase"`
	StartedAt            time.Time        `json:"startedAt"`
	UpdatedAt            time.Time        `json:"updatedAt"`
}
