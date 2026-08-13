package snapshot

import (
	"archive/tar"
	"compress/gzip"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/state"
)

type Manager struct {
	DataVolume   string
	BackupVolume string
	StateRoot    string
	Container    string
	Retain       int
}

type Metadata struct {
	SchemaVersion int    `json:"schemaVersion"`
	ReleaseDigest string `json:"releaseDigest"`
	DataVersion   int    `json:"dataVersion"`
	Archive       string `json:"archive"`
	SHA256        string `json:"sha256"`
	Bytes         int64  `json:"bytes"`
	CreatedAt     string `json:"createdAt"`
}

func (manager Manager) Create(releaseDigest string, dataVersion int) (string, error) {
	dataRoot, err := volumeMountpoint(manager.dataVolume())
	if err != nil {
		return "", err
	}
	backupRoot, err := volumeMountpoint(manager.backupVolume())
	if err != nil {
		return "", err
	}
	if err := exec.Command("docker", "stop", manager.container()).Run(); err != nil {
		return "", fmt.Errorf("stop PocketBase before snapshot: %w", err)
	}
	restartOnError := true
	defer func() {
		if restartOnError {
			_ = exec.Command("docker", "start", manager.container()).Run()
		}
	}()
	archiveName := "update-" + releaseDigest + ".tar.gz"
	archivePath := filepath.Join(backupRoot, archiveName)
	if err := createArchive(dataRoot, archivePath); err != nil {
		return "", err
	}
	digest, bytes, err := digestFile(archivePath)
	if err != nil {
		return "", err
	}
	metadata := Metadata{SchemaVersion: 1, ReleaseDigest: releaseDigest, DataVersion: dataVersion, Archive: archiveName, SHA256: digest, Bytes: bytes, CreatedAt: time.Now().UTC().Format(time.RFC3339)}
	metadataPath := manager.metadataPath(releaseDigest)
	if err := state.WriteJSONAtomic(metadataPath, metadata, 0o600); err != nil {
		return "", err
	}
	if err := manager.cleanup(backupRoot); err != nil {
		return "", err
	}
	restartOnError = false
	return metadataPath, nil
}

func (manager Manager) Restore(metadataPath string) error {
	data, err := os.ReadFile(metadataPath)
	if err != nil {
		return err
	}
	var metadata Metadata
	if err := json.Unmarshal(data, &metadata); err != nil {
		return err
	}
	dataRoot, err := volumeMountpoint(manager.dataVolume())
	if err != nil {
		return err
	}
	backupRoot, err := volumeMountpoint(manager.backupVolume())
	if err != nil {
		return err
	}
	archivePath := filepath.Join(backupRoot, metadata.Archive)
	digest, bytes, err := digestFile(archivePath)
	if err != nil {
		return err
	}
	if digest != metadata.SHA256 || bytes != metadata.Bytes {
		return fmt.Errorf("snapshot checksum or size mismatch")
	}
	_ = exec.Command("docker", "stop", manager.container()).Run()
	entries, err := os.ReadDir(dataRoot)
	if err != nil {
		return err
	}
	for _, entry := range entries {
		if err := os.RemoveAll(filepath.Join(dataRoot, entry.Name())); err != nil {
			return err
		}
	}
	return extractArchive(archivePath, dataRoot)
}

func (manager Manager) metadataPath(digest string) string {
	return filepath.Join(manager.StateRoot, "update-snapshots", digest+".json")
}
func (manager Manager) dataVolume() string {
	if manager.DataVolume != "" {
		return manager.DataVolume
	}
	return "pocketcoder_pb_data"
}
func (manager Manager) backupVolume() string {
	if manager.BackupVolume != "" {
		return manager.BackupVolume
	}
	return "pocketcoder_pb_backups"
}
func (manager Manager) container() string {
	if manager.Container != "" {
		return manager.Container
	}
	return "pocketcoder-pocketbase"
}

func volumeMountpoint(volume string) (string, error) {
	output, err := exec.Command("docker", "volume", "inspect", "--format", "{{.Mountpoint}}", volume).Output()
	if err != nil {
		return "", fmt.Errorf("inspect Docker volume %s: %w", volume, err)
	}
	path := strings.TrimSpace(string(output))
	if path == "" || !filepath.IsAbs(path) {
		return "", fmt.Errorf("Docker volume %s has invalid mountpoint", volume)
	}
	return path, nil
}

// VolumeBytes returns the current size of regular files in the data volume.
// It is used during update preflight so a data-version-changing release can
// reserve enough disk for the PocketBase snapshot before stopping services.
func (manager Manager) VolumeBytes() (int64, error) {
	root, err := volumeMountpoint(manager.dataVolume())
	if err != nil {
		return 0, err
	}
	var total int64
	err = filepath.Walk(root, func(_ string, info os.FileInfo, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if info.Mode().IsRegular() {
			total += info.Size()
		}
		return nil
	})
	return total, err
}

