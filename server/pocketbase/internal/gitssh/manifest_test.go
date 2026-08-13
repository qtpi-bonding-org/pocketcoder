package gitssh

import "testing"

func TestValidateFiles(t *testing.T) {
	if err := ValidateFiles([]File{{Path: "keys/k", Mode: 0600}, {Path: "known_hosts", Mode: 0644}}); err != nil {
		t.Fatal(err)
	}
	for _, files := range [][]File{{{Path: "../key", Mode: 0600}}, {{Path: "/key", Mode: 0600}}, {{Path: "key", Mode: 0644}, {Path: "key", Mode: 0644}}, {{Path: "key", Mode: 0755}}} {
		if err := ValidateFiles(files); err == nil {
			t.Errorf("accepted unsafe manifest: %+v", files)
		}
	}
}
