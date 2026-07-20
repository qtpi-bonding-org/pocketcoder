package coordinator

import (
	"context"

	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/acp"
)

// SessionProfile is the per-session configuration resolved from a chat's
// agent definition (poco_config). Not every field is deliverable over ACP
// today — see ProfileApplier.
type SessionProfile struct {
	Model, Provider, Instructions, Cwd string
	AdditionalDirectories              []string
	McpServers                         []acpsdk.McpServer
	Mode                               acpsdk.SessionModeId
}

// ProfileFunc resolves a SessionProfile for the run currently starting.
// Injected from internal/api, mirroring the existing ResolveSession closure,
// so the coordinator stays PocketBase-agnostic.
type ProfileFunc func(context.Context) (SessionProfile, error)

// ProfileApplier delivers the parts of a SessionProfile that ACP allows to
// be set post session/new|load.
type ProfileApplier interface {
	Apply(ctx context.Context, conn acp.Conn, sessionID string, p SessionProfile) error
}

// GlobalConfigApplier delivers only what ACP allows post-create today: the
// session mode. Model/provider/prompt are delivered out-of-band by the
// render pipeline + restart (spec §4).
type GlobalConfigApplier struct{}

func (GlobalConfigApplier) Apply(ctx context.Context, conn acp.Conn, sessionID string, p SessionProfile) error {
	if p.Mode == "" {
		return nil
	}
	_, err := conn.SetSessionMode(ctx, acpsdk.SetSessionModeRequest{
		SessionId: acpsdk.SessionId(sessionID), ModeId: p.Mode,
	})
	return err
}

// PerSessionApplier is the future path (Goose #7596): it will additionally
// deliver model/instructions/recipe per session. Stub until the capability
// exists.
type PerSessionApplier struct{}

func (PerSessionApplier) Apply(ctx context.Context, conn acp.Conn, sessionID string, p SessionProfile) error {
	return GlobalConfigApplier{}.Apply(ctx, conn, sessionID, p) // no extra capability yet
}

// selectApplier gates on advertised capabilities. Today no SDK field
// describes per-session model/prompt config (#7596 unshipped), so this
// always returns the global applier (spec §4/§S8).
func selectApplier(init *acpsdk.InitializeResponse) ProfileApplier {
	return GlobalConfigApplier{}
}
