package hooks

import (
	"archive/tar"
	"bytes"
	"context"
	"fmt"
	"io"
	"time"

	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/dockerapi"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/gitssh"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/harnessvolume"
)

const selfContainerName = "pocketcoder-pocketbase"

type gitMaterializerDocker interface {
	inspector
	Create(ctx context.Context, name string, spec dockerapi.CreateSpec) (string, error)
	CopyArchive(ctx context.Context, containerName, destination string, archive io.Reader) error
	Start(ctx context.Context, containerName string) error
	Remove(ctx context.Context, containerName string) error
}

type DockerGitSSHMaterializer struct {
	Client gitMaterializerDocker
}

func (m DockerGitSSHMaterializer) Materialize(ctx context.Context, userID string, manifest gitssh.Manifest) error {
	workspaceVolume, _, err := ResolveWorkspaceVolumeAndNetwork(ctx, m.Client)
	if err != nil {
		return fmt.Errorf("resolve compose namespace: %w", err)
	}
	gitVolume, err := harnessvolume.GitSSHVolumeName(workspaceVolume, userID)
	if err != nil {
		return fmt.Errorf("resolve git-ssh volume: %w", err)
	}
	self, err := m.Client.Inspect(ctx, selfContainerName)
	if err != nil {
		return fmt.Errorf("inspect %s: %w", selfContainerName, err)
	}

	archive, err := manifestArchive(manifest)
	if err != nil {
		return fmt.Errorf("build manifest archive: %w", err)
	}

	containerName := fmt.Sprintf("pc-git-materialize-%s-%d", userID, time.Now().UnixNano())
	if _, err := m.Client.Create(ctx, containerName, dockerapi.CreateSpec{
		Image:         self.Config.Image,
		Entrypoint:    []string{"/app/git-materializer"},
		Cmd:           []string{"materialize"},
		VolumeBinds:   []string{gitVolume + ":/state"},
		RestartPolicy: "no",
	}); err != nil {
		return fmt.Errorf("create git-materializer helper: %w", err)
	}
	defer func() { _ = m.Client.Remove(context.WithoutCancel(ctx), containerName) }()

	if err := m.Client.CopyArchive(ctx, containerName, "/inbox", bytes.NewReader(archive)); err != nil {
		return fmt.Errorf("copy manifest into helper: %w", err)
	}
	if err := m.Client.Start(ctx, containerName); err != nil {
		return fmt.Errorf("start git-materializer helper: %w", err)
	}

	deadline := time.Now().Add(15 * time.Second)
	for time.Now().Before(deadline) {
		insp, err := m.Client.Inspect(ctx, containerName)
		if err != nil {
			return fmt.Errorf("inspect git-materializer helper: %w", err)
		}
		if !insp.State.Running {
			if insp.State.ExitCode != 0 {
				return fmt.Errorf("git-materializer helper exited %d", insp.State.ExitCode)
			}
			return nil
		}
		time.Sleep(200 * time.Millisecond)
	}
	return fmt.Errorf("git-materializer helper did not exit within 15s")
}

// Layout must match what cmd/git-materializer expects under /inbox/manifest.tar.
func manifestArchive(manifest gitssh.Manifest) ([]byte, error) {
	files := []gitssh.File{
		{Path: "ssh_config", Mode: 0644, Data: manifest.Config},
		{Path: "known_hosts", Mode: 0644, Data: manifest.KnownHosts},
	}
	for id, key := range manifest.Keys {
		files = append(files, gitssh.File{Path: "keys/" + id, Mode: 0600, Data: key})
	}
	if err := gitssh.ValidateFiles(files); err != nil {
		return nil, err
	}

	var buf bytes.Buffer
	tw := tar.NewWriter(&buf)
	for _, f := range files {
		if err := tw.WriteHeader(&tar.Header{
			Name: f.Path,
			Mode: int64(f.Mode),
			Size: int64(len(f.Data)),
		}); err != nil {
			return nil, err
		}
		if _, err := tw.Write(f.Data); err != nil {
			return nil, err
		}
	}
	if err := tw.Close(); err != nil {
		return nil, err
	}

	var outer bytes.Buffer
	outerTw := tar.NewWriter(&outer)
	if err := outerTw.WriteHeader(&tar.Header{Name: "manifest.tar", Mode: 0644, Size: int64(buf.Len())}); err != nil {
		return nil, err
	}
	if _, err := outerTw.Write(buf.Bytes()); err != nil {
		return nil, err
	}
	if err := outerTw.Close(); err != nil {
		return nil, err
	}
	return outer.Bytes(), nil
}
