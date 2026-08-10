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
	want := []string{"container_image", "launch_template", "supports_live_config", "provider_scope", "supports_ollama", "single_connection_only", "supports_session_delete", "supports_additional_directories"}
	got := map[string]bool{}
	for _, f := range harnesses["fields"].([]any) {
		got[f.(map[string]any)["name"].(string)] = true
	}
	for _, name := range want {
		if !got[name] {
			t.Errorf("harnesses.%s field missing", name)
		}
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
	for _, name := range []string{"harness", "harness_model", "launch_key", "user", "container_name", "acp_endpoint", "secret", "status", "last_error", "managed", "created", "updated"} {
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
		if s == "CREATE UNIQUE INDEX idx_harness_instances_pair ON harness_instances (user, harness, launch_key)" {
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

func TestHarnessAuthBindingHasRequiredFields(t *testing.T) {
	data, err := os.ReadFile("schema.json")
	if err != nil {
		t.Fatal(err)
	}
	var collections []map[string]any
	if err := json.Unmarshal(data, &collections); err != nil {
		t.Fatal(err)
	}
	var bindings map[string]any
	for _, c := range collections {
		if c["name"] == "harness_auth_bindings" {
			bindings = c
			break
		}
	}
	if bindings == nil {
		t.Fatal("harness_auth_bindings collection not found")
	}
	required := []string{
		"scope_kind",
		"scope_id",
		"harness",
		"credential_mode",
		"provider_key",
		"status",
		"last_error",
	}
	found := map[string]bool{}
	for _, f := range bindings["fields"].([]any) {
		found[f.(map[string]any)["name"].(string)] = true
	}
	for _, name := range required {
		if !found[name] {
			t.Errorf("harness_auth_bindings.%s field missing", name)
		}
	}
	wantUnique := "CREATE UNIQUE INDEX idx_harness_auth_bindings_scope ON harness_auth_bindings (scope_kind, scope_id, harness)"
	foundUnique := false
	for _, idx := range bindings["indexes"].([]any) {
		if idx == wantUnique {
			foundUnique = true
		}
	}
	if !foundUnique {
		t.Error("harness_auth_bindings unique scope index missing")
	}
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
		"scope_kind",
		"scope_id",
		"harness",
		"binding",
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
	for _, idx := range attempts["indexes"].([]any) {
		index := idx.(string)
		if index == "CREATE INDEX idx_harness_auth_attempts_binding_status ON harness_auth_attempts (binding, status)" {
			return
		}
	}
	t.Error("harness_auth_attempts index idx_harness_auth_attempts_binding_status missing")
}
