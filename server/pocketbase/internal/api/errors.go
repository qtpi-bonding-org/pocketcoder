package api

import "github.com/pocketbase/pocketbase/core"

// pocketCoderError keeps custom operations compatible with PocketBase's
// standard ClientException response shape: {code, message, data}.
func pocketCoderError(re *core.RequestEvent, code int, message string) error {
	return re.JSON(code, map[string]any{
		"code":    code,
		"message": message,
		"data":    map[string]any{},
	})
}
