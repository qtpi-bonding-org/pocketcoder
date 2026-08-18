package osctl

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

type NixOSController struct {
	VersionFilePath string // defaults to /etc/nixos/nixos-version if empty
}

func (controller NixOSController) versionFilePath() string {
	if controller.VersionFilePath != "" {
		return controller.VersionFilePath
	}
	return "/etc/nixos/nixos-version"
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
