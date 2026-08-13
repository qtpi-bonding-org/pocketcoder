package artifact

import (
	"archive/tar"
	"compress/gzip"
	"io"
	"os"
	"path/filepath"
	"testing"
)

func writeArchive(t *testing.T, name string) (string, int64) {
	t.Helper()
	path := filepath.Join(t.TempDir(), "server.tar.gz")
	file, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	gzipWriter := gzip.NewWriter(file)
	writer := tar.NewWriter(gzipWriter)
	content := []byte("release")
	if err := writer.WriteHeader(&tar.Header{Name: name, Mode: 0o644, Size: int64(len(content)), Typeflag: tar.TypeReg}); err != nil {
		t.Fatal(err)
	}
	if _, err := writer.Write(content); err != nil {
		t.Fatal(err)
	}
	if err := writer.Close(); err != nil {
		t.Fatal(err)
	}
	if err := gzipWriter.Close(); err != nil {
		t.Fatal(err)
	}
	if err := file.Close(); err != nil {
		t.Fatal(err)
	}
	input, err := os.Open(path)
	if err != nil {
		t.Fatal(err)
	}
	decompressor, err := gzip.NewReader(input)
	if err != nil {
		t.Fatal(err)
	}
	expanded, err := io.Copy(io.Discard, decompressor)
	if err != nil {
		t.Fatal(err)
	}
	if err := decompressor.Close(); err != nil {
		t.Fatal(err)
	}
	if err := input.Close(); err != nil {
		t.Fatal(err)
	}
	return path, expanded
}

func TestExtractServerFilesRejectsTraversal(t *testing.T) {
	path, expanded := writeArchive(t, "../escape")
	if err := ExtractServerFiles(path, t.TempDir(), expanded); err == nil {
		t.Fatal("expected traversal rejection")
	}
}

func TestExtractServerFilesWritesRegularFile(t *testing.T) {
	destination := t.TempDir()
	path, expanded := writeArchive(t, "release.json")
	if err := ExtractServerFiles(path, destination, expanded); err != nil {
		t.Fatal(err)
	}
	if data, err := os.ReadFile(filepath.Join(destination, "release.json")); err != nil || string(data) != "release" {
		t.Fatalf("data=%q err=%v", data, err)
	}
}

func TestExtractServerFilesEnforcesExpandedSize(t *testing.T) {
	path, expanded := writeArchive(t, "release.json")
	if err := ExtractServerFiles(path, t.TempDir(), expanded-1); err == nil {
		t.Fatal("expected expanded-size rejection")
	}
}
