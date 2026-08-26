/*
PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
Copyright (C) 2026 Qtpi Bonding LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

// @pocketcoder-core: Docker Engine API client for harness provisioning,
// talking only to docker-socket-proxy-write — never the raw socket. Follows
// the same fixed-dial-to-proxy pattern as hooks/docker.go's
// restartContainer, extended to the handful of extra calls provisioning
// needs (inspect, pull, create, start, events).
package dockerapi

import (
	"bufio"
	"bytes"
	"context"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"
)

const defaultDockerHost = "tcp://docker-socket-proxy-write:2375"

var ErrContainerNotFound = errors.New("container not found")

type Client struct {
	baseURL string
	http    *http.Client
}

func New() *Client {
	host := os.Getenv("DOCKER_HOST")
	if host == "" {
		host = defaultDockerHost
	}
	proxyAddr := strings.TrimPrefix(host, "tcp://")
	return &Client{
		baseURL: "http://" + proxyAddr,
		http: &http.Client{
			Transport: &http.Transport{
				DialContext: func(ctx context.Context, network, addr string) (net.Conn, error) {
					return net.Dial("tcp", proxyAddr)
				},
			},
			Timeout: 30 * time.Second,
		},
	}
}

type Mount struct {
	Destination, Name string
}

type NetworkEndpoint struct{}

type ContainerInspect struct {
	Mounts []Mount
	Config struct {
		Image  string
		Labels map[string]string
	}
	NetworkSettings struct {
		Networks map[string]NetworkEndpoint
	}
	State struct {
		Running  bool
		Status   string
		ExitCode int `json:"ExitCode"`
	}
}

func (c *Client) Inspect(ctx context.Context, containerName string) (ContainerInspect, error) {
	var insp ContainerInspect
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/containers/"+containerName+"/json", nil)
	if err != nil {
		return insp, err
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return insp, fmt.Errorf("inspect %s: %w", containerName, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusNotFound {
		return insp, ErrContainerNotFound
	}
	if resp.StatusCode >= 400 {
		return insp, fmt.Errorf("inspect %s: docker API returned %s", containerName, resp.Status)
	}
	if err := json.NewDecoder(resp.Body).Decode(&insp); err != nil {
		return insp, fmt.Errorf("decode inspect response: %w", err)
	}
	return insp, nil
}

func (c *Client) Logs(ctx context.Context, containerName string, tail int) (string, error) {
	q := url.Values{
		"stdout":     []string{"1"},
		"stderr":     []string{"1"},
		"follow":     []string{"0"},
		"timestamps": []string{"0"},
	}
	if tail > 0 {
		q.Set("tail", strconv.Itoa(tail))
	} else {
		q.Set("tail", "100")
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/containers/"+containerName+"/logs?"+q.Encode(), nil)
	if err != nil {
		return "", err
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return "", fmt.Errorf("logs %s: %w", containerName, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusNotFound {
		return "", ErrContainerNotFound
	}
	if resp.StatusCode >= 400 {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("logs %s: docker API returned %s: %s", containerName, resp.Status, string(body))
	}
	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}
	if len(raw) == 0 {
		return "", nil
	}
	decoded, err := decodeDockerLogStream(raw)
	if err != nil {
		return "", err
	}
	return decoded, nil
}

// StreamLogs opens a live Docker log stream without buffering it. The normal
// client timeout is unsuitable for follow=1; cancellation is controlled by
// the caller's context instead.
func (c *Client) StreamLogs(ctx context.Context, containerName string, tail int) (io.ReadCloser, error) {
	q := url.Values{"stdout": {"1"}, "stderr": {"1"}, "follow": {"1"}, "timestamps": {"0"}}
	if tail > 0 {
		q.Set("tail", strconv.Itoa(tail))
	} else {
		q.Set("tail", "100")
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/containers/"+containerName+"/logs?"+q.Encode(), nil)
	if err != nil {
		return nil, err
	}
	streamClient := &http.Client{Transport: c.http.Transport, CheckRedirect: c.http.CheckRedirect, Jar: c.http.Jar}
	resp, err := streamClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("stream logs %s: %w", containerName, err)
	}
	if resp.StatusCode == http.StatusNotFound {
		resp.Body.Close()
		return nil, ErrContainerNotFound
	}
	if resp.StatusCode >= 400 {
		body, _ := io.ReadAll(resp.Body)
		resp.Body.Close()
		return nil, fmt.Errorf("stream logs %s: docker API returned %s: %s", containerName, resp.Status, string(body))
	}
	return resp.Body, nil
}

func decodeDockerLogStream(raw []byte) (string, error) {
	const frameHeaderLen = 8
	if len(raw) < frameHeaderLen {
		return string(raw), nil
	}
	if raw[0] == 0 && raw[1] == 0 && raw[2] == 0 && raw[3] == 0 {
		var out bytes.Buffer
		r := bytes.NewReader(raw)
		for {
			header := make([]byte, frameHeaderLen)
			if _, err := io.ReadFull(r, header); err != nil {
				if err == io.EOF || err == io.ErrUnexpectedEOF {
					break
				}
				return "", err
			}
			size := int(binary.BigEndian.Uint32(header[4:8]))
			if size == 0 {
				continue
			}
			payload := make([]byte, size)
			if _, err := io.ReadFull(r, payload); err != nil {
				if err == io.ErrUnexpectedEOF || err == io.EOF {
					break
				}
				return "", err
			}
			out.Write(payload)
		}
		return out.String(), nil
	}
	return string(raw), nil
}

func (c *Client) PullImage(ctx context.Context, image string) error {
	q := url.Values{"fromImage": {image}}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/images/create?"+q.Encode(), nil)
	if err != nil {
		return err
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return fmt.Errorf("pull image %s: %w", image, err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 400 {
		return fmt.Errorf("pull image %s: docker API returned %s: %s", image, resp.Status, string(body))
	}
	return nil
}

// LoadImage streams a compressed docker-save archive into Docker. The normal
// API client has a short timeout for control operations; image loading is
// bounded by the caller's context instead because large archives can take
// several minutes to import.
func (c *Client) LoadImage(ctx context.Context, archive io.Reader) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/images/load?quiet=1", archive)
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/x-tar")
	streamClient := &http.Client{
		Transport:     c.http.Transport,
		CheckRedirect: c.http.CheckRedirect,
		Jar:           c.http.Jar,
	}
	resp, err := streamClient.Do(req)
	if err != nil {
		return fmt.Errorf("load image archive: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("load image archive: docker API returned %s: %s", resp.Status, string(body))
	}
	decoder := json.NewDecoder(resp.Body)
	for {
		var message struct {
			Error       string `json:"error"`
			ErrorDetail struct {
				Message string `json:"message"`
			} `json:"errorDetail"`
		}
		if err := decoder.Decode(&message); err != nil {
			if errors.Is(err, io.EOF) {
				return nil
			}
			return fmt.Errorf("decode docker image load response: %w", err)
		}
		if message.ErrorDetail.Message != "" {
			return fmt.Errorf("docker image load failed: %s", message.ErrorDetail.Message)
		}
		if message.Error != "" {
			return fmt.Errorf("docker image load failed: %s", message.Error)
		}
	}
}

// ImageExists reports whether image is already present in the local Docker
// image store. First-party harness images are loaded from verified release
// artifacts, so pulling their commit tags from a registry would be both
// unnecessary and guaranteed to fail: PocketCoder does not publish those
// local image tags to a registry.
func (c *Client) ImageExists(ctx context.Context, image string) (bool, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/images/"+url.PathEscape(image)+"/json", nil)
	if err != nil {
		return false, err
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return false, fmt.Errorf("inspect image %s: %w", image, err)
	}
	defer resp.Body.Close()
	switch {
	case resp.StatusCode == http.StatusNotFound:
		return false, nil
	case resp.StatusCode >= 400:
		body, _ := io.ReadAll(resp.Body)
		return false, fmt.Errorf("inspect image %s: docker API returned %s: %s", image, resp.Status, string(body))
	default:
		return true, nil
	}
}

type CreateSpec struct {
	Image                  string
	Entrypoint             []string
	Cmd                    []string
	Env                    []string
	VolumeName, VolumeDest string
	VolumeBinds            []string
	Labels                 map[string]string
	NetworkNames           []string
	NetworkAliases         map[string][]string
	RestartPolicy          string
}

func (c *Client) Create(ctx context.Context, name string, spec CreateSpec) (string, error) {
	endpoints := make(map[string]any, len(spec.NetworkNames))
	for _, networkName := range spec.NetworkNames {
		endpoint := map[string]any{}
		if aliases := spec.NetworkAliases[networkName]; len(aliases) > 0 {
			endpoint["Aliases"] = aliases
		}
		endpoints[networkName] = endpoint
	}
	binds := spec.VolumeBinds
	if len(binds) == 0 && spec.VolumeName != "" {
		b := spec.VolumeName + ":" + spec.VolumeDest
		if spec.VolumeDest != "" {
			b = spec.VolumeName + ":" + spec.VolumeDest
		}
		binds = []string{b}
	}
	restartPolicy := spec.RestartPolicy
	if restartPolicy == "" {
		restartPolicy = "unless-stopped"
	}
	hostConfig := map[string]any{
		"Binds":         binds,
		"RestartPolicy": map[string]any{"Name": restartPolicy},
	}
	payload := map[string]any{
		"Image":      spec.Image,
		"Entrypoint": spec.Entrypoint,
		"Cmd":        spec.Cmd,
		"Env":        spec.Env,
		"HostConfig": hostConfig,
		"NetworkingConfig": map[string]any{
			"EndpointsConfig": endpoints,
		},
	}
	if len(spec.Labels) > 0 {
		// Container labels are part of Docker's Config object, not HostConfig.
		// Keeping them at the top level is what makes pc_managed/pc_release
		// visible to the host updater's narrowly scoped container filters.
		payload["Labels"] = spec.Labels
	}
	buf, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/containers/create?name="+url.QueryEscape(name), bytes.NewReader(buf))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := c.http.Do(req)
	if err != nil {
		return "", fmt.Errorf("create container %s: %w", name, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("create container %s: docker API returned %s: %s", name, resp.Status, string(body))
	}
	var out struct{ Id string }
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return "", fmt.Errorf("decode create response: %w", err)
	}
	return out.Id, nil
}

// CopyArchive writes a tar archive into a running container using Docker's
// archive API. This deliberately avoids exec: PocketBase can materialize
// managed files without gaining a shell in user harnesses.
func (c *Client) CopyArchive(ctx context.Context, containerName, destination string, archive io.Reader) error {
	q := url.Values{"path": []string{destination}}
	req, err := http.NewRequestWithContext(ctx, http.MethodPut, c.baseURL+"/containers/"+containerName+"/archive?"+q.Encode(), archive)
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/x-tar")
	resp, err := c.http.Do(req)
	if err != nil {
		return fmt.Errorf("copy archive to %s: %w", containerName, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusNotFound {
		return ErrContainerNotFound
	}
	if resp.StatusCode >= 400 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("copy archive to %s: docker API returned %s: %s", containerName, resp.Status, string(body))
	}
	return nil
}

func (c *Client) Start(ctx context.Context, containerName string) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/containers/"+containerName+"/start", nil)
	if err != nil {
		return err
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return fmt.Errorf("start container %s: %w", containerName, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("start container %s: docker API returned %s: %s", containerName, resp.Status, string(body))
	}
	return nil
}

func (c *Client) Stop(ctx context.Context, containerName string, timeout int) error {
	q := url.Values{}
	if timeout > 0 {
		q.Set("t", strconv.Itoa(timeout))
	}
	path := "/containers/" + containerName + "/stop"
	if encoded := q.Encode(); encoded != "" {
		path += "?" + encoded
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+path, nil)
	if err != nil {
		return err
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return fmt.Errorf("stop container %s: %w", containerName, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusNotFound {
		return ErrContainerNotFound
	}
	if resp.StatusCode >= 400 && resp.StatusCode != http.StatusNotModified {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("stop container %s: docker API returned %s: %s", containerName, resp.Status, string(body))
	}
	return nil
}

type Event struct {
	Type, Action, ContainerName string
}

func (c *Client) Events(ctx context.Context) (<-chan Event, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/events", nil)
	if err != nil {
		return nil, err
	}
	// Long-lived streaming GET — no client-side timeout for this one call.
	streamClient := &http.Client{Transport: c.http.Transport}
	resp, err := streamClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("subscribe to docker events: %w", err)
	}
	ch := make(chan Event)
	go func() {
		defer resp.Body.Close()
		defer close(ch)
		scanner := bufio.NewScanner(resp.Body)
		for scanner.Scan() {
			var raw struct {
				Type   string
				Action string
				Actor  struct {
					Attributes map[string]string
				}
			}
			if err := json.Unmarshal(scanner.Bytes(), &raw); err != nil {
				log.Printf("dockerapi: failed to unmarshal event: %v", err)
				continue
			}
			select {
			case ch <- Event{Type: raw.Type, Action: raw.Action, ContainerName: raw.Actor.Attributes["name"]}:
			case <-ctx.Done():
				return
			}
		}
		if err := scanner.Err(); err != nil {
			log.Printf("dockerapi: events stream ended: %v", err)
		}
	}()
	return ch, nil
}

type ContainerSummary struct {
	ID     string   `json:"Id"`
	Names  []string `json:"Names"`
	Image  string   `json:"Image"`
	State  string   `json:"State"`
	Status string   `json:"Status"`
}

func (c *Client) ListContainers(ctx context.Context) ([]ContainerSummary, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/containers/json?all=1", nil)
	if err != nil {
		return nil, err
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("list containers: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("list containers: docker API returned %s: %s", resp.Status, string(body))
	}
	var out []ContainerSummary
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, fmt.Errorf("decode list response: %w", err)
	}
	return out, nil
}

// ListAll is retained for callers that use the older name for the same
// Docker API operation.
func (c *Client) ListAll(ctx context.Context) ([]ContainerSummary, error) {
	return c.ListContainers(ctx)
}

// Remove deletes a managed container after it has stopped. The socket proxy
// permits this narrow lifecycle operation for PocketCoder-owned containers.
func (c *Client) Remove(ctx context.Context, containerName string) error {
	q := url.Values{"force": {"1"}}
	req, err := http.NewRequestWithContext(ctx, http.MethodDelete, c.baseURL+"/containers/"+url.PathEscape(containerName)+"?"+q.Encode(), nil)
	if err != nil {
		return err
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return fmt.Errorf("remove %s: %w", containerName, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusNotFound {
		return ErrContainerNotFound
	}
	if resp.StatusCode >= 400 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("remove %s: docker API returned %s: %s", containerName, resp.Status, string(body))
	}
	return nil
}
