package manager

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
)

type dockerLifecycle interface {
	Stop(container string) error
	Start(container string) error
}

type RestoreDataConfig struct {
	DataDir   string
	BackupDir string
	Container string
	Docker    dockerLifecycle
}

// RestoreData restores the most recent SQLite backup made by backup_db.sh.
// PocketBase is stopped before copying the database and its SQLite sidecars,
// since copying them while SQLite is connected risks corruption.
func RestoreData(config RestoreDataConfig) error {
	backupFile := filepath.Join(config.BackupDir, "data.db")
	if _, err := os.Stat(backupFile); err != nil {
		return fmt.Errorf("no backup present at %s: %w", backupFile, err)
	}
	if err := config.Docker.Stop(config.Container); err != nil {
		return fmt.Errorf("stop PocketBase before restore: %w", err)
	}

	restartOnError := true
	defer func() {
		if restartOnError {
			_ = config.Docker.Start(config.Container)
		}
	}()
	for _, suffix := range []string{"", "-wal", "-shm"} {
		if err := copyIfExists(backupFile+suffix, filepath.Join(config.DataDir, "data.db"+suffix)); err != nil {
			return fmt.Errorf("restore data.db%s: %w", suffix, err)
		}
	}
	restartOnError = false
	return config.Docker.Start(config.Container)
}

func copyIfExists(src, dst string) error {
	in, err := os.Open(src)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return err
	}
	defer in.Close()

	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer out.Close()
	_, err = io.Copy(out, in)
	return err
}
