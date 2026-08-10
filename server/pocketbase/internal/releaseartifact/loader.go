// Package releaseartifact installs release-pinned Docker images from the
// immutable artifact manifest cached on a PocketCoder host.
package releaseartifact

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"golang.org/x/sys/unix"
)

const (
	defaultPointerPath  = "/var/lib/pocketcoder/release/current.json"
	defaultArtifactDir  = "/artifacts"
	defaultReserveBytes = int64(1 << 30)
)

var (
	releasePattern   = regexp.MustCompile(`^[0-9a-f]{40}$`)
	harnessIDPattern = regexp.MustCompile(`^[a-z0-9]+(?:-[a-z0-9]+)*$`)
	shaPattern       = regexp.MustCompile(`^[0-9a-f]{64}$`)
)

// DockerLoader is the narrow Docker API surface artifact installation needs.
type DockerLoader interface {
	ImageExists(ctx context.Context, image string) (bool, error)
	LoadImage(ctx context.Context, archive io.Reader) error
}

type Config struct {
	PointerPath     string
	ArtifactDir     string
	ExpectedRelease string
	ReserveBytes    int64
	DownloadTimeout time.Duration
	HTTPClient      *http.Client
	AvailableBytes  func(path string) (uint64, error)
}

type Loader struct {
	config  Config
	flights flightGroup
}

type releasePointer struct {
	SchemaVersion         int    `json:"schemaVersion"`
	ManifestSchemaVersion int    `json:"manifestSchemaVersion"`
	Release               string `json:"release"`
	ManifestURL           string `json:"manifestUrl"`
	ActivatedAt           string `json:"activatedAt"`
}

type artifact struct {
	URL           string   `json:"url"`
	SHA256        string   `json:"sha256"`
	Bytes         int64    `json:"bytes"`
	ExpandedBytes int64    `json:"expandedBytes"`
	Images        []string `json:"images"`
}

type releaseManifest struct {
	SchemaVersion int                 `json:"schemaVersion"`
	Release       string              `json:"release"`
	SourceURL     string              `json:"sourceUrl"`
	NixOSImage    artifact            `json:"nixosImage"`
	Deployment    artifact            `json:"deployment"`
	Core          artifact            `json:"core"`
	Harnesses     map[string]artifact `json:"harnesses"`
	Optional      struct {
		Ollama artifact `json:"ollama"`
	} `json:"optional"`
}

func New(config Config) *Loader {
	if config.PointerPath == "" {
		config.PointerPath = defaultPointerPath
	}
	if config.ArtifactDir == "" {
		config.ArtifactDir = defaultArtifactDir
	}
	if config.ReserveBytes <= 0 {
		config.ReserveBytes = defaultReserveBytes
	}
	if config.DownloadTimeout <= 0 {
		config.DownloadTimeout = 30 * time.Minute
	}
	if config.HTTPClient == nil {
		config.HTTPClient = &http.Client{Transport: &http.Transport{
			Proxy:                 http.ProxyFromEnvironment,
			ResponseHeaderTimeout: 30 * time.Second,
		}}
	}
	if config.AvailableBytes == nil {
		config.AvailableBytes = filesystemAvailableBytes
	}
	return &Loader{config: config}
}

func ConfigFromEnvironment() Config {
	reserve := defaultReserveBytes
	if raw := os.Getenv("POCKETCODER_DISK_RESERVE_BYTES"); raw != "" {
		if parsed, err := strconv.ParseInt(raw, 10, 64); err == nil && parsed > 0 {
			reserve = parsed
		}
	}
	return Config{
		PointerPath:     os.Getenv("POCKETCODER_RELEASE_POINTER"),
		ArtifactDir:     os.Getenv("POCKETCODER_ARTIFACT_DIR"),
		ExpectedRelease: os.Getenv("POCKETCODER_RELEASE"),
		ReserveBytes:    reserve,
	}
}

var (
	defaultOnce   sync.Once
	defaultLoader *Loader
)

func EnsureHarnessImage(ctx context.Context, docker DockerLoader, harnessID, image string) error {
	defaultOnce.Do(func() { defaultLoader = New(ConfigFromEnvironment()) })
	return defaultLoader.EnsureHarnessImage(ctx, docker, harnessID, image)
}

