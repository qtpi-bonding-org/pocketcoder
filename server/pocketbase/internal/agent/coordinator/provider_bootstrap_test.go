package coordinator

import (
	"context"
	"encoding/json"
	"testing"
)

// Dispatch must key on SupportsLiveCredentialRegistration, not
// SupportsLiveConfig -- the seed data (pb_migrations/1756000100_seed.go)
// sets supports_live_config=true for BOTH goose and opencode, but only
// goose sets supports_live_credential_registration=true. Keying on
// SupportsLiveConfig would silently route opencode through
// LiveConfigBootstrap the day it gains that second flag. These test
// cases use realistic seeded shapes for all 4 harnesses, not synthetic
// single-flag combinations, so this distinction can't be missed again.
func TestSelectProviderBootstrapPicksLiveConfigForGoose(t *testing.T) {
	got := selectProviderBootstrap(SessionProfile{SupportsLiveConfig: true, SupportsLiveCredentialRegistration: true})
	if _, ok := got.(LiveConfigBootstrap); !ok {
		t.Fatalf("selectProviderBootstrap(goose-shaped profile) = %T, want LiveConfigBootstrap", got)
	}
}

func TestSelectProviderBootstrapPicksStaticEnvForOpencodeDespiteLiveConfig(t *testing.T) {
	// opencode: supports_live_config=true, supports_live_credential_registration=false (seed.go).
	got := selectProviderBootstrap(SessionProfile{SupportsLiveConfig: true, SupportsLiveCredentialRegistration: false})
	if _, ok := got.(StaticEnvBootstrap); !ok {
		t.Fatalf("selectProviderBootstrap(opencode-shaped profile) = %T, want StaticEnvBootstrap", got)
	}
}

func TestSelectProviderBootstrapPicksStaticEnvForClaudeCodeAndCodex(t *testing.T) {
	// claude-code and codex: both flags false (seed.go).
	got := selectProviderBootstrap(SessionProfile{SupportsLiveConfig: false, SupportsLiveCredentialRegistration: false})
	if _, ok := got.(StaticEnvBootstrap); !ok {
		t.Fatalf("selectProviderBootstrap(claude-code/codex-shaped profile) = %T, want StaticEnvBootstrap", got)
	}
}

func TestStaticEnvBootstrapIsNoOp(t *testing.T) {
	fc := &fakeConn{}
	err := StaticEnvBootstrap{}.Bootstrap(context.Background(), fc, SessionProfile{
		Provider: "openai", CredentialFieldName: "OPENAI_API_KEY", CredentialFieldValue: "sk-test",
	})
	if err != nil {
		t.Fatalf("Bootstrap: %v", err)
	}
	if fc.callExtensionCalls != 0 {
		t.Fatalf("callExtensionCalls = %d, want 0 (static bootstrap must never call the harness)", fc.callExtensionCalls)
	}
}

func TestLiveConfigBootstrapRegistersCredentialWhenPresent(t *testing.T) {
	cases := []struct {
		name, fieldName                     string
		supportsRegistration, wantExtension bool
	}{
		{"goose credential present", "OPENAI_API_KEY", true, true},
		{"ollama or no saved key", "", true, false},
		{"registration not supported", "OPENAI_API_KEY", false, false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			fc := &fakeConn{extensionResponse: json.RawMessage(`{"status":{"providerId":"openai","isConfigured":true}}`)}
			err := LiveConfigBootstrap{}.Bootstrap(context.Background(), fc, SessionProfile{
				Provider:                           "openai",
				SupportsLiveCredentialRegistration: tc.supportsRegistration,
				CredentialFieldName:                tc.fieldName,
				CredentialFieldValue:               "sk-test",
			})
			if err != nil {
				t.Fatalf("Bootstrap: %v", err)
			}
			if (fc.callExtensionCalls > 0) != tc.wantExtension {
				t.Fatalf("extension calls = %d, want extension=%v", fc.callExtensionCalls, tc.wantExtension)
			}
		})
	}
}

func TestLiveConfigBootstrapPropagatesRegistrationError(t *testing.T) {
	fc := &fakeConn{extensionResponse: json.RawMessage(`{"status":{"providerId":"openai","isConfigured":false}}`)}
	err := LiveConfigBootstrap{}.Bootstrap(context.Background(), fc, SessionProfile{
		Provider:                           "openai",
		SupportsLiveCredentialRegistration: true,
		CredentialFieldName:                "OPENAI_API_KEY",
		CredentialFieldValue:               "sk-test",
	})
	if err == nil {
		t.Fatal("expected an error when the response reports isConfigured=false")
	}
}
