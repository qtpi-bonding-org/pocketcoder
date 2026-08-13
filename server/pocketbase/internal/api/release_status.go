// PocketCoder release compatibility and authenticated update status APIs.
package api

import (
	"encoding/json"
	"errors"
	"net/http"
	"os"
	"path/filepath"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/openapi"
)

const defaultReleaseStateDir = "/var/lib/pocketcoder/release"

type releasePointerResponse struct {
	ReleaseDigest             string `json:"releaseDigest"`
	SourceCommit              string `json:"sourceCommit"`
	ServerVersion             string `json:"serverVersion"`
	DataVersion               int    `json:"dataVersion"`
	DeploymentContractVersion int    `json:"deploymentContractVersion"`
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

// RegisterReleaseStatusApi exposes contract-only compatibility before login
// and detailed release/update identity only to authenticated owners.
func RegisterReleaseStatusApi(_ *pocketbase.PocketBase, e *core.ServeEvent) {
	e.Router.GET("/api/pocketcoder/release/compatibility", func(re *core.RequestEvent) error {
		dataVersion := 1
		deploymentContractVersion := 1
		var pointer releasePointerResponse
		if err := readJSON(filepath.Join(releaseStateDir(), "current.json"), &pointer); err == nil {
			dataVersion = pointer.DataVersion
			deploymentContractVersion = pointer.DeploymentContractVersion
		}
		response := map[string]any{
			"schemaVersion": 1,
			"dataVersion":   dataVersion,
			"compatibility": map[string]any{
				"app":        map[string]int{"contractVersion": 1},
				"server":     map[string]int{"apiVersion": 1},
				"deployment": map[string]int{"contractVersion": deploymentContractVersion},
			},
		}
		return writeGeneratedJSON(re, openapi.GetReleaseCompatibility200JSONResponse{
			JsonSuccessJSONResponse: openapi.JsonSuccessJSONResponse(response),
		})
	})

	e.Router.GET("/api/pocketcoder/release/status", func(re *core.RequestEvent) error {
		var pointer releasePointerResponse
		if err := readJSON(filepath.Join(releaseStateDir(), "current.json"), &pointer); err != nil &&
			!errors.Is(err, os.ErrNotExist) {
			return pocketCoderError(re, 500, "release state unavailable")
		}
		var metadataStatus map[string]any
		if err := readJSON(filepath.Join(releaseStateDir(), "metadata-status.json"), &metadataStatus); err != nil {
			metadataStatus = map[string]any{"schemaVersion": 1, "status": "unknown"}
		}
		return writeGeneratedJSON(re, openapi.GetReleaseStatus200JSONResponse{
			JsonSuccessJSONResponse: openapi.JsonSuccessJSONResponse(map[string]any{
				"schemaVersion":  1,
				"current":        pointer,
				"metadataStatus": metadataStatus,
			}),
		})
	}).Bind(apis.RequireAuth())
}

func writeGeneratedJSON(re *core.RequestEvent, response any) error {
	if typed, ok := response.(interface {
		VisitGetReleaseCompatibilityResponse(http.ResponseWriter) error
	}); ok {
		return typed.VisitGetReleaseCompatibilityResponse(re.Response)
	}
	if typed, ok := response.(interface {
		VisitGetReleaseStatusResponse(http.ResponseWriter) error
	}); ok {
		return typed.VisitGetReleaseStatusResponse(re.Response)
	}
	return re.InternalServerError("generated response type mismatch", nil)
}