func (l *Loader) EnsureHarnessImage(ctx context.Context, docker DockerLoader, harnessID, image string) error {
	if !harnessIDPattern.MatchString(harnessID) {
		return fmt.Errorf("invalid harness artifact ID %q", harnessID)
	}
	if !releasePattern.MatchString(l.config.ExpectedRelease) {
		return fmt.Errorf("invalid active release identity %q", l.config.ExpectedRelease)
	}
	if !strings.HasPrefix(image, "pocketcoder-harness-") ||
		!ManagedReleaseImage(image, l.config.ExpectedRelease) {
		return fmt.Errorf("image %q does not belong to active release", image)
	}
	flightKey := l.config.ExpectedRelease + ":" + harnessID + ":" + image
	return l.flights.Do(ctx, flightKey, func() error {
		local, err := docker.ImageExists(ctx, image)
		if err != nil {
			return fmt.Errorf("inspect release image %s: %w", image, err)
		}
		if local {
			return nil
		}
		return l.install(ctx, docker, harnessID, image)
	})
}

func (l *Loader) install(ctx context.Context, docker DockerLoader, harnessID, image string) error {
	pointer, manifest, err := l.loadReleaseState()
	if err != nil {
		return err
	}
	if pointer.Release != l.config.ExpectedRelease || manifest.Release != l.config.ExpectedRelease {
		return fmt.Errorf("release state does not match active release %s", l.config.ExpectedRelease)
	}
	selected, ok := manifest.Harnesses[harnessID]
	if !ok {
		return fmt.Errorf("release %s has no artifact for harness %s", manifest.Release, harnessID)
	}
	if err := validateHarnessArtifact(selected, image); err != nil {
		return fmt.Errorf("invalid %s harness artifact: %w", harnessID, err)
	}

	if err := os.MkdirAll(l.config.ArtifactDir, 0o700); err != nil {
		return fmt.Errorf("create artifact directory: %w", err)
	}
	available, err := l.config.AvailableBytes(l.config.ArtifactDir)
	if err != nil {
		return fmt.Errorf("measure artifact disk space: %w", err)
	}
	required := uint64(selected.Bytes) + uint64(selected.ExpandedBytes) + uint64(l.config.ReserveBytes)
	if available < required {
		return fmt.Errorf("insufficient disk space for harness %s artifact", harnessID)
	}
	temp, err := os.CreateTemp(l.config.ArtifactDir, "."+manifest.Release+"-"+harnessID+"-*.part")
	if err != nil {
		return fmt.Errorf("create artifact staging file: %w", err)
	}
	tempPath := temp.Name()
	defer os.Remove(tempPath)
	defer temp.Close()
	if err := temp.Chmod(0o600); err != nil {
		return fmt.Errorf("protect artifact staging file: %w", err)
	}

	operationCtx, cancel := context.WithTimeout(ctx, l.config.DownloadTimeout)
	defer cancel()
	req, err := http.NewRequestWithContext(operationCtx, http.MethodGet, selected.URL, nil)
	if err != nil {
		return fmt.Errorf("create harness artifact request: %w", err)
	}
	configuredRedirect := l.config.HTTPClient.CheckRedirect
	downloadClient := &http.Client{
		Transport: l.config.HTTPClient.Transport,
		Jar:       l.config.HTTPClient.Jar,
		Timeout:   l.config.HTTPClient.Timeout,
	}
	downloadClient.CheckRedirect = func(req *http.Request, via []*http.Request) error {
		if req.URL.Scheme != "https" {
			return errors.New("artifact redirect must use HTTPS")
		}
		if configuredRedirect != nil {
			return configuredRedirect(req, via)
		}
		if len(via) >= 10 {
			return errors.New("too many artifact redirects")
		}
		return nil
	}
	resp, err := downloadClient.Do(req)
	if err != nil {
		return fmt.Errorf("download harness %s artifact: %w", harnessID, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("download harness %s artifact: server returned %s", harnessID, resp.Status)
	}
	if resp.Request.URL.Scheme != "https" {
		return fmt.Errorf("download harness %s artifact redirected outside HTTPS", harnessID)
	}
	if resp.ContentLength >= 0 && resp.ContentLength != selected.Bytes {
		return fmt.Errorf("harness %s artifact size header mismatch", harnessID)
	}

	hasher := sha256.New()
	written, err := io.Copy(io.MultiWriter(temp, hasher), io.LimitReader(resp.Body, selected.Bytes+1))
	if err != nil {
		return fmt.Errorf("download harness %s artifact body: %w", harnessID, err)
	}
	if written != selected.Bytes {
		return fmt.Errorf("harness %s artifact size mismatch", harnessID)
	}
	if actual := hex.EncodeToString(hasher.Sum(nil)); actual != selected.SHA256 {
		return fmt.Errorf("harness %s artifact checksum mismatch", harnessID)
	}
	if err := temp.Sync(); err != nil {
		return fmt.Errorf("sync harness artifact: %w", err)
	}
	if _, err := temp.Seek(0, io.SeekStart); err != nil {
		return fmt.Errorf("rewind harness artifact: %w", err)
	}
	if err := docker.LoadImage(operationCtx, temp); err != nil {
		return fmt.Errorf("load harness %s artifact: %w", harnessID, err)
	}
	local, err := docker.ImageExists(operationCtx, image)
	if err != nil {
		return fmt.Errorf("verify loaded harness image %s: %w", image, err)
	}
	if !local {
		return fmt.Errorf("harness artifact did not contain expected image %s", image)
	}
	return nil
}

func (l *Loader) loadReleaseState() (releasePointer, releaseManifest, error) {
	var pointer releasePointer
	if err := decodeStrictFile(l.config.PointerPath, &pointer); err != nil {
		return pointer, releaseManifest{}, fmt.Errorf("read release pointer: %w", err)
	}
	if pointer.SchemaVersion != 1 || pointer.ManifestSchemaVersion != 2 || !releasePattern.MatchString(pointer.Release) {
		return pointer, releaseManifest{}, errors.New("invalid release pointer")
	}
	manifestURL, err := url.Parse(pointer.ManifestURL)
	if err != nil || manifestURL.Scheme != "https" || manifestURL.Host == "" {
		return pointer, releaseManifest{}, errors.New("invalid immutable manifest URL")
	}
	if !strings.HasSuffix(manifestURL.Path, "/release-"+pointer.Release+".json") {
		return pointer, releaseManifest{}, errors.New("immutable manifest URL does not match release pointer")
	}
	manifestPath := filepath.Join(filepath.Dir(l.config.PointerPath), "manifests", pointer.Release+".json")
	var manifest releaseManifest
	if err := decodeStrictFile(manifestPath, &manifest); err != nil {
		return pointer, manifest, fmt.Errorf("read cached release manifest: %w", err)
	}
	if manifest.SchemaVersion != 2 || !releasePattern.MatchString(manifest.Release) || manifest.Release != pointer.Release {
		return pointer, manifest, errors.New("cached manifest identity does not match release pointer")
	}
	return pointer, manifest, nil
}

func validateHarnessArtifact(candidate artifact, image string) error {
	parsed, err := url.Parse(candidate.URL)
	if err != nil || parsed.Scheme != "https" || parsed.Host == "" {
		return errors.New("artifact URL must use HTTPS")
	}
	if !shaPattern.MatchString(candidate.SHA256) {
		return errors.New("artifact checksum is invalid")
	}
	if candidate.Bytes <= 0 || candidate.ExpandedBytes < candidate.Bytes {
		return errors.New("artifact sizes are invalid")
	}
	if len(candidate.Images) != 1 || candidate.Images[0] != image {
		return errors.New("artifact image identity does not match requested image")
	}
	return nil
}

func decodeStrictFile(path string, target any) error {
	file, err := os.Open(path)
	if err != nil {
		return err
	}
	defer file.Close()
	decoder := json.NewDecoder(file)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		return err
	}
	if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		return errors.New("trailing JSON value")
	}
	return nil
}

