package pb_migrations

import (
	"encoding/json"
	"os"
	"testing"
)

func TestChatsCollectionHasHarnessFields(t *testing.T) {
	data, err := os.ReadFile("schema.json")
	if err != nil {
		t.Fatal(err)
	}
	var collections []map[string]any
	if err := json.Unmarshal(data, &collections); err != nil {
		t.Fatal(err)
	}
	var chats map[string]any
	for _, c := range collections {
		if c["name"] == "chats" {
			chats = c
		}
	}
	if chats == nil {
		t.Fatal("chats collection not found")
	}
	fieldNames := map[string]bool{}
	for _, f := range chats["fields"].([]any) {
		fieldNames[f.(map[string]any)["name"].(string)] = true
	}
	if !fieldNames["harness"] {
		t.Error("chats.harness field missing")
	}
	if !fieldNames["workspace_override"] {
		t.Error("chats.workspace_override field missing")
	}
	found := false
	for _, idx := range chats["indexes"].([]any) {
		if idx == "CREATE INDEX idx_chats_user_archived ON chats (user, archived)" {
			found = true
		}
	}
	if !found {
		t.Error("chats (user, archived) index missing")
	}
}

func TestHarnessesCollectionHasCapabilityFields(t *testing.T) {
	data, err := os.ReadFile("schema.json")
	if err != nil {
		t.Fatal(err)
	}
	var collections []map[string]any
	if err := json.Unmarshal(data, &collections); err != nil {
		t.Fatal(err)
	}
	var harnesses map[string]any
	for _, c := range collections {
		if c["name"] == "harnesses" {
			harnesses = c
		}
	}
	if harnesses == nil {
		t.Fatal("harnesses collection not found")
	}
	want := []string{"container_image", "launch_template", "supports_live_config", "provider_scope", "supports_ollama", "supports_session_delete", "supports_additional_directories"}
	got := map[string]bool{}
	for _, f := range harnesses["fields"].([]any) {
		got[f.(map[string]any)["name"].(string)] = true
	}
	for _, name := range want {
		if !got[name] {
			t.Errorf("harnesses.%s field missing", name)
		}
	}
	if got["single_connection_only"] {
		t.Error("obsolete harnesses.single_connection_only field must not be present")
	}
}

func TestHarnessInstancesCollectionExists(t *testing.T) {
	data, err := os.ReadFile("schema.json")
	if err != nil {
		t.Fatal(err)
	}
	var collections []map[string]any
	if err := json.Unmarshal(data, &collections); err != nil {
		t.Fatal(err)
	}
	var hi map[string]any
	for _, c := range collections {
		if c["name"] == "harness_instances" {
			hi = c
		}
	}
	if hi == nil {
		t.Fatal("harness_instances collection not found")
	}
	if hi["listRule"] != "@request.auth.id != ''" {
		t.Errorf("harness_instances.listRule = %v, want @request.auth.id != ''", hi["listRule"])
	}
	if hi["createRule"] != nil {
		t.Errorf("harness_instances.createRule should be null (superuser only)")
	}
	fields := map[string]map[string]any{}
	for _, f := range hi["fields"].([]any) {
		m := f.(map[string]any)
		fields[m["name"].(string)] = m
	}
	for _, name := range []string{"harness", "harness_model", "harness_account", "launch_key", "user", "container_name", "acp_endpoint", "secret", "status", "last_error", "managed", "created", "updated"} {
		if fields[name] == nil {
			t.Errorf("harness_instances.%s field missing", name)
		}
	}
	if hidden, _ := fields["secret"]["hidden"].(bool); !hidden {
		t.Error("harness_instances.secret must be hidden: true")
	}
	uniquePair := false
	uniqueName := false
	for _, idx := range hi["indexes"].([]any) {
		s := idx.(string)
		if s == "CREATE UNIQUE INDEX idx_harness_instances_pair ON harness_instances (user, harness, harness_account, launch_key)" {
			uniquePair = true
		}
		if s == "CREATE UNIQUE INDEX idx_harness_instances_name ON harness_instances (container_name)" {
			uniqueName = true
		}
	}
	if !uniquePair || !uniqueName {
		t.Error("harness_instances missing one or both unique indexes")
	}
}

