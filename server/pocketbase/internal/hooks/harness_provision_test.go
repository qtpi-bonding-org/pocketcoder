package hooks

import (
	"context"
	"testing"

	"github.com/qtpi-automaton/pocketcoder/backend/internal/dockerapi"
)

type fakeInspectClient struct {
	insp dockerapi.ContainerInspect
}

func (f *fakeInspectClient) Inspect(ctx context.Context, containerName string) (dockerapi.ContainerInspect, error) {
	return f.insp, nil
}

func TestResolveWorkspaceVolumeAndNetworkMatchesByDestinationAndSuffix(t *testing.T) {
	fake := &fakeInspectClient{
		insp: dockerapi.ContainerInspect{
			Mounts: []dockerapi.Mount{
				{Destination: "/app/pb_data", Name: "proj_pb_data"},
				{Destination: "/workspace", Name: "proj_goose_workspace"},
			},
		},
	}
	fake.insp.NetworkSettings.Networks = map[string]dockerapi.NetworkEndpoint{
		"proj_pocketcoder-dashboard": {},
		"proj_pocketcoder-agent":     {},
	}
	vol, net, err := ResolveWorkspaceVolumeAndNetwork(context.Background(), fake)
	if err != nil {
		t.Fatal(err)
	}
	if vol != "proj_goose_workspace" {
		t.Errorf("volume = %q, want proj_goose_workspace", vol)
	}
	if net != "proj_pocketcoder-agent" {
		t.Errorf("network = %q, want proj_pocketcoder-agent", net)
	}
}

func TestResolveWorkspaceVolumeAndNetworkErrorsWhenNoMatch(t *testing.T) {
	fake := &fakeInspectClient{insp: dockerapi.ContainerInspect{}}
	_, _, err := ResolveWorkspaceVolumeAndNetwork(context.Background(), fake)
	if err == nil {
		t.Fatal("expected an error when no /workspace mount or pocketcoder-agent network is found")
	}
}
