package release

import (
	"reflect"
	"testing"

	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/contract"
)

func TestSelectedProfilesComeFromRegistryDescriptors(t *testing.T) {
	activation := Activation{
		OptionalImages: []string{"ollama", "ntfy"},
		Manifest: contract.Manifest{Images: contract.Images{Registry: contract.RegistryImages{
			Optional: map[string]contract.OptionalRegistryImage{
				"ollama": {ComposeProfile: "local-models"},
				"ntfy":   {ComposeProfile: "foss"},
			},
		}}},
	}
	profiles, err := activation.selectedProfiles()
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(profiles, []string{"local-models", "foss"}) {
		t.Fatalf("profiles = %#v", profiles)
	}
}

func TestSelectedProfilesRejectsUnknownOptionalImage(t *testing.T) {
	activation := Activation{OptionalImages: []string{"unknown"}}
	if _, err := activation.selectedProfiles(); err == nil {
		t.Fatal("unknown optional image was accepted")
	}
}
