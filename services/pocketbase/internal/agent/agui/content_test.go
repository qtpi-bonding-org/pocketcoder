package agui

import (
	"testing"

	acpsdk "github.com/coder/acp-go-sdk"
)

func TestRenderContentText(t *testing.T) {
	text, media, ok := renderContent(acpsdk.ContentBlock{Text: &acpsdk.ContentBlockText{Type: "text", Text: "hi"}})
	if !ok || text != "hi" || media != nil {
		t.Fatalf("text: got (%q,%v,%v)", text, media, ok)
	}
}

func TestRenderContentImage(t *testing.T) {
	uri := "https://x/y.png"
	_, media, ok := renderContent(acpsdk.ContentBlock{Image: &acpsdk.ContentBlockImage{Type: "image", MimeType: "image/png", Uri: &uri}})
	if !ok || media == nil || media.Kind != "image" || media.MimeType != "image/png" || media.URI != uri {
		t.Fatalf("image: got %+v ok=%v", media, ok)
	}
}

func TestRenderContentResourceLinkAndResource(t *testing.T) {
	_, media, ok := renderContent(acpsdk.ContentBlock{ResourceLink: &acpsdk.ContentBlockResourceLink{Type: "resource_link", Name: "f.go"}})
	if !ok || media == nil || media.Kind != "resource_link" || media.Name != "f.go" {
		t.Fatalf("resource_link: got %+v ok=%v", media, ok)
	}
	_, media, ok = renderContent(acpsdk.ContentBlock{Resource: &acpsdk.ContentBlockResource{Type: "resource"}})
	if !ok || media == nil || media.Kind != "resource" {
		t.Fatalf("resource: got %+v ok=%v", media, ok)
	}
}

func TestRenderContentEmpty(t *testing.T) {
	if _, _, ok := renderContent(acpsdk.ContentBlock{}); ok {
		t.Fatal("empty block should be ok=false")
	}
}

func TestRenderToolContentTextDiffTerminal(t *testing.T) {
	old := "a\n"
	content := []acpsdk.ToolCallContent{
		{Content: &acpsdk.ToolCallContentContent{Type: "content", Content: acpsdk.ContentBlock{Text: &acpsdk.ContentBlockText{Type: "text", Text: "ran ok"}}}},
		{Diff: &acpsdk.ToolCallContentDiff{Path: "/f.go", OldText: &old, NewText: "b\n"}},
		{Terminal: &acpsdk.ToolCallContentTerminal{TerminalId: "t1", Type: "terminal"}},
	}
	text, diffs, terms, has, err := renderToolContent(content, nil)
	if err != nil || !has {
		t.Fatalf("err=%v has=%v", err, has)
	}
	if text != "ran ok" {
		t.Fatalf("text=%q", text)
	}
	if len(diffs) != 1 || diffs[0].Path != "/f.go" || diffs[0].NewText != "b\n" || diffs[0].OldText != "a\n" {
		t.Fatalf("diffs=%+v", diffs)
	}
	if len(terms) != 1 || terms[0].TerminalID != "t1" {
		t.Fatalf("terms=%+v", terms)
	}
}

func TestRenderToolContentRawFallback(t *testing.T) {
	text, _, _, has, err := renderToolContent(nil, map[string]any{"exit": 0})
	if err != nil || !has || text == "" {
		t.Fatalf("rawOutput fallback: text=%q has=%v err=%v", text, has, err)
	}
}
