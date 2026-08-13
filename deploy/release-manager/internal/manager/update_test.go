package manager

import (
	"reflect"
	"testing"

	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/contract"
	releasecontract "github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/release"
)

func TestDiscoverLocalSelectionsPreservesAcquiredHarnessesAndOptionalImages(t *testing.T) {
	current := releasecontract.Current{SelectedHarnesses: []string{"goose"}}
	previous := contract.Manifest{Images: contract.Images{
		Choices: map[string]contract.ChoiceGroup{
			"coding": {
				CatalogDocument: "coding-harnesses",
				Options: map[string]contract.Artifact{
					"goose":  {Images: []string{"goose:a"}},
					"codex":  {Images: []string{"codex:a"}},
					"absent": {Images: []string{"absent:a"}},
				},
			},
		},
		Optional: map[string]contract.Artifact{
			"ollama": {Images: []string{"ollama:a"}},
		},
	}}
	local := map[string]bool{"goose:a": true, "codex:a": true, "ollama:a": true}

	discoverLocalSelections(&current, previous, func(image string) bool {
		return local[image]
	})

	if !reflect.DeepEqual(current.SelectedHarnesses, []string{"codex", "goose"}) {
		t.Fatalf("selected harnesses = %#v", current.SelectedHarnesses)
	}
	if !reflect.DeepEqual(current.SelectedOptionalImages, []string{"ollama"}) {
		t.Fatalf("selected optional images = %#v", current.SelectedOptionalImages)
	}
}