func TestAgentSessionsHasHarnessInstance(t *testing.T) {
	data, err := os.ReadFile("schema.json")
	if err != nil {
		t.Fatal(err)
	}
	var collections []map[string]any
	if err := json.Unmarshal(data, &collections); err != nil {
		t.Fatal(err)
	}
	var gs map[string]any
	for _, c := range collections {
		if c["name"] == "agent_sessions" {
			gs = c
		}
	}
	if gs == nil {
		t.Fatal("agent_sessions collection not found")
	}
	found := false
	for _, f := range gs["fields"].([]any) {
		if f.(map[string]any)["name"] == "harness_instance" {
			found = true
		}
	}
	if !found {
		t.Error("agent_sessions.harness_instance field missing")
	}
}

func TestHarnessAccountsHaveRequiredFields(t *testing.T) {
	data, err := os.ReadFile("schema.json")
	if err != nil {
		t.Fatal(err)
	}
	var collections []map[string]any
	if err := json.Unmarshal(data, &collections); err != nil {
		t.Fatal(err)
	}
	var accounts map[string]any
	for _, c := range collections {
		if c["name"] == "harness_accounts" {
			accounts = c
			break
		}
	}
	if accounts == nil {
		t.Fatal("harness_accounts collection not found")
	}
	required := []string{
		"harness",
		"owner",
		"name",
		"visibility",
		"credential_mode",
		"provider_key",
		"status",
		"last_error",
	}
	found := map[string]bool{}
	for _, f := range accounts["fields"].([]any) {
		found[f.(map[string]any)["name"].(string)] = true
	}
	for _, name := range required {
		if !found[name] {
			t.Errorf("harness_accounts.%s field missing", name)
		}
	}
	for _, rule := range []string{"listRule", "viewRule", "createRule", "updateRule", "deleteRule"} {
		if accounts[rule] != nil {
			t.Errorf("harness_accounts.%s should be custom-API only", rule)
		}
	}
}

func TestHarnessAccountSelectionsHaveRequiredFields(t *testing.T) {
	data, err := os.ReadFile("schema.json")
	if err != nil {
		t.Fatal(err)
	}
	var collections []map[string]any
	if err := json.Unmarshal(data, &collections); err != nil {
		t.Fatal(err)
	}
	for _, c := range collections {
		if c["name"] != "harness_account_selections" {
			continue
		}
		found := map[string]bool{}
		for _, f := range c["fields"].([]any) {
			found[f.(map[string]any)["name"].(string)] = true
		}
		for _, name := range []string{"user", "harness", "account"} {
			if !found[name] {
				t.Errorf("harness_account_selections.%s field missing", name)
			}
		}
		return
	}
	t.Fatal("harness_account_selections collection not found")
}

func TestHarnessAuthAttemptsHasRequiredFields(t *testing.T) {
	data, err := os.ReadFile("schema.json")
	if err != nil {
		t.Fatal(err)
	}
	var collections []map[string]any
	if err := json.Unmarshal(data, &collections); err != nil {
		t.Fatal(err)
	}
	var attempts map[string]any
	for _, c := range collections {
		if c["name"] == "harness_auth_attempts" {
			attempts = c
			break
		}
	}
	if attempts == nil {
		t.Fatal("harness_auth_attempts collection not found")
	}
	required := []string{
		"account",
		"provider",
		"status",
		"last_error",
		"expires_at",
	}
	found := map[string]bool{}
	for _, f := range attempts["fields"].([]any) {
		found[f.(map[string]any)["name"].(string)] = true
	}
	for _, name := range required {
		if !found[name] {
			t.Errorf("harness_auth_attempts.%s field missing", name)
		}
	}
	for _, rule := range []string{"listRule", "viewRule", "createRule", "updateRule", "deleteRule"} {
		if attempts[rule] != nil {
			t.Errorf("harness_auth_attempts.%s should be custom-API only", rule)
		}
	}
	for _, idx := range attempts["indexes"].([]any) {
		index := idx.(string)
		if index == "CREATE INDEX idx_harness_auth_attempts_account_status ON harness_auth_attempts (account, status)" {
			return
		}
	}
	t.Error("harness_auth_attempts account/status index missing")
}
