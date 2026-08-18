package osctl

import (
	"net/http"
	"net/http/httptest"
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

func TestNixOSControllerUpgradeWritesThePinAndSwitches(t *testing.T) {
	stub := t.TempDir()
	captured := filepath.Join(stub, "captured-args")
	script := "#!/bin/sh\nprintf '%s' \"$*\" > " + captured + "\n"
	if err := os.WriteFile(filepath.Join(stub, "nixos-rebuild"), []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", stub+":"+os.Getenv("PATH"))
	pinPath := filepath.Join(stub, "nixos-version.nix")
	server := healthyTestServer(t)
	defer server.Close()
	controller := NixOSController{
		VersionPinPath: pinPath,
		HealthURL:      server.URL,
	}
	if err := controller.Upgrade(Candidate{Version: "26.05"}); err != nil {
		t.Fatalf("Upgrade: %v", err)
	}
	pin, err := os.ReadFile(pinPath)
	if err != nil {
		t.Fatal(err)
	}
	if string(pin) != `"26.05"` {
		t.Fatalf("pin file = %q, want %q", pin, `"26.05"`)
	}
	args, err := os.ReadFile(captured)
	if err != nil {
		t.Fatal(err)
	}
	wantArgs := "switch -I nixpkgs=https://github.com/NixOS/nixpkgs/archive/nixos-26.05.tar.gz"
	if string(args) != wantArgs {
		t.Fatalf("nixos-rebuild args = %q, want %q", args, wantArgs)
	}
}

func TestNixOSControllerUpgradeFailsWhenHealthCheckFails(t *testing.T) {
	stub := t.TempDir()
	if err := os.WriteFile(filepath.Join(stub, "nixos-rebuild"), []byte("#!/bin/sh\nexit 0\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", stub+":"+os.Getenv("PATH"))
	unhealthy := unhealthyTestServer(t)
	defer unhealthy.Close()
	controller := NixOSController{
		VersionPinPath: filepath.Join(stub, "nixos-version.nix"),
		HealthURL:      unhealthy.URL,
	}
	if err := controller.Upgrade(Candidate{Version: "26.05"}); err == nil {
		t.Fatal("expected Upgrade to fail when the box reports unhealthy")
	}
}

func TestNixOSControllerRestorePreviousRunsRollbackAndHealthChecks(t *testing.T) {
	stub := t.TempDir()
	captured := filepath.Join(stub, "captured-args")
	script := "#!/bin/sh\nprintf '%s' \"$*\" > " + captured + "\n"
	if err := os.WriteFile(filepath.Join(stub, "nixos-rebuild"), []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", stub+":"+os.Getenv("PATH"))
	server := healthyTestServer(t)
	defer server.Close()
	controller := NixOSController{HealthURL: server.URL}
	if err := controller.RestorePrevious(); err != nil {
		t.Fatalf("RestorePrevious: %v", err)
	}
	got, err := os.ReadFile(captured)
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != "switch --rollback" {
		t.Fatalf("nixos-rebuild args = %q, want %q", got, "switch --rollback")
	}
}

func healthyTestServer(t *testing.T) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))
}

func unhealthyTestServer(t *testing.T) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
}
