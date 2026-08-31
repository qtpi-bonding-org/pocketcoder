package coordinator

import (
	"context"
	"encoding/json"
	"errors"
	"testing"
)

func newFakeConnWithExtension(t *testing.T, response json.RawMessage, err error) *fakeConn {
	t.Helper()
	return &fakeConn{extensionResponse: response, extensionErr: err}
}

func TestRegisterProviderCredentialSendsGooseCustomMethod(t *testing.T) {
	conn := newFakeConnWithExtension(t, json.RawMessage(`{"status":{"providerId":"openai","isConfigured":true}}`), nil)

	if err := registerProviderCredential(context.Background(), conn, "openai", "OPENAI_API_KEY", "sk-test"); err != nil {
		t.Fatalf("registerProviderCredential: %v", err)
	}
	if conn.lastExtensionMethod != gooseProviderConfigSaveMethod {
		t.Fatalf("method = %q, want %q", conn.lastExtensionMethod, gooseProviderConfigSaveMethod)
	}
	req, ok := conn.lastExtensionParams.(providerConfigSaveRequest)
	if !ok {
		t.Fatalf("params type = %T, want providerConfigSaveRequest", conn.lastExtensionParams)
	}
	if req.ProviderID != "openai" {
		t.Fatalf("providerId = %q, want openai", req.ProviderID)
	}
	if len(req.Fields) != 1 || req.Fields[0].Key != "OPENAI_API_KEY" || req.Fields[0].Value != "sk-test" {
		t.Fatalf("unexpected fields: %+v", req.Fields)
	}
}

func TestRegisterProviderCredentialSurfacesRejectionAsApiKeyInvalid(t *testing.T) {
	conn := newFakeConnWithExtension(t, nil, errors.New("unauthorized: invalid api key"))

	err := registerProviderCredential(context.Background(), conn, "openai", "OPENAI_API_KEY", "bad-key")
	if err == nil {
		t.Fatal("expected an error")
	}
	if !providerApiKeyFailure(false, err) {
		t.Fatalf("expected providerApiKeyFailure to classify this error, got: %v", err)
	}
}

func TestRegisterProviderCredentialFailsWhenNotConfigured(t *testing.T) {
	conn := newFakeConnWithExtension(t, json.RawMessage(`{"status":{"providerId":"openai","isConfigured":false}}`), nil)

	if err := registerProviderCredential(context.Background(), conn, "openai", "OPENAI_API_KEY", "sk-test"); err == nil {
		t.Fatal("expected an error when the response reports isConfigured=false")
	}
}
