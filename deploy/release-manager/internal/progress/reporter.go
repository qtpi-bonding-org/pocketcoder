package progress

import (
	"fmt"
	"io"
	"os"
	"sync"
	"time"

	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/state"
)

// Sink receives coarse deployment phases suitable for the onboarding UI.
// Release correctness must never depend on the status document being writable.
type Sink interface {
	Report(phase, detail string)
}

type document struct {
	Schema       int         `json:"schema"`
	RunID        string      `json:"runId"`
	Phase        string      `json:"phase"`
	Detail       string      `json:"detail,omitempty"`
	SourceCommit string      `json:"sourceCommit"`
	UpdatedAt    string      `json:"updatedAt"`
	Error        string      `json:"error,omitempty"`
	SSHHostKey   *sshHostKey `json:"sshHostKey,omitempty"`
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
	sshHostKey   *sshHostKey
}

func New(path, runID, sourceCommit, hostKeyType, hostKeyFingerprint string, errorWriter io.Writer) *Reporter {
	if errorWriter == nil {
		errorWriter = io.Discard
	}
	if path != "" && runID == "" {
		runID = fmt.Sprintf("native-%d-%d", os.Getpid(), time.Now().UnixNano())
	}
	if sourceCommit == "" {
		sourceCommit = "unknown"
	}
	var hostKey *sshHostKey
	if hostKeyType != "" && hostKeyFingerprint != "" {
		hostKey = &sshHostKey{Type: hostKeyType, Fingerprint: hostKeyFingerprint}
	}
	return &Reporter{
		path: path, runID: runID, sourceCommit: sourceCommit,
		errorWriter: errorWriter, phase: "fetching_release", sshHostKey: hostKey,
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
	value := document{
		Schema: 1, RunID: reporter.runID, Phase: reporter.phase,
		Detail: reporter.detail, SourceCommit: reporter.sourceCommit,
		UpdatedAt: time.Now().UTC().Format(time.RFC3339), Error: errorCode,
		SSHHostKey: reporter.sshHostKey,
	}
	if err := state.WriteJSONAtomic(reporter.path, value, 0o644); err != nil {
		fmt.Fprintf(reporter.errorWriter, "pocketcoder-release: status warning: %v\n", err)
	}
}
