package osctl

import (
	"os"
	"path/filepath"
	"testing"
)

func TestNixOSControllerCurrentVersionReadsTheVersionFile(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "nixos-version")
	if err := os.WriteFile(path, []byte("26.05\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	controller := NixOSController{VersionFilePath: path}
	got, err := controller.CurrentVersion()
	if err != nil {
		t.Fatal(err)
	}
	if got != "26.05" {
		t.Fatalf("CurrentVersion() = %q, want %q", got, "26.05")
	}
}

func TestNixOSControllerCurrentVersionFailsWithNoFile(t *testing.T) {
	controller := NixOSController{VersionFilePath: filepath.Join(t.TempDir(), "missing")}
	if _, err := controller.CurrentVersion(); err == nil {
		t.Fatal("expected an error when the version file is missing")
	}
}

func TestNixOSControllerUpdateRunsNixosRebuildSwitchUpgrade(t *testing.T) {
	stub := t.TempDir()
	captured := filepath.Join(stub, "captured-args")
	script := "#!/bin/sh\nprintf '%s' \"$*\" > " + captured + "\n"
	if err := os.WriteFile(filepath.Join(stub, "nixos-rebuild"), []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", stub+":"+os.Getenv("PATH"))
	controller := NixOSController{}
	if err := controller.Update(); err != nil {
		t.Fatalf("Update: %v", err)
	}
	got, err := os.ReadFile(captured)
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != "switch --upgrade" {
		t.Fatalf("nixos-rebuild args = %q, want %q", got, "switch --upgrade")
	}
}

func TestNixOSControllerRestartRunsSystemctlReboot(t *testing.T) {
	stub := t.TempDir()
	captured := filepath.Join(stub, "captured-args")
	script := "#!/bin/sh\nprintf '%s' \"$*\" > " + captured + "\n"
	if err := os.WriteFile(filepath.Join(stub, "systemctl"), []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", stub+":"+os.Getenv("PATH"))
	controller := NixOSController{}
	if err := controller.Restart(); err != nil {
		t.Fatalf("Restart: %v", err)
	}
	got, err := os.ReadFile(captured)
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != "reboot" {
		t.Fatalf("systemctl args = %q, want %q", got, "reboot")
	}
}
