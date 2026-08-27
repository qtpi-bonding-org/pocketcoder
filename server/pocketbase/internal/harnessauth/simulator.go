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

package harnessauth

import (
	"context"
	"encoding/base64"
	"errors"
	"fmt"
	"os"
	"regexp"
	"strings"
	"time"

	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/dockerapi"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/harnessvolume"
)

const (
	helperMountPath       = harnessvolume.AuthHomeMount
	helperCodeFile        = helperMountPath + "/pocketcoder_claude_auth_code.txt"
	helperContainerPrefix = "pocketcoder-auth-helper"
	helperLogTail         = 200

	selfContainerIDEnv       = "HOSTNAME"
	defaultSelfContainerName = "pocketcoder-pocketbase"
)

var (
	errMissingAttemptContext = errors.New("attempt context is incomplete")
	errMissingHarnessImage   = errors.New("attempt context missing harness image")

	urlRegex             = regexp.MustCompile(`(?i)https?://[^\s"'<>` + "`" + `]+`)
	ansiEscapeRegex      = regexp.MustCompile("\\x1b\\[[0-?]*[ -/]*[@-~]")
	codexCodeRegex       = regexp.MustCompile(`(?i:(?:code|device code|verification code))\s*[:=]?\s*([A-Z0-9]{4,}(?:-[A-Z0-9]{4,})*)`)
	codexDeviceCodeRegex = regexp.MustCompile(`\b([A-Z0-9]{4,}-[A-Z0-9]{4,})\b`)
	// Claude can emit several short forms; this is intentionally permissive.
	claudeCodeRegex = regexp.MustCompile(`(?i)(?:code|verification code|one-time code)\s*[:=]?\s*([A-Za-z0-9_-]{4,})`)
	expiryRegex     = regexp.MustCompile(`(?i)(?:for|in)\s+(\d+\s*(?:second|minute|hour|day|week)s?)`)
	successRegex    = regexp.MustCompile(`(?i)(logged in|login successful|authentication (?:succeeded|successful|complete)|auth(entication)? complete|session ready|connected)`)
	failureRegex    = regexp.MustCompile(`(?i)(error|failed|denied|invalid|expired|timeout|timed out|unable|unable to)`)
)

type commandAuthenticator struct {
	provider            string
	docker              *dockerapi.Client
	startCommandBuilder func(AttemptContext) string
	parseChallenge      func(string) *Challenge
	submitCode          func(context.Context, AttemptContext, string) error
}

func NewCodexAuthenticator() Authenticator {
	return &commandAuthenticator{
		provider:            ProviderCodex,
		docker:              dockerapi.New(),
		startCommandBuilder: buildCodexStartCommand,
		parseChallenge:      parseCodexChallenge,
	}
}

func NewClaudeAuthenticator() Authenticator {
	return &commandAuthenticator{
		provider:            ProviderClaude,
		docker:              dockerapi.New(),
		startCommandBuilder: buildClaudeStartCommand,
		parseChallenge:      parseClaudeChallenge,
		submitCode:          writeClaudeCode,
	}
}

func (c *commandAuthenticator) Provider() string {
	return c.provider
}

func (c *commandAuthenticator) Start(ctx context.Context, attempt AttemptContext) (*AttemptState, error) {
	if err := validateAttemptContext(attempt); err != nil {
		return nil, err
	}
	if err := c.ensureRunningHelper(ctx, attempt); err != nil {
		return nil, err
	}
	state, err := c.Poll(ctx, attempt)
	if err != nil {
		return nil, err
	}
	if state.Status == AttemptStatusStarting {
		state.Status = AttemptStatusAwaiting
	}
	return state, nil
}

func (c *commandAuthenticator) Poll(ctx context.Context, attempt AttemptContext) (*AttemptState, error) {
	if err := validateAttemptContext(attempt); err != nil {
		return nil, err
	}

	state := &AttemptState{Status: AttemptStatusStarting}
	logs, err := c.helperLogs(ctx, attempt)
	if err != nil && !errors.Is(err, dockerapi.ErrContainerNotFound) {
		return nil, err
	}
	state.Challenge = c.parseChallenge(logs)

	ins, err := c.docker.Inspect(ctx, helperContainerName(attempt.AttemptID))
	if errors.Is(err, dockerapi.ErrContainerNotFound) {
		state.Status = AttemptStatusFailed
		state.LastError = "helper container not found"
		return state, nil
	}
	if err != nil {
		return nil, err
	}

	if isAuthSuccess(logs) {
		state.Status = AttemptStatusSucceeded
		return state, nil
	}
	if ins.State.Running {
		if state.Challenge != nil {
			state.Status = AttemptStatusAwaiting
			return state, nil
		}
		state.Status = AttemptStatusStarting
		return state, nil
	}

	state.LastError = parseFailure(logs)
	if ins.State.ExitCode != 0 {
		state.Status = AttemptStatusFailed
		if state.LastError == "" {
			state.LastError = "authentication helper exited with error"
		}
		return state, nil
	}
	if state.Challenge != nil {
		state.Status = AttemptStatusFailed
		if state.LastError == "" {
			state.LastError = "authentication helper finished without completing challenge"
		}
		return state, nil
	}

	state.Status = AttemptStatusSucceeded
	return state, nil
}

