package api

import (
	"encoding/json"
	"net/http/httptest"
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/router"
)

func TestPocketCoderErrorUsesPocketBaseEnvelope(t *testing.T) {
	recorder := httptest.NewRecorder()
	re := &core.RequestEvent{Event: router.Event{
		Response: recorder,
		Request:  httptest.NewRequest("GET", "/", nil),
	}}
	if err := pocketCoderError(re, 422, "invalid operation"); err != nil {
		t.Fatalf("pocketCoderError returned error: %v", err)
	}
	if recorder.Code != 422 {
		t.Fatalf("status = %d, want 422", recorder.Code)
	}
	var body map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if body["code"] != float64(422) || body["message"] != "invalid operation" {
		t.Fatalf("unexpected envelope: %#v", body)
	}
	if _, ok := body["data"].(map[string]any); !ok {
		t.Fatalf("data is not an object: %#v", body["data"])
	}
}
