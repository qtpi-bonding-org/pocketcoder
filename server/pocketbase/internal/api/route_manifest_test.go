package api

import (
	"os"
	"path/filepath"
	"reflect"
	"regexp"
	"runtime"
	"sort"
	"strings"
	"testing"

	"gopkg.in/yaml.v3"
)

type openAPIRouteSpec struct {
	Paths map[string]map[string]struct {
		OperationID string `yaml:"operationId"`
	} `yaml:"paths"`
}

var operationRegistrationPattern = regexp.MustCompile(`OperationID:\s*"([^"]+)"`)

func TestPocketCoderRouteManifestMatchesBackend(t *testing.T) {
	_, filename, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("resolve test location")
	}
	repoRoot := filepath.Clean(filepath.Join(filepath.Dir(filename), "../../../.."))
	manifestData, err := os.ReadFile(filepath.Join(repoRoot, "api", "openapi", "pocketcoder.yaml"))
	if err != nil {
		t.Fatal(err)
	}
	var spec openAPIRouteSpec
	if err := yaml.Unmarshal(manifestData, &spec); err != nil {
		t.Fatal(err)
	}

	want := make([]string, 0)
	for path, methods := range spec.Paths {
		if !strings.HasPrefix(path, "/api/pocketcoder/v1/") {
			t.Fatalf("custom API path is outside the v1 namespace: %s", path)
		}
		for method, operationSpec := range methods {
			if method == "parameters" {
				continue
			}
			want = append(want, operationSpec.OperationID)
		}
	}
	sort.Strings(want)

	var got []string
	err = filepath.WalkDir(filepath.Join(repoRoot, "server", "pocketbase"), func(path string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if entry.IsDir() || !strings.HasSuffix(path, ".go") || strings.HasSuffix(path, "_test.go") {
			return nil
		}
		data, readErr := os.ReadFile(path)
		if readErr != nil {
			return readErr
		}
		for _, match := range operationRegistrationPattern.FindAllStringSubmatch(string(data), -1) {
			got = append(got, match[1])
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	sort.Strings(got)
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("backend operations differ from api/openapi/pocketcoder.yaml\n got: %v\nwant: %v", got, want)
	}
}
