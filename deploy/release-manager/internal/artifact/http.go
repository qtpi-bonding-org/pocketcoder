package artifact

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"

	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/contract"
)

type Fetcher struct {
	Client *http.Client
}

func (fetcher Fetcher) ArtifactToFile(descriptor contract.Artifact, directory string) (string, error) {
	if err := os.MkdirAll(directory, 0o700); err != nil {
		return "", err
	}
	path := filepath.Join(directory, descriptor.SHA256+".part")
	// A killed process can leave a partial file. Mutating commands hold the
	// release lock, so this path cannot belong to another active download.
	if err := os.Remove(path); err != nil && !os.IsNotExist(err) {
		return "", err
	}
	file, err := os.OpenFile(path, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o600)
	if err != nil {
		return "", err
	}
	keep := false
	defer func() {
		file.Close()
		if !keep {
			os.Remove(path)
		}
	}()
	client := fetcher.Client
	if client == nil {
		client = http.DefaultClient
	}
	response, err := client.Get(descriptor.URL)
	if err != nil {
		return "", fmt.Errorf("fetch %s: %w", descriptor.URL, err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return "", fmt.Errorf("fetch %s: HTTP %d", descriptor.URL, response.StatusCode)
	}
	if response.ContentLength > descriptor.DownloadBytes {
		return "", fmt.Errorf("artifact declared body exceeds expected size")
	}
	hasher := sha256.New()
	written, err := io.Copy(io.MultiWriter(file, hasher), io.LimitReader(response.Body, descriptor.DownloadBytes+1))
	if err != nil {
		return "", err
	}
	if written != descriptor.DownloadBytes {
		return "", fmt.Errorf("artifact size mismatch: got %d, want %d", written, descriptor.DownloadBytes)
	}
	if hex.EncodeToString(hasher.Sum(nil)) != descriptor.SHA256 {
		return "", fmt.Errorf("artifact checksum mismatch")
	}
	if err := file.Sync(); err != nil {
		return "", err
	}
	if err := file.Close(); err != nil {
		return "", err
	}
	keep = true
	return path, nil
}

func (fetcher Fetcher) Bounded(url string, maximum int64) ([]byte, error) {
	if maximum < 1 {
		return nil, fmt.Errorf("invalid download bound")
	}
	client := fetcher.Client
	if client == nil {
		client = http.DefaultClient
	}
	request, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	response, err := client.Do(request)
	if err != nil {
		return nil, fmt.Errorf("fetch %s: %w", url, err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("fetch %s: HTTP %d", url, response.StatusCode)
	}
	if response.ContentLength > maximum {
		return nil, fmt.Errorf("fetch %s: declared body exceeds %d bytes", url, maximum)
	}
	data, err := io.ReadAll(io.LimitReader(response.Body, maximum+1))
	if err != nil {
		return nil, fmt.Errorf("read %s: %w", url, err)
	}
	if int64(len(data)) > maximum {
		return nil, fmt.Errorf("fetch %s: body exceeds %d bytes", url, maximum)
	}
	return data, nil
}
