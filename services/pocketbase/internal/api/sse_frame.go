package api

import (
	"fmt"
	"io"
	"strings"

	"github.com/ag-ui-protocol/ag-ui/sdks/community/go/pkg/core/events"
)

// writeSeqFrame writes one SSE frame whose id: line is the chat-global seq
// (not the AG-UI SDK's default `<Type>_<timestamp>` id, which the stream
// route needs to be a monotonic cursor clients can resume from via
// Last-Event-ID / ?cursor=). Newlines in the JSON payload are escaped so the
// frame stays a single `data:` line per the SSE wire format.
func writeSeqFrame(w io.Writer, seq int, ev events.Event) error {
	data, err := ev.ToJSON()
	if err != nil {
		return err
	}
	escaped := strings.ReplaceAll(string(data), "\n", "\\n")
	escaped = strings.ReplaceAll(escaped, "\r", "\\r")
	_, err = fmt.Fprintf(w, "id: %d\ndata: %s\n\n", seq, escaped)
	return err
}
