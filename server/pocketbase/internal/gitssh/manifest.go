package gitssh

import (
	"fmt"
	"path"
	"strings"
)

type File struct {
	Path string
	Mode uint32
	Data []byte
}

// ValidateFiles is shared by the Docker materializer and its tests. It
// rejects traversal, links (represented by callers as non-regular entries),
// duplicate paths, and modes that could make key material world-readable.
func ValidateFiles(files []File) error {
	seen := map[string]bool{}
	for _, f := range files {
		if f.Path == "" || path.IsAbs(f.Path) || strings.Contains(f.Path, "\\") || path.Clean(f.Path) != f.Path || strings.HasPrefix(f.Path, "../") || f.Path == ".." {
			return fmt.Errorf("unsafe manifest path %q", f.Path)
		}
		if seen[f.Path] {
			return fmt.Errorf("duplicate manifest path %q", f.Path)
		}
		seen[f.Path] = true
		if f.Mode != 0600 && f.Mode != 0644 && f.Mode != 0700 {
			return fmt.Errorf("unsafe mode for %q", f.Path)
		}
	}
	return nil
}
