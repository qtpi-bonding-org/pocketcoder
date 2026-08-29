package coordinator

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/agent/acp"
)

const gooseProviderConfigSaveMethod = "_goose/unstable/providers/config/save"
const gooseDefaultsSaveMethod = "_goose/unstable/defaults/save"
const gooseProvidersListMethod = "_goose/unstable/providers/list"

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
	ModelID    string `json:"modelId,omitempty"`
}

type defaultsSaveResponse struct {
	ProviderID string `json:"providerId"`
	ModelID    string `json:"modelId"`
}

type providersListRequest struct {
	ProviderIDs []string `json:"providerIds"`
}

type providerInventoryEntry struct {
	ProviderID   string `json:"providerId"`
	DefaultModel string `json:"defaultModel"`
}

type providersListResponse struct {
	Entries []providerInventoryEntry `json:"entries"`
}

// gooseProviderDefaultModel asks goose for the model it would itself pick
// as the default for providerIDString -- guaranteed to exist in goose's own
// live provider inventory, unlike anything sourced from PocketBase's own
// harness_models catalog (see LiveConfigBootstrap's doc comment for why
// that distinction matters).
func gooseProviderDefaultModel(ctx context.Context, conn acp.Conn, providerIDString string) (string, error) {
	raw, err := conn.CallExtension(ctx, gooseProvidersListMethod, providersListRequest{ProviderIDs: []string{providerIDString}})
	if err != nil {
		return "", fmt.Errorf("list goose providers: %w", err)
	}
	var resp providersListResponse
	if err := json.Unmarshal(raw, &resp); err != nil {
		return "", fmt.Errorf("decode providers list response: %w", err)
	}
	for _, entry := range resp.Entries {
		if entry.ProviderID == providerIDString {
			return entry.DefaultModel, nil
		}
	}
	return "", fmt.Errorf("provider %s not found in goose's provider inventory", providerIDString)
}

// setGooseDefaultProvider sets providerIDString as goose's active default
// provider, using modelID as the default model. Callers should pass a model
// sourced from goose's own inventory (gooseProviderDefaultModel), not from
// PocketBase's own harness_models catalog: defaults/save strictly validates
// modelID against goose's live provider inventory, and a catalog pick with
// no is_default row set can resolve to a model that inventory doesn't
// recognize, which fails this call outright -- see LiveConfigBootstrap's
// doc comment. The caller's actual desired model (which may differ from
// modelID here) is applied separately, afterward, via the ordinary
// per-session model switch.
func setGooseDefaultProvider(ctx context.Context, conn acp.Conn, providerIDString, modelID string) error {
	req := defaultsSaveRequest{ProviderID: providerIDString, ModelID: modelID}
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
