package main

import (
	"archive/tar"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"
)

func main() {
	if len(os.Args) != 2 || os.Args[1] != "materialize" {
		fmt.Fprintln(os.Stderr, "usage: git-materializer materialize")
		os.Exit(2)
	}
	if err := materialize("/inbox", "/state"); err != nil {
		fmt.Fprintln(os.Stderr, "materialize error:", err)
		os.Exit(1)
	}
	fmt.Println("pocketcoder-materialized")
}

func materialize(inbox, state string) error {
	f, err := os.Open(filepath.Join(inbox, "manifest.tar"))
	if err != nil {
		return err
	}
	defer f.Close()
	generation := fmt.Sprintf("%d", time.Now().UnixNano())
	root := filepath.Join(state, "generations", generation)
	if err := os.MkdirAll(root, 0700); err != nil {
		return err
	}
	seen := map[string]bool{}
	tr := tar.NewReader(f)
	for {
		h, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}
		if h.Typeflag != tar.TypeReg {
			return fmt.Errorf("non-regular entry %q", h.Name)
		}
		name := filepath.Clean(h.Name)
		if name == "." || filepath.IsAbs(name) || name == ".." || strings.HasPrefix(name, "../") || seen[name] {
			return fmt.Errorf("unsafe manifest path %q", h.Name)
		}
		seen[name] = true
		if h.Size > 256*1024 {
			return fmt.Errorf("manifest entry too large")
		}
		mode := os.FileMode(h.Mode) & 0777
		if mode != 0600 && mode != 0644 && mode != 0700 {
			return fmt.Errorf("unsafe mode for %q", h.Name)
		}
		dest := filepath.Join(root, name)
		if err := os.MkdirAll(filepath.Dir(dest), 0700); err != nil {
			return err
		}
		out, err := os.OpenFile(dest, os.O_CREATE|os.O_EXCL|os.O_WRONLY, mode)
		if err != nil {
			return err
		}
		if _, err = io.CopyN(out, tr, h.Size); err != nil {
			out.Close()
			return err
		}
		if err = out.Close(); err != nil {
			return err
		}
	}
	tmp := filepath.Join(state, ".current.tmp")
	_ = os.Remove(tmp)
	if err := os.Symlink(filepath.Join("generations", generation), tmp); err != nil {
		return err
	}
	current, old := filepath.Join(state, "current"), filepath.Join(state, ".current.old")
	_ = os.Remove(old)
	_ = os.Rename(current, old)
	if err := os.Rename(tmp, current); err != nil {
		_ = os.Rename(old, current)
		return err
	}
	_ = os.Remove(old)
	return nil
}
