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
	"fmt"
	"sync"
	"time"
)

type simulatedAttempt struct {
	status     string
	challenge  *Challenge
	expiresAt  time.Time
	lastError  string
	corrective bool
}

type simulatedAuthenticator struct {
	provider          string
	challengeTemplate Challenge
	attempts          map[string]*simulatedAttempt
	mu                sync.Mutex
}

func newSimulatedAuthenticator(provider string, template Challenge) *simulatedAuthenticator {
	return &simulatedAuthenticator{
		provider:          provider,
		challengeTemplate: template,
		attempts:          map[string]*simulatedAttempt{},
	}
}

func (s *simulatedAuthenticator) Provider() string { return s.provider }

func (s *simulatedAuthenticator) Start(_ context.Context, attemptID string) (*AttemptState, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.attempts[attemptID] = &simulatedAttempt{
		status:    AttemptStatusStarting,
		challenge: &s.challengeTemplate,
		expiresAt: time.Now().Add(15 * time.Minute),
	}
	challenge := *s.challengeTemplate.copy()
	return &AttemptState{
		Status:    AttemptStatusStarting,
		Challenge: &challenge,
	}, nil
}

func (s *simulatedAuthenticator) Poll(_ context.Context, attemptID string) (*AttemptState, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	a, ok := s.attempts[attemptID]
	if !ok {
		return nil, ErrAttemptExpired
	}
	if time.Now().After(a.expiresAt) {
		a.status = AttemptStatusExpired
		return &AttemptState{
			Status:    AttemptStatusExpired,
			LastError: "authentication flow expired",
		}, nil
	}
	if a.status == AttemptStatusStarting {
		a.status = AttemptStatusAwaiting
		challenge := *a.challenge.copy()
		return &AttemptState{
			Status:    AttemptStatusAwaiting,
			Challenge: &challenge,
		}, nil
	}
	return &AttemptState{
		Status:    a.status,
		Challenge: nil,
		LastError: a.lastError,
	}, nil
}

func (s *simulatedAuthenticator) Submit(_ context.Context, attemptID, code string) (*AttemptState, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	a, ok := s.attempts[attemptID]
	if !ok {
		return nil, ErrAttemptExpired
	}
	if time.Now().After(a.expiresAt) {
		a.status = AttemptStatusExpired
		a.lastError = "authentication flow expired"
		return &AttemptState{
			Status:    AttemptStatusExpired,
			LastError: a.lastError,
		}, nil
	}
	if a.status == AttemptStatusCancelled || a.status == AttemptStatusSucceeded {
		return &AttemptState{Status: a.status, LastError: a.lastError}, nil
	}
	if a.status != AttemptStatusAwaiting {
		a.lastError = fmt.Sprintf("cannot submit code in %s state", a.status)
		return nil, fmt.Errorf(a.lastError)
	}
	if code == "" {
		a.status = AttemptStatusFailed
		a.lastError = "auth code is required"
		return &AttemptState{
			Status:    AttemptStatusFailed,
			LastError: a.lastError,
		}, nil
	}
	a.status = AttemptStatusSucceeded
	a.challenge = nil
	return &AttemptState{Status: AttemptStatusSucceeded}, nil
}

func (s *simulatedAuthenticator) Cancel(_ context.Context, attemptID string) (*AttemptState, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	a, ok := s.attempts[attemptID]
	if !ok {
		return nil, ErrAttemptExpired
	}
	if a.status == AttemptStatusSucceeded || a.status == AttemptStatusFailed || a.status == AttemptStatusExpired {
		return &AttemptState{Status: a.status, LastError: a.lastError}, nil
	}
	a.status = AttemptStatusCancelled
	a.challenge = nil
	return &AttemptState{Status: AttemptStatusCancelled}, nil
}

func (s *simulatedAuthenticator) Disconnect(_ context.Context, attemptID string) (*AttemptState, error) {
	return s.Cancel(context.Background(), attemptID)
}

func (c *Challenge) copy() *Challenge {
	if c == nil {
		return nil
	}
	copy := *c
	return &copy
}

func NewCodexAuthenticator() Authenticator {
	return newSimulatedAuthenticator(ProviderCodex, Challenge{
		Type:    "device-code",
		Text:    "Visit the provider URL and enter the displayed user code",
		Target:  "https://codex.example/auth/device",
		Details: "Device-code flow",
	})
}

func NewClaudeAuthenticator() Authenticator {
	return newSimulatedAuthenticator(ProviderClaude, Challenge{
		Type:    "browser-code",
		Text:    "Paste the code shown in your Claude browser page",
		Target:  "https://claude.example/auth/code",
		Details: "Claude browser challenge",
	})
}
