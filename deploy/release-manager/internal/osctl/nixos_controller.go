package osctl

import (
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"strings"
)

type NixOSController struct {
	VersionFilePath string // defaults to /etc/nixos/nixos-version if empty
	VersionPinPath  string // defaults to /etc/nixos/nixos-version.nix
	HealthURL       string // defaults to http://127.0.0.1:8090/api/health
}

func (controller NixOSController) versionFilePath() string {
	if controller.VersionFilePath != "" {
		return controller.VersionFilePath
	}
	return "/etc/nixos/nixos-version"
}

func (controller NixOSController) versionPinPath() string {
	if controller.VersionPinPath != "" {
		return controller.VersionPinPath
	}
	return "/etc/nixos/nixos-version.nix"
}

func (controller NixOSController) CurrentVersion() (string, error) {
	data, err := os.ReadFile(controller.versionFilePath())
	if err != nil {
		return "", fmt.Errorf("read current NixOS version: %w", err)
	}
	version := strings.TrimSpace(string(data))
	if version == "" {
		return "", fmt.Errorf("%s is empty", controller.versionFilePath())
	}
	return version, nil
}

func (controller NixOSController) Update() error {
	cmd := exec.Command("nixos-rebuild", "switch", "--upgrade")
	cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
	return cmd.Run()
}

func (controller NixOSController) Restart() error {
	return exec.Command("systemctl", "reboot").Run()
}

func (controller NixOSController) Upgrade(candidate Candidate) error {
	if err := os.WriteFile(controller.versionPinPath(), []byte(`"`+candidate.Version+`"`), 0o644); err != nil {
		return fmt.Errorf("write version pin: %w", err)
	}
	cmd := exec.Command("nixos-rebuild", "switch")
	cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("nixos-rebuild switch: %w", err)
	}
	return controller.checkHealthy()
}

func (controller NixOSController) RestorePrevious() error {
	cmd := exec.Command("nixos-rebuild", "switch", "--rollback")
	cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("nixos-rebuild switch --rollback: %w", err)
	}
	return controller.checkHealthy()
}

func (controller NixOSController) checkHealthy() error {
	url := controller.HealthURL
	if url == "" {
		url = "http://127.0.0.1:8090/api/health"
	}
	resp, err := http.Get(url)
	if err != nil {
		return fmt.Errorf("health check: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("health check returned status %d", resp.StatusCode)
	}
	return nil
}
