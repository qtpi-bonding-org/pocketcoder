/*
PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
Copyright (C) 2026 Qtpi Bonding LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

package harnessauth

import (
	"context"
	"errors"
	"fmt"
)

const (
	ProviderCodex  = "codex"
	ProviderClaude = "claude"

	ChallengeKindDeviceCode     = "device_code"
	ChallengeKindBrowserCode    = "browser_code"
	ChallengeDestinationBrowser = "browser"
	ChallengeDestinationApp     = "app"
	ChallengeDestinationNone    = "none"

	AttemptStatusStarting  = "starting"
	AttemptStatusAwaiting  = "awaiting_input"
	AttemptStatusSucceeded = "succeeded"
	AttemptStatusFailed    = "failed"
	AttemptStatusExpired   = "expired"
	AttemptStatusCancelled = "cancelled"
)

// Challenge is returned to UI layers when a provider requires user action.
type Challenge struct {
	Type                string `json:"type"`
	Text                string `json:"text"`
	Target              string `json:"target,omitempty"`
	Details             string `json:"details,omitempty"`
	Kind                string `json:"kind,omitempty"`
	VerificationURI     string `json:"verificationUri,omitempty"`
	UserCode            string `json:"userCode,omitempty"`
	CodeDestination     string `json:"codeDestination,omitempty"`
	ExpiresAt           string `json:"expiresAt,omitempty"`
	PollIntervalSeconds int    `json:"pollIntervalSeconds,omitempty"`
}

// AttemptState mirrors the fields persisted in harness_oauth_attempts and is used
// as an in-memory runtime state before syncing back into PocketBase.
type AttemptState struct {
	Status    string     `json:"status"`
	Challenge *Challenge `json:"challenge,omitempty"`
	LastError string     `json:"lastError,omitempty"`
}

type AttemptContext struct {
	AttemptID    string
	UserID       string
	AccountID    string
	HarnessCLI   string
	HarnessImage string
}

type unknownProviderError struct {
	provider string
}

func (e unknownProviderError) Error() string {
	return fmt.Sprintf("unsupported provider %q", e.provider)
}

func newUnknownProviderError(provider string) error {
	return unknownProviderError{provider: provider}
}

// Authenticator encapsulates the provider-specific helper lifecycle.
type Authenticator interface {
	Provider() string
	Start(context.Context, AttemptContext) (*AttemptState, error)
	Poll(context.Context, AttemptContext) (*AttemptState, error)
	Submit(context.Context, AttemptContext, string) (*AttemptState, error)
	Cancel(context.Context, AttemptContext) (*AttemptState, error)
	Disconnect(context.Context, AttemptContext) (*AttemptState, error)
}

// Runtime dispatches start/poll/submit/cancel/disconnect calls to provider
// implementations selected by attempt input.
type Runtime struct {
	providers map[string]Authenticator
}

func NewRuntime(providers map[string]Authenticator) *Runtime {
	return &Runtime{providers: providers}
}

func NewDefaultRuntime() *Runtime {
	return NewRuntime(map[string]Authenticator{
		ProviderCodex:  NewCodexAuthenticator(),
		ProviderClaude: NewClaudeAuthenticator(),
	})
}

func (r *Runtime) provider(provider string) (Authenticator, error) {
	p := r.providers[provider]
	if p == nil {
		return nil, newUnknownProviderError(provider)
	}
	return p, nil
}

func (r *Runtime) Start(ctx context.Context, provider string, attempt AttemptContext) (*AttemptState, error) {
	authenticator, err := r.provider(provider)
	if err != nil {
		return nil, err
	}
	return authenticator.Start(ctx, attempt)
}

func (r *Runtime) Poll(ctx context.Context, provider string, attempt AttemptContext) (*AttemptState, error) {
	authenticator, err := r.provider(provider)
	if err != nil {
		return nil, err
	}
	return authenticator.Poll(ctx, attempt)
}

func (r *Runtime) Submit(ctx context.Context, provider string, attempt AttemptContext, code string) (*AttemptState, error) {
	authenticator, err := r.provider(provider)
	if err != nil {
		return nil, err
	}
	return authenticator.Submit(ctx, attempt, code)
}

func (r *Runtime) Cancel(ctx context.Context, provider string, attempt AttemptContext) (*AttemptState, error) {
	authenticator, err := r.provider(provider)
	if err != nil {
		return nil, err
	}
	return authenticator.Cancel(ctx, attempt)
}

func (r *Runtime) Disconnect(ctx context.Context, provider string, attempt AttemptContext) (*AttemptState, error) {
	authenticator, err := r.provider(provider)
	if err != nil {
		return nil, err
	}
	return authenticator.Disconnect(ctx, attempt)
}

var ErrAttemptExpired = errors.New("attempt expired")
