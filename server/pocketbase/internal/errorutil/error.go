package errorutil

import (
	"errors"
	"log"
	"net/http"

	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/tools/router"
)

// Internal logs the underlying error server-side and returns a safe generic
// error to the client. Plain errors from strict handlers are otherwise
// converted by PocketBase into a misleading 400 response.
func Internal(context string, err error) error {
	log.Printf("[pocketcoder] %s: %v", context, err)
	var apiErr *router.ApiError
	if errors.As(err, &apiErr) {
		return err
	}
	return apis.NewApiError(http.StatusInternalServerError, context, nil)
}
