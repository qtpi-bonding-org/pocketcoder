package progress

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sync"
	"syscall"
	"time"

	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/state"
)

// Sink receives coarse deployment phases suitable for the onboarding UI.
// Release correctness must never depend on the status document being writable.
type Sink interface {
	Report(phase, detail string)
}

type sshHostKey struct {
	Type        string `json:"type"`
	Fingerprint string `json:"fingerprint"`
}

// Reporter atomically continues the bootstrap status stream while the native
// release manager owns the deployment operation.
type Reporter struct {
	path        string
	runID       string
	errorWriter io.Writer

	mu           sync.Mutex
	phase        string
	detail       string
	sourceCommit string
	attempt      int
	maxAttempts  int
	sshHostKey   *sshHostKey
}

func New(path, runID, sourceCommit, hostKeyType, hostKeyFingerprint string, attempt, maxAttempts int, errorWriter io.Writer) *Reporter {
	if errorWriter == nil {
		errorWriter = io.Discard
	}
	if path != "" && runID == "" {
		runID = fmt.Sprintf("native-%d-%d", os.Getpid(), time.Now().UnixNano())
	}
	if sourceCommit == "" {
		sourceCommit = "unknown"
	}
	if attempt < 1 {
		attempt = 1
	}
	if maxAttempts < 1 {
		maxAttempts = 1
	}
	var hostKey *sshHostKey
	if hostKeyType != "" && hostKeyFingerprint != "" {
		hostKey = &sshHostKey{Type: hostKeyType, Fingerprint: hostKeyFingerprint}
	}
	return &Reporter{
		path: path, runID: runID, sourceCommit: sourceCommit,
		errorWriter: errorWriter, phase: "fetching_release", sshHostKey: hostKey,
		attempt: attempt, maxAttempts: maxAttempts,
	}
}

func (reporter *Reporter) Enabled() bool {
	return reporter != nil && reporter.path != ""
}

func (reporter *Reporter) SetSourceCommit(value string) {
	if !reporter.Enabled() || value == "" {
		return
	}
	reporter.mu.Lock()
	reporter.sourceCommit = value
	reporter.mu.Unlock()
}

func (reporter *Reporter) Report(phase, detail string) {
	if !reporter.Enabled() {
		return
	}
	reporter.mu.Lock()
	reporter.phase = phase
	reporter.detail = detail
	reporter.writeLocked("")
	reporter.mu.Unlock()
}

func (reporter *Reporter) Fail(code string) {
	if !reporter.Enabled() {
		return
	}
	reporter.mu.Lock()
	reporter.writeLocked(code)
	reporter.mu.Unlock()
}

func (reporter *Reporter) StartHeartbeat(interval time.Duration) func() {
	if !reporter.Enabled() || interval <= 0 {
		return func() {}
	}
	done := make(chan struct{})
	stopped := make(chan struct{})
	var once sync.Once
	go func() {
		defer close(stopped)
		ticker := time.NewTicker(interval)
		defer ticker.Stop()
		for {
			select {
			case <-ticker.C:
				reporter.mu.Lock()
				reporter.writeLocked("")
				reporter.mu.Unlock()
			case <-done:
				return
			}
		}
	}()
	return func() {
		once.Do(func() {
			close(done)
			<-stopped
		})
	}
}

func (reporter *Reporter) writeLocked(errorCode string) {
	if err := os.MkdirAll(filepath.Dir(reporter.path), 0o755); err != nil {
		fmt.Fprintf(reporter.errorWriter, "pocketcoder-release: status warning: %v\n", err)
		return
	}
	lockPath := filepath.Join(filepath.Dir(reporter.path), ".status.lock")
	lockFile, err := os.OpenFile(lockPath, os.O_CREATE|os.O_RDWR, 0o600)
	if err == nil {
		defer lockFile.Close()
		err = syscall.Flock(int(lockFile.Fd()), syscall.LOCK_EX)
	}
	if err == nil {
		defer syscall.Flock(int(lockFile.Fd()), syscall.LOCK_UN)
		value := map[string]json.RawMessage{}
		if data, readErr := os.ReadFile(reporter.path); readErr == nil && len(data) != 0 {
			if readErr = json.Unmarshal(data, &value); readErr != nil {
				err = readErr
			}
		} else if readErr != nil && !os.IsNotExist(readErr) {
			err = readErr
		}
		if err == nil {
			set := func(key string, item any) {
				data, marshalErr := json.Marshal(item)
				if marshalErr != nil {
					err = marshalErr
					return
				}
				value[key] = data
			}
			set("schema", 3)
			set("runId", reporter.runID)
			set("operation", reporter.phase)
			if reporter.detail == "" {
				set("detail", nil)
			} else {
				set("detail", reporter.detail)
			}
			set("attempt", reporter.attempt)
			set("maxAttempts", reporter.maxAttempts)
			set("sourceCommit", reporter.sourceCommit)
			set("updatedAt", time.Now().UTC().Format(time.RFC3339))
			if errorCode == "" {
				set("errorCode", nil)
			} else {
				set("errorCode", errorCode)
			}
			set("errorMessage", nil)
			if reporter.sshHostKey != nil {
				set("sshHostKey", reporter.sshHostKey)
			}
			if err == nil {
				err = state.WriteJSONAtomic(reporter.path, value, 0o644)
			}
		}
	}
	if err != nil {
		fmt.Fprintf(reporter.errorWriter, "pocketcoder-release: status warning: %v\n", err)
	}
}
