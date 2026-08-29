package coordinator

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/agent/acp"
)

const gooseProviderConfigSaveMethod = "_goose/unstable/providers/config/save"
const gooseDefaultsSaveMethod = "_goose/unstable/defaults/save"

type providerConfigFieldUpdate struct {
	Key   string `json:"key"`
	Value string `json:"value"`
}

type providerConfigSaveRequest struct {
	ProviderID string                      `json:"providerId"`
	Fields     []providerConfigFieldUpdate `json:"fields"`
}

type providerConfigStatus struct {
	ProviderID   string `json:"providerId"`
	IsConfigured bool   `json:"isConfigured"`
}

type providerConfigSaveResponse struct {
	Status providerConfigStatus `json:"status"`
}

// registerProviderCredential persists a provider's saved API key into
// goose's own provider registry via its custom ACP method, so a
// subsequent SetSessionConfigOption("provider", providerIDString) call
// succeeds instead of failing with "Provider not set" -- goose only
// allows switching to a provider its own config/secrets store already
// knows about, and does not discover credentials from process env vars
// for anything but the one provider it booted with. providerIDString is
// the provider_id STRING (e.g. "openai"), matching what goose's own
// registry keys on and what SessionProfile.Provider already holds --
// never a PocketBase record id.
func registerProviderCredential(ctx context.Context, conn acp.Conn, providerIDString, fieldName, fieldValue string) error {
	req := providerConfigSaveRequest{
		ProviderID: providerIDString,
		Fields:     []providerConfigFieldUpdate{{Key: fieldName, Value: fieldValue}},
	}
	raw, err := conn.CallExtension(ctx, gooseProviderConfigSaveMethod, req)
	if err != nil {
		return fmt.Errorf("register provider credential: %w", err)
	}
	var resp providerConfigSaveResponse
	if err := json.Unmarshal(raw, &resp); err != nil {
		return fmt.Errorf("decode provider config save response: %w", err)
	}
	if !resp.Status.IsConfigured {
		return fmt.Errorf("provider %s not configured after registration attempt", providerIDString)
	}
	return nil
}

type defaultsSaveRequest struct {
	ProviderID string `json:"providerId"`
}

type defaultsSaveResponse struct {
	ProviderID string `json:"providerId"`
	ModelID    string `json:"modelId"`
}

// setGooseDefaultProvider sets providerIDString as goose's active default
// provider. It deliberately never sends a modelId: defaults/save validates
// any model it's given against goose's own live provider inventory, and the
// caller's model choice may come from a catalog goose's inventory doesn't
// agree with (see LiveConfigBootstrap's doc comment). Omitting it lets
// defaults/save fall back to the provider's own known-valid default model,
// which is all this call needs to guarantee -- the caller's actual desired
// model is applied separately, afterward, via the ordinary per-session
// model switch.
func setGooseDefaultProvider(ctx context.Context, conn acp.Conn, providerIDString string) error {
	req := defaultsSaveRequest{ProviderID: providerIDString}
	raw, err := conn.CallExtension(ctx, gooseDefaultsSaveMethod, req)
	if err != nil {
		return fmt.Errorf("set goose default provider: %w", err)
	}
	var resp defaultsSaveResponse
	if err := json.Unmarshal(raw, &resp); err != nil {
		return fmt.Errorf("decode defaults save response: %w", err)
	}
	if resp.ProviderID != providerIDString {
		return fmt.Errorf("provider %s not set as default after defaults/save (got %q)", providerIDString, resp.ProviderID)
	}
	return nil
}
