package api

import (
	"github.com/pocketbase/pocketbase/core"
)

// requireRole enforces authentication and membership in one of the supplied
// roles.  Authentication failures deliberately have a different status from
// authorization failures.
func requireRole(re *core.RequestEvent, roles ...string) error {
	if re.Auth == nil {
		return re.UnauthorizedError("Authentication required", nil)
	}
	role := re.Auth.GetString("role")
	for _, allowed := range roles {
		if role == allowed {
			return nil
		}
	}
	return re.ForbiddenError("Insufficient permissions", nil)
}

// requireOwnedRecord returns a record only when it belongs to the caller.
// Missing, unauthenticated, and non-owned records are intentionally
// indistinguishable to callers.
func requireOwnedRecord(app core.App, re *core.RequestEvent, collection, id string) (*core.Record, error) {
	if re.Auth == nil {
		return nil, re.NotFoundError("Record not found", nil)
	}
	record, err := app.FindRecordById(collection, id)
	if err != nil || record.GetString("user") != re.Auth.Id {
		return nil, re.NotFoundError("Record not found", nil)
	}
	return record, nil
}
