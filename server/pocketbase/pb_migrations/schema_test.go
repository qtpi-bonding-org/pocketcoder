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
