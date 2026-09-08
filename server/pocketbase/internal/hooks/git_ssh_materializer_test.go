package hooks

import (
	"archive/tar"
	"bytes"
	"context"
	"io"
	"testing"

	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/dockerapi"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/gitssh"
)

type fakeGitMaterializerDocker struct {
	selfImage string

	createdName string
	createSpec  dockerapi.CreateSpec
	copiedTo    string
	copiedTar   map[string][]byte
	started     bool
	removed     bool

	exitCode  int
	startErr  error
	createErr error
}

func (f *fakeGitMaterializerDocker) Inspect(ctx context.Context, containerName string) (dockerapi.ContainerInspect, error) {
	if containerName == selfContainerName {
		insp := dockerapi.ContainerInspect{}
		insp.Config.Image = f.selfImage
		insp.Mounts = []dockerapi.Mount{{Destination: "/workspace", Name: "proj_workspace"}}
		insp.NetworkSettings.Networks = map[string]dockerapi.NetworkEndpoint{"proj_pocketcoder-agent": {}}
		return insp, nil
	}
	insp := dockerapi.ContainerInspect{}
	insp.State.Running = false
	insp.State.ExitCode = f.exitCode
	return insp, nil
}

func (f *fakeGitMaterializerDocker) Create(ctx context.Context, name string, spec dockerapi.CreateSpec) (string, error) {
	if f.createErr != nil {
		return "", f.createErr
	}
	f.createdName = name
	f.createSpec = spec
	return "container-id", nil
}

func (f *fakeGitMaterializerDocker) CopyArchive(ctx context.Context, containerName, destination string, archive io.Reader) error {
	f.copiedTo = destination
	data, err := io.ReadAll(archive)
	if err != nil {
		return err
	}
	f.copiedTar = map[string][]byte{}
	tr := tar.NewReader(bytes.NewReader(data))
	for {
		h, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}
		buf, err := io.ReadAll(tr)
		if err != nil {
			return err
		}
		f.copiedTar[h.Name] = buf
	}
	return nil
}

func (f *fakeGitMaterializerDocker) Start(ctx context.Context, containerName string) error {
	if f.startErr != nil {
		return f.startErr
	}
	f.started = true
	return nil
}

func (f *fakeGitMaterializerDocker) Remove(ctx context.Context, containerName string) error {
	f.removed = true
	return nil
}

func TestDockerGitSSHMaterializerBindsTheUsersOwnVolumeAndReusesItsOwnImage(t *testing.T) {
	fake := &fakeGitMaterializerDocker{selfImage: "pocketcoder-pocketbase:latest"}
	m := DockerGitSSHMaterializer{Client: fake}

	err := m.Materialize(context.Background(), "user123", gitssh.Manifest{
		Config:     []byte("Host pcgit-a\n"),
		KnownHosts: []byte("github.com ssh-ed25519 AAAA\n"),
		Keys:       map[string][]byte{"cred1": []byte("-----BEGIN PRIVATE KEY-----\n")},
	})
	if err != nil {
		t.Fatal(err)
	}

	if fake.createSpec.Image != "pocketcoder-pocketbase:latest" {
		t.Fatalf("image = %q, want the self-container's own image", fake.createSpec.Image)
	}
	wantBind := "proj_git_ssh_user123:/state"
	if len(fake.createSpec.VolumeBinds) != 1 || fake.createSpec.VolumeBinds[0] != wantBind {
		t.Fatalf("volume binds = %v, want [%s]", fake.createSpec.VolumeBinds, wantBind)
	}
	if fake.copiedTo != "/inbox" {
		t.Fatalf("copied to %q, want /inbox", fake.copiedTo)
	}
	inner, ok := fake.copiedTar["manifest.tar"]
	if !ok {
		t.Fatal("expected an outer manifest.tar entry")
	}
	tr := tar.NewReader(bytes.NewReader(inner))
	got := map[string]string{}
	for {
		h, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			t.Fatal(err)
		}
		buf, _ := io.ReadAll(tr)
		got[h.Name] = string(buf)
	}
	if got["ssh_config"] != "Host pcgit-a\n" {
		t.Fatalf("ssh_config = %q", got["ssh_config"])
	}
	if got["known_hosts"] != "github.com ssh-ed25519 AAAA\n" {
		t.Fatalf("known_hosts = %q", got["known_hosts"])
	}
	if got["keys/cred1"] != "-----BEGIN PRIVATE KEY-----\n" {
		t.Fatalf("keys/cred1 = %q", got["keys/cred1"])
	}
	if !fake.started {
		t.Fatal("expected the helper container to be started")
	}
	if !fake.removed {
		t.Fatal("expected the helper container to be removed")
	}
}

func TestDockerGitSSHMaterializerFailsWhenTheHelperExitsNonZero(t *testing.T) {
	fake := &fakeGitMaterializerDocker{selfImage: "img", exitCode: 1}
	m := DockerGitSSHMaterializer{Client: fake}

	err := m.Materialize(context.Background(), "user123", gitssh.Manifest{Config: []byte("x"), KnownHosts: []byte("y")})
	if err == nil {
		t.Fatal("expected an error when the helper exits non-zero")
	}
	if !fake.removed {
		t.Fatal("expected the helper container to still be removed on failure")
	}
}
