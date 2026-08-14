package releaseidentity

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"regexp"

	"github.com/pocketbase/pocketbase/core"
)

var releasePattern = regexp.MustCompile(`^[0-9a-f]{40}$`)

type Catalog struct {
	SchemaVersion  int       `json:"schemaVersion"`
	DefaultHarness string    `json:"defaultHarness"`
	Harnesses      []Harness `json:"harnesses"`
}

type Harness struct {
	ID              string `json:"id"`
	ComposeService  string `json:"composeService"`
	ImageRepository string `json:"imageRepository"`
	UpstreamVersion string `json:"upstreamVersion"`
}

func LoadCatalog(path string) (Catalog, error) {
	file, err := os.Open(path)
	if err != nil {
		return Catalog{}, fmt.Errorf("open harness catalog: %w", err)
	}
	defer file.Close()

	decoder := json.NewDecoder(file)
	decoder.DisallowUnknownFields()
	var catalog Catalog
	if err := decoder.Decode(&catalog); err != nil {
		return Catalog{}, fmt.Errorf("decode harness catalog: %w", err)
	}
	if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		return Catalog{}, errors.New("decode harness catalog: trailing JSON value")
	}
	if catalog.SchemaVersion != 1 || len(catalog.Harnesses) == 0 {
		return Catalog{}, errors.New("unsupported harness catalog")
	}
	seen := make(map[string]struct{}, len(catalog.Harnesses))
	defaultFound := false
	for _, harness := range catalog.Harnesses {
		if harness.ID == "" || harness.ComposeService == "" || harness.ImageRepository == "" || harness.UpstreamVersion == "" {
			return Catalog{}, errors.New("harness catalog contains an empty field")
		}
		if _, exists := seen[harness.ID]; exists {
			return Catalog{}, fmt.Errorf("duplicate harness ID %q", harness.ID)
		}
		seen[harness.ID] = struct{}{}
		defaultFound = defaultFound || harness.ID == catalog.DefaultHarness
	}
	if !defaultFound {
		return Catalog{}, errors.New("default harness is not in the catalog")
	}
	return catalog, nil
}

func SyncHarnessImages(app core.App, catalogPath, release string) error {
	if !releasePattern.MatchString(release) {
		return fmt.Errorf("invalid PocketCoder release identity %q", release)
	}
	catalog, err := LoadCatalog(catalogPath)
	if err != nil {
		return err
	}
	for _, harness := range catalog.Harnesses {
		record, err := app.FindFirstRecordByFilter(
			"harnesses",
			"cli_id = {:cliID}",
			map[string]any{"cliID": harness.ID},
		)
		if err != nil {
			return fmt.Errorf("find harness %q: %w", harness.ID, err)
		}
		image := harness.ImageRepository + ":" + release
		if record.GetString("container_image") == image {
			continue
		}
		record.Set("container_image", image)
		if err := app.Save(record); err != nil {
			return fmt.Errorf("save harness %q release image: %w", harness.ID, err)
		}
	}
	return nil
}
