// PocketCoder release compatibility and authenticated update status APIs.
package api

import (
	"encoding/json"
	"errors"
	"net/http"
	"os"
	"path/filepath"

	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"
)

const defaultReleaseStateDir = "/var/lib/pocketcoder/release"

type releasePointerResponse struct {
	ReleaseDigest             string          `json:"releaseDigest"`
	SourceCommit              string          `json:"sourceCommit"`
	ServerVersion             string          `json:"serverVersion"`
	DataVersion               int             `json:"dataVersion"`
	DeploymentContractVersion int             `json:"deploymentContractVersion"`
	Compatibility             json.RawMessage `json:"compatibility"`
}

var developmentCompatibility = map[string]any{
	"app": map[string]any{
		"contractVersion": 1,
		"officialMinimumVersions": map[string]string{
			"pocketcoder-pro":  "1.0.0",
			"pocketcoder-foss": "1.0.0",
		},
	},
	"server": map[string]int{"apiVersion": 1},
	"workers": map[string]int{
		"image-relay": 1,
		"push-relay":  1,
		"oauth-relay": 1,
	},
	"provisioning": map[string]int{"contractVersion": 1},
	"deployment": map[string]any{
		"contractVersion": 1,
		"supportedSourceContractVersions": map[string]int{
			"minimum": 1,
			"maximum": 1,
		},
	},
}

func releaseStateDir() string {
	if value := os.Getenv("POCKETCODER_RELEASE_STATE_DIR"); value != "" {
		return value
	}
	return defaultReleaseStateDir
}

func readJSON(path string, target any) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	return json.Unmarshal(data, target)
}

func AddReleaseStatusOperations(registry *operation.Registry) {
	registry.Add(operation.Route{OperationID: "getReleaseCompatibility", Method: http.MethodGet, Path: "/api/pocketcoder/v1/compatibility", Action: func(re *core.RequestEvent) error {
		dataVersion := 1
		compatibility := any(developmentCompatibility)
		var pointer releasePointerResponse
		if err := readJSON(filepath.Join(releaseStateDir(), "current.json"), &pointer); err == nil {
			dataVersion = pointer.DataVersion
			if len(pointer.Compatibility) != 0 {
				compatibility = pointer.Compatibility
			}
		}
		return re.JSON(http.StatusOK, map[string]any{
			"schemaVersion": 1,
			"dataVersion":   dataVersion,
			"compatibility": compatibility,
		})
	}})

	registry.Add(operation.Route{OperationID: "getReleaseStatus", Method: http.MethodGet, Path: "/api/pocketcoder/v1/release/status", Auth: true, Action: func(re *core.RequestEvent) error {
		var pointer releasePointerResponse
		if err := readJSON(filepath.Join(releaseStateDir(), "current.json"), &pointer); err != nil &&
			!errors.Is(err, os.ErrNotExist) {
			return pocketCoderError(re, 500, "release state unavailable")
		}
		var metadataStatus map[string]any
		if err := readJSON(filepath.Join(releaseStateDir(), "metadata-status.json"), &metadataStatus); err != nil {
			metadataStatus = map[string]any{"schemaVersion": 1, "status": "unknown"}
		}
		return re.JSON(http.StatusOK, map[string]any{
			"schemaVersion":  1,
			"current":        pointer,
			"metadataStatus": metadataStatus,
		})
	}})
}