func (c *commandAuthenticator) Submit(ctx context.Context, attempt AttemptContext, code string) (*AttemptState, error) {
	if err := validateAttemptContext(attempt); err != nil {
		return nil, err
	}
	code = strings.TrimSpace(code)
	if code == "" {
		return nil, fmt.Errorf("code is required")
	}
	if c.submitCode == nil {
		return nil, fmt.Errorf("provider %q does not accept interactive code submission", c.provider)
	}
	if err := c.submitCode(ctx, attempt, code); err != nil {
		return nil, err
	}
	return c.Poll(ctx, attempt)
}

func (c *commandAuthenticator) Cancel(ctx context.Context, attempt AttemptContext) (*AttemptState, error) {
	if err := validateAttemptContext(attempt); err != nil {
		return nil, err
	}
	if err := c.stopHelper(ctx, attempt.AttemptID); err != nil && !errors.Is(err, dockerapi.ErrContainerNotFound) {
		return nil, err
	}
	return &AttemptState{Status: AttemptStatusCancelled}, nil
}

func (c *commandAuthenticator) Disconnect(ctx context.Context, attempt AttemptContext) (*AttemptState, error) {
	return c.Cancel(ctx, attempt)
}

func validateAttemptContext(attempt AttemptContext) error {
	if attempt.AttemptID == "" || attempt.UserID == "" || attempt.AccountID == "" || attempt.HarnessCLI == "" {
		return errMissingAttemptContext
	}
	if attempt.HarnessImage == "" {
		return errMissingHarnessImage
	}
	return nil
}

func helperContainerName(attemptID string) string {
	return fmt.Sprintf("%s-%s", helperContainerPrefix, attemptID)
}

func helperSubmitContainerName(attemptID string) string {
	return fmt.Sprintf("%s-submit-%s-%d", helperContainerPrefix, attemptID, time.Now().UnixNano())
}

func (c *commandAuthenticator) ensureRunningHelper(ctx context.Context, attempt AttemptContext) error {
	name := helperContainerName(attempt.AttemptID)
	ins, err := c.docker.Inspect(ctx, name)
	if err == nil {
		if ins.State.Running {
			return nil
		}
		return c.docker.Start(ctx, name)
	}
	if !errors.Is(err, dockerapi.ErrContainerNotFound) {
		return err
	}

	authVolume, err := resolveAuthVolume(ctx, c.docker, attempt.UserID, attempt.HarnessCLI, attempt.AccountID)
	if err != nil {
		return err
	}

	_, err = c.docker.Create(ctx, name, dockerapi.CreateSpec{
		Image:      attempt.HarnessImage,
		Entrypoint: []string{"sh", "-lc"},
		Cmd:        []string{c.startCommandBuilder(attempt)},
		Env: []string{
			"HOME=" + helperMountPath,
			"XDG_CONFIG_HOME=" + helperMountPath + "/.config",
			"XDG_DATA_HOME=" + helperMountPath + "/.local/share",
			"NO_COLOR=1",
			"TERM=dumb",
		},
		VolumeBinds:   []string{authVolume + ":" + helperMountPath},
		RestartPolicy: "no",
		Labels: map[string]string{
			"pc_helper":           "true",
			"pc_helper_for":       attempt.AttemptID,
			"pc_oauth_account_id": attempt.AccountID,
		},
	})
	if err != nil {
		return err
	}
	return c.docker.Start(ctx, name)
}

func (c *commandAuthenticator) helperLogs(ctx context.Context, attempt AttemptContext) (string, error) {
	logs, err := c.docker.Logs(ctx, helperContainerName(attempt.AttemptID), helperLogTail)
	if err != nil {
		return "", err
	}
	return scrubLogText(logs), nil
}

func (c *commandAuthenticator) stopHelper(ctx context.Context, attemptID string) error {
	return c.docker.Stop(ctx, helperContainerName(attemptID), 2)
}

func buildCodexStartCommand(AttemptContext) string {
	return `mkdir -p "` + helperMountPath + `" && codex login --device-auth`
}