func filesystemAvailableBytes(path string) (uint64, error) {
	var stats unix.Statfs_t
	if err := unix.Statfs(path, &stats); err != nil {
		return 0, err
	}
	return uint64(stats.Bavail) * uint64(stats.Bsize), nil
}

type flight struct {
	done chan struct{}
	err  error
}

type flightGroup struct {
	mu      sync.Mutex
	flights map[string]*flight
}

func (g *flightGroup) Do(ctx context.Context, key string, work func() error) error {
	g.mu.Lock()
	if g.flights == nil {
		g.flights = make(map[string]*flight)
	}
	if active := g.flights[key]; active != nil {
		g.mu.Unlock()
		select {
		case <-active.done:
			return active.err
		case <-ctx.Done():
			return ctx.Err()
		}
	}
	active := &flight{done: make(chan struct{})}
	g.flights[key] = active
	g.mu.Unlock()

	active.err = work()
	g.mu.Lock()
	delete(g.flights, key)
	close(active.done)
	g.mu.Unlock()
	return active.err
}

// ManagedReleaseImage reports whether image belongs to the active immutable
// PocketCoder release and therefore must come from its verified artifact.
func ManagedReleaseImage(image, release string) bool {
	return releasePattern.MatchString(release) && strings.HasSuffix(image, ":"+release)
}
