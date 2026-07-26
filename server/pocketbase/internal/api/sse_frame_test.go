package api

import (
	"strings"
	"testing"

	"github.com/ag-ui-protocol/ag-ui/sdks/community/go/pkg/core/events"
)

func TestWriteSeqFrameEmitsSeqIdAndData(t *testing.T) {
	var b strings.Builder
	ev := events.NewTextMessageContentEvent("m", "hello")
	if err := writeSeqFrame(&b, 7, ev); err != nil {
		t.Fatal(err)
	}
	out := b.String()
	if !strings.Contains(out, "id: 7\n") {
		t.Fatalf("frame missing seq id line: %q", out)
	}
	if !strings.Contains(out, "data: ") || !strings.HasSuffix(out, "\n\n") {
		t.Fatalf("frame malformed: %q", out)
	}
	if strings.Count(out, "\n\ndata") > 0 {
		t.Fatalf("data must be single-line (newlines escaped): %q", out)
	}
}
