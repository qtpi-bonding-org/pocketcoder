package api

import (
	"net/http"

	"github.com/pocketbase/pocketbase/core"
)

// pocketCoderError keeps custom operations compatible with PocketBase's
// standard ClientException response shape: {code, message, data}.
func pocketCoderError(re *core.RequestEvent, code int, message string) error {
	return re.JSON(code, map[string]any{
		"code":    code,
		"message": message,
		"data":    map[string]any{},
	})
}

// requireRole enforces authentication and membership in one of the supplied
// roles.  Authentication failures deliberately have a different status from
// authorization failures.
func requireRole(re *core.RequestEvent, roles ...string) error {
	if re.Auth == nil {
		return pocketCoderError(re, http.StatusUnauthorized, "Authentication required")
	}
	role := re.Auth.GetString("role")
	for _, allowed := range roles {
		if role == allowed {
			return nil
		}
	}
	return pocketCoderError(re, http.StatusForbidden, "Insufficient permissions")
}

// requireOwnedRecord returns a record only when it belongs to the caller.
// Missing, unauthenticated, and non-owned records are intentionally
// indistinguishable to callers.
func requireOwnedRecord(app core.App, re *core.RequestEvent, collection, id string) (*core.Record, error) {
	if re.Auth == nil {
		return nil, pocketCoderError(re, http.StatusNotFound, "Record not found")
	}
	record, err := app.FindRecordById(collection, id)
	if err != nil || record.GetString("user") != re.Auth.Id {
		return nil, pocketCoderError(re, http.StatusNotFound, "Record not found")
	}
	return record, nil
}
