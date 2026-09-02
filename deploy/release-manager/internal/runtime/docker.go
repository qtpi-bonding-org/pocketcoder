package runtime

import (
	"compress/gzip"
	"context"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"time"
)

type Docker struct {
	ProjectName string
	Stdout      io.Writer
	Stderr      io.Writer
}

func (docker Docker) Stop(container string) error {
	command := exec.Command("docker", "stop", container)
	command.Stdout, command.Stderr = docker.Stdout, docker.Stderr
	return command.Run()
}

func (docker Docker) Start(container string) error {
	command := exec.Command("docker", "start", container)
	command.Stdout, command.Stderr = docker.Stdout, docker.Stderr
	return command.Run()
}

func (docker Docker) ImageExists(image string) bool {
	return exec.Command("docker", "image", "inspect", image).Run() == nil
}

// PullImage makes an immutable upstream image available before activation.
// The release contract only permits digest-pinned references here.
func (docker Docker) PullImage(image string) error {
	if docker.ImageExists(image) {
		return nil
	}
	command := exec.Command("docker", "pull", image)
	command.Stdout = docker.Stdout
	command.Stderr = docker.Stderr
	if err := command.Run(); err != nil {
		return fmt.Errorf("pull Docker image %s: %w", image, err)
	}
	if !docker.ImageExists(image) {
		return fmt.Errorf("pulled Docker image %s is unavailable", image)
	}
	return nil
}

func (docker Docker) RemoveImage(image string) error {
	command := exec.Command("docker", "image", "rm", image)
	command.Stdout = docker.Stdout
	command.Stderr = docker.Stderr
	if err := command.Run(); err != nil {
		return fmt.Errorf("remove Docker image %s: %w", image, err)
	}
	return nil
}

func (docker Docker) LoadGzipArchive(path string) error {
	file, err := os.Open(path)
	if err != nil {
		return err
	}
	defer file.Close()
	reader, err := gzip.NewReader(file)
	if err != nil {
		return err
	}
	defer reader.Close()
	command := exec.Command("docker", "load")
	command.Stdin = reader
	command.Stdout = docker.Stdout
	command.Stderr = docker.Stderr
	if err := command.Run(); err != nil {
		return fmt.Errorf("docker load: %w", err)
	}
	return nil
}

// harnessEgressNetwork must match hooks.HarnessEgressNetwork in
// server/pocketbase/internal/hooks/harness_provision.go. It is declared in
// docker-compose.yml's top-level networks but deliberately not attached to
// any static service there -- only dynamically-created harness containers
// join it, outside Compose's own service graph. Compose only creates a
// declared network if some service in the same file references it, so
// without ensuring it here, a fresh box never gets this network at all and
// every harness container creation fails with "network ... not found".
const harnessEgressNetwork = "pocketcoder-harness-egress"

func (docker Docker) ComposeUp(composeFile, environmentFile string, profiles []string) error {
	if err := docker.ensureNetwork(harnessEgressNetwork); err != nil {
		return err
	}
	arguments := []string{"compose", "--project-name", docker.projectName(), "--env-file", environmentFile, "-f", composeFile}
	for _, profile := range profiles {
		arguments = append(arguments, "--profile", profile)
	}
	arguments = append(arguments, "up", "-d", "--no-build", "--remove-orphans")
	if err := docker.runCompose(arguments); err != nil {
		// Best-effort; must never mask the original `up` error.
		logsArguments := []string{"compose", "--project-name", docker.projectName(), "--env-file", environmentFile, "-f", composeFile, "logs", "--no-color", "--tail=500"}
		_ = docker.runCompose(logsArguments)
		return fmt.Errorf("docker compose up: %w", err)
	}
	return nil
}

// ensureNetwork is idempotent: a network that already exists is left
// untouched, matching how Compose itself treats its own declared networks.
func (docker Docker) ensureNetwork(name string) error {
	if exec.Command("docker", "network", "inspect", name).Run() == nil {
		return nil
	}
	command := exec.Command("docker", "network", "create", "--driver", "bridge", name)
	command.Stdout, command.Stderr = docker.Stdout, docker.Stderr
	if err := command.Run(); err != nil {
		return fmt.Errorf("create docker network %s: %w", name, err)
	}
	return nil
}

func (docker Docker) ComposeDown(composeFile, environmentFile string) error {
	arguments := []string{"compose", "--project-name", docker.projectName(), "--env-file", environmentFile, "-f", composeFile, "down", "--remove-orphans"}
	return docker.runCompose(arguments)
}

func (docker Docker) ComposeRestart(composeFile, environmentFile string) error {
	arguments := []string{"compose", "--project-name", docker.projectName(), "--env-file", environmentFile, "-f", composeFile, "restart"}
	return docker.runCompose(arguments)
}

// runCompose chooses the legacy binary only when the Compose plugin is
// unavailable. A failed `docker compose up` is a deployment failure, not a
// reason to retry an unrelated command and hide its useful error.
func (docker Docker) runCompose(arguments []string) error {
	command := exec.Command("docker", "compose", "version")
	command.Stdout = docker.Stdout
	command.Stderr = docker.Stderr
	if err := command.Run(); err != nil {
		command = exec.Command("docker-compose", arguments[1:]...)
	} else {
		command = exec.Command("docker", arguments...)
	}
	command.Stdout = docker.Stdout
	command.Stderr = docker.Stderr
	return command.Run()
}

func (docker Docker) projectName() string {
	if docker.ProjectName != "" {
		return docker.ProjectName
	}
	return "pocketcoder"
}

func WaitHealthy(ctx context.Context, rawURL string, interval time.Duration) error {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	client := &http.Client{Timeout: 5 * time.Second}
	for {
		request, err := http.NewRequestWithContext(ctx, http.MethodGet, rawURL, nil)
		if err != nil {
			return err
		}
		response, err := client.Do(request)
		if err == nil {
			response.Body.Close()
			if response.StatusCode >= 200 && response.StatusCode < 300 {
				return nil
			}
		}
		select {
		case <-ctx.Done():
			return fmt.Errorf("health check failed: %w", ctx.Err())
		case <-ticker.C:
		}
	}
}
