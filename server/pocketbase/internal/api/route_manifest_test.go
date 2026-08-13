package api

import (
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"regexp"
	"runtime"
	"sort"
	"strings"
	"testing"
)

type routeManifest struct {
	SchemaVersion int `json:"schemaVersion"`
	Routes        []struct {
		Method string `json:"method"`
		Path   string `json:"path"`
	} `json:"routes"`
}

var routeRegistrationPattern = regexp.MustCompile(`\.Router\.(GET|POST|PUT|PATCH|DELETE)\("([^"]+)"`)

func TestPocketCoderRouteManifestMatchesBackend(t *testing.T) {
	_, filename, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("resolve test location")
	}
	repoRoot := filepath.Clean(filepath.Join(filepath.Dir(filename), "../../../.."))
	manifestData, err := os.ReadFile(filepath.Join(repoRoot, "api", "pocketcoder-routes.json"))
	if err != nil {
		t.Fatal(err)
	}
	var manifest routeManifest
	if err := json.Unmarshal(manifestData, &manifest); err != nil {
		t.Fatal(err)
	}
	if manifest.SchemaVersion != 1 {
		t.Fatalf("unsupported route manifest schemaVersion %d", manifest.SchemaVersion)
	}

	want := make([]string, 0, len(manifest.Routes))
	for _, route := range manifest.Routes {
		want = append(want, route.Method+" "+route.Path)
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
		for _, match := range routeRegistrationPattern.FindAllStringSubmatch(string(data), -1) {
			if strings.HasPrefix(match[2], "/api/pocketcoder/") {
				got = append(got, match[1]+" "+match[2])
			}
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	sort.Strings(got)
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("backend routes differ from api/pocketcoder-routes.json\n got: %v\nwant: %v", got, want)
	}
}