func buildClaudeStartCommand(AttemptContext) string {
	return `mkdir -p "` + helperMountPath + `" && ` +
		`code_file="` + helperCodeFile + `" && ` +
		`rm -f "$code_file" && ` +
		`(while :; do ` +
		`if [ -s "$code_file" ]; then ` +
		`cat "$code_file"; ` +
		`rm -f "$code_file"; ` +
		`break; ` +
		`fi; ` +
		`sleep 1; ` +
		`done) | claude auth login --claudeai`
}

func parseCodexChallenge(logs string) *Challenge {
	logs = scrubLogText(logs)
	if logs == "" {
		return nil
	}
	url := firstURL(logs)
	if url == "" {
		return nil
	}
	code := firstMatch(codexDeviceCodeRegex, logs)
	if code == "" {
		code = firstMatch(codexCodeRegex, logs)
	}
	text := "Open the authorization URL and enter the code shown."
	if code != "" {
		text = "Enter this code: " + code
	}
	return &Challenge{
		Type:    "device-code",
		Text:    text,
		Target:  url,
		Details: firstMatch(expiryRegex, logs),
	}
}

func parseClaudeChallenge(logs string) *Challenge {
	logs = scrubLogText(logs)
	if logs == "" {
		return nil
	}
	url := firstURL(logs)
	return &Challenge{
		Type:    "browser-code",
		Text:    "Open the authorization URL and submit the one-time code in the browser flow.",
		Target:  url,
		Details: firstMatch(expiryRegex, logs),
	}
}

func parseFailure(logs string) string {
	if logs == "" {
		return ""
	}
	for _, line := range strings.Split(logs, "\n") {
		l := strings.ToLower(strings.TrimSpace(line))
		if l == "" {
			continue
		}
		if failureRegex.MatchString(l) {
			return strings.TrimSpace(line)
		}
	}
	return ""
}

func isAuthSuccess(logs string) bool {
	return successRegex.MatchString(logs)
}

func firstMatch(re *regexp.Regexp, text string) string {
	match := re.FindStringSubmatch(text)
	if len(match) > 1 {
		return strings.TrimSpace(match[1])
	}
	if len(match) > 0 {
		return strings.TrimSpace(match[0])
	}
	return ""
}

func firstURL(text string) string {
	match := urlRegex.FindString(text)
	if match == "" {
		return ""
	}
	return strings.TrimRight(match, "\t\r\n\x20,:;.)\"")
}

func scrubLogText(logs string) string {
	logs = ansiEscapeRegex.ReplaceAllString(logs, "")
	lines := strings.Split(logs, "\n")
	for i, line := range lines {
		line = strings.TrimPrefix(line, "\x00")
		line = strings.TrimSpace(line)
		lines[i] = strings.TrimSuffix(strings.TrimPrefix(line, "\x01"), "\x02")
	}
	return strings.Join(lines, "\n")
}

func resolveAuthVolume(ctx context.Context, client *dockerapi.Client, userID, harnessCLI, accountID string) (string, error) {
	self := strings.TrimSpace(os.Getenv(selfContainerIDEnv))
	if self == "" {
		self = defaultSelfContainerName
	}
	insp, err := client.Inspect(ctx, self)
	if err != nil {
		return "", fmt.Errorf("inspect %q: %w", self, err)
	}
	workspaceVolume := ""
	for _, m := range insp.Mounts {
		if m.Destination == "/workspace" {
			workspaceVolume = m.Name
			break
		}
	}
	if workspaceVolume == "" {
		return "", fmt.Errorf("unable to resolve workspace volume for container %q", self)
	}

	volumes, err := harnessvolume.Resolve(workspaceVolume, userID, harnessCLI, accountID)
	if err != nil {
		return "", err
	}
	return volumes.Auth, nil
}

func writeClaudeCode(ctx context.Context, attempt AttemptContext, code string) error {
	if err := validateAttemptContext(attempt); err != nil {
		return err
	}

	volume, err := resolveAuthVolume(ctx, dockerapi.New(), attempt.UserID, attempt.HarnessCLI, attempt.AccountID)
	if err != nil {
		return err
	}

	payload := base64.StdEncoding.EncodeToString([]byte(code + "\n"))
	command := `mkdir -p "` + helperMountPath + `" && ` +
		`printf '%s' "$PC_AUTH_CODE_B64" | base64 -d > "` + helperCodeFile + `"`

	containerName := helperSubmitContainerName(attempt.AttemptID)
	client := dockerapi.New()
	_, err = client.Create(ctx, containerName, dockerapi.CreateSpec{
		Image:      attempt.HarnessImage,
		Entrypoint: []string{"sh", "-lc"},
		Cmd:        []string{command},
		Env:        []string{"PC_AUTH_CODE_B64=" + payload},
		VolumeBinds: []string{
			volume + ":" + helperMountPath,
		},
		RestartPolicy: "no",
	})
	if err != nil {
		return err
	}
	return client.Start(ctx, containerName)
}
