package coordinator

import (
	"context"
	"testing"

	acpsdk "github.com/coder/acp-go-sdk"
)

func TestGlobalConfigApplier_SetsMode(t *testing.T) {
	fc := &fakeConn{}
	err := GlobalConfigApplier{}.Apply(context.Background(), fc, "sess-1",
		SessionProfile{Mode: acpsdk.SessionModeId("auto")})
	if err != nil {
		t.Fatal(err)
	}
	if fc.lastModeSession != "sess-1" || fc.lastMode != "auto" {
		t.Fatalf("set_mode not forwarded: sess=%q mode=%q", fc.lastModeSession, fc.lastMode)
	}
}

func TestSelectApplier_DefaultsToGlobalToday(t *testing.T) {
	if _, ok := selectApplier(&acpsdk.InitializeResponse{}).(GlobalConfigApplier); !ok {
		t.Fatal("expected GlobalConfigApplier under today's capabilities")
	}
}
