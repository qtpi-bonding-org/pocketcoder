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

func (docker Docker) ComposeUp(composeFile, environmentFile string, profiles []string) error {
	arguments := []string{"compose", "--project-name", docker.projectName(), "--env-file", environmentFile, "-f", composeFile}
	for _, profile := range profiles {
		arguments = append(arguments, "--profile", profile)
	}
	arguments = append(arguments, "up", "-d", "--no-build", "--remove-orphans")
	command := exec.Command("docker", arguments...)
	command.Stdout = docker.Stdout
	command.Stderr = docker.Stderr
	if err := command.Run(); err == nil {
		return nil
	}
	arguments = arguments[1:]
	command = exec.Command("docker-compose", arguments...)
	command.Stdout = docker.Stdout
	command.Stderr = docker.Stderr
	if err := command.Run(); err != nil {
		return fmt.Errorf("docker compose up: %w", err)
	}
	return nil
}

func (docker Docker) ComposeDown(composeFile, environmentFile string) error {
	arguments := []string{"compose", "--project-name", docker.projectName(), "--env-file", environmentFile, "-f", composeFile, "down", "--remove-orphans"}
	command := exec.Command("docker", arguments...)
	command.Stdout = docker.Stdout
	command.Stderr = docker.Stderr
	if err := command.Run(); err == nil {
		return nil
	}
	command = exec.Command("docker-compose", arguments[1:]...)
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