func createArchive(source, destination string) error {
	if err := os.MkdirAll(filepath.Dir(destination), 0o700); err != nil {
		return err
	}
	temporary := destination + ".part"
	os.Remove(temporary)
	file, err := os.OpenFile(temporary, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o600)
	if err != nil {
		return err
	}
	gzipWriter := gzip.NewWriter(file)
	tarWriter := tar.NewWriter(gzipWriter)
	err = filepath.Walk(source, func(path string, info os.FileInfo, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if path == source {
			return nil
		}
		if !info.Mode().IsRegular() && !info.IsDir() {
			return fmt.Errorf("unsupported snapshot entry %s", path)
		}
		relative, err := filepath.Rel(source, path)
		if err != nil {
			return err
		}
		header, err := tar.FileInfoHeader(info, "")
		if err != nil {
			return err
		}
		header.Name = filepath.ToSlash(relative)
		if err := tarWriter.WriteHeader(header); err != nil {
			return err
		}
		if info.Mode().IsRegular() {
			input, err := os.Open(path)
			if err != nil {
				return err
			}
			_, copyErr := io.Copy(tarWriter, input)
			closeErr := input.Close()
			if copyErr != nil {
				return copyErr
			}
			if closeErr != nil {
				return closeErr
			}
		}
		return nil
	})
	if closeErr := tarWriter.Close(); err == nil {
		err = closeErr
	}
	if closeErr := gzipWriter.Close(); err == nil {
		err = closeErr
	}
	if err == nil {
		err = file.Sync()
	}
	if closeErr := file.Close(); err == nil {
		err = closeErr
	}
	if err != nil {
		os.Remove(temporary)
		return err
	}
	if err := os.Rename(temporary, destination); err != nil {
		return err
	}
	return state.SyncDirectory(filepath.Dir(destination))
}

func extractArchive(path, destination string) error {
	file, err := os.Open(path)
	if err != nil {
		return err
	}
	defer file.Close()
	gzipReader, err := gzip.NewReader(file)
	if err != nil {
		return err
	}
	defer gzipReader.Close()
	reader := tar.NewReader(gzipReader)
	for {
		header, err := reader.Next()
		if err == io.EOF {
			return nil
		}
		if err != nil {
			return err
		}
		name := filepath.Clean(header.Name)
		if filepath.IsAbs(name) || name == ".." || strings.HasPrefix(name, ".."+string(filepath.Separator)) {
			return fmt.Errorf("unsafe snapshot path")
		}
		target := filepath.Join(destination, name)
		switch header.Typeflag {
		case tar.TypeDir:
			if err := os.MkdirAll(target, os.FileMode(header.Mode)&0o700); err != nil {
				return err
			}
		case tar.TypeReg, tar.TypeRegA:
			if err := os.MkdirAll(filepath.Dir(target), 0o700); err != nil {
				return err
			}
			output, err := os.OpenFile(target, os.O_CREATE|os.O_EXCL|os.O_WRONLY, os.FileMode(header.Mode)&0o700)
			if err != nil {
				return err
			}
			_, copyErr := io.CopyN(output, reader, header.Size)
			syncErr := output.Sync()
			closeErr := output.Close()
			if copyErr != nil {
				return copyErr
			}
			if syncErr != nil {
				return syncErr
			}
			if closeErr != nil {
				return closeErr
			}
		default:
			return fmt.Errorf("unsupported snapshot entry")
		}
	}
}

func digestFile(path string) (string, int64, error) {
	file, err := os.Open(path)
	if err != nil {
		return "", 0, err
	}
	defer file.Close()
	hash := sha256.New()
	bytes, err := io.Copy(hash, file)
	return hex.EncodeToString(hash.Sum(nil)), bytes, err
}

func (manager Manager) cleanup(backupRoot string) error {
	retain := manager.Retain
	if retain == 0 {
		retain = 2
	}
	directory := filepath.Join(manager.StateRoot, "update-snapshots")
	entries, err := os.ReadDir(directory)
	if err != nil {
		return err
	}
	type item struct {
		path     string
		modified time.Time
	}
	items := make([]item, 0, len(entries))
	for _, entry := range entries {
		if filepath.Ext(entry.Name()) != ".json" {
			continue
		}
		info, err := entry.Info()
		if err != nil {
			return err
		}
		items = append(items, item{filepath.Join(directory, entry.Name()), info.ModTime()})
	}
	sort.Slice(items, func(i, j int) bool { return items[i].modified.After(items[j].modified) })
	for _, stale := range items[retain:] {
		data, err := os.ReadFile(stale.path)
		if err != nil {
			return err
		}
		var metadata Metadata
		if err := json.Unmarshal(data, &metadata); err != nil {
			return err
		}
		if err := os.Remove(filepath.Join(backupRoot, metadata.Archive)); err != nil && !os.IsNotExist(err) {
			return err
		}
		if err := os.Remove(stale.path); err != nil {
			return err
		}
	}
	return nil
}
