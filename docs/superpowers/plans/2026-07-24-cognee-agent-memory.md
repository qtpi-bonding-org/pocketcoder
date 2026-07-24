# cognee Agent Memory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire cognee (an embedded FOSS MCP memory server) into the current Goose/ACP architecture as its own container, registered as a live Goose extension, with PocketBase-admin-configurable LLM settings and an SQLPage dashboard view.

**Architecture:** `cognee` runs as a new standalone `docker-compose` service on a dedicated `pocketcoder-cognee` network shared only with `goose`. PocketBase live-registers it as a `"cognee"` Goose extension over ACP (mirroring the existing gateway-registration hook), and separately renders its LLM settings from a new `cognee_config` collection into an env file the container reads (mirroring the existing goose-config render+restart hook). No prompt-injection code — cognee's tools are just more tools in Goose's normal agentic loop.

**Tech Stack:** Go (PocketBase backend, `github.com/pocketbase/pocketbase` v0.36.1), Docker Compose, cognee-mcp (Python, upstream image), SQL (SQLite via SQLPage).

## Global Constraints

- Follow root `CLAUDE.md`'s PocketBase schema convention: edit `services/pocketbase/pb_migrations/schema.json` directly — do NOT add a new timestamped migration file.
- PocketBase always owns its own primary key (`id`) — any external id (none needed here; `cognee_config` has no external system to track) stays a plain field, not the PK. Not applicable to this plan's one new collection, noted for completeness per `CLAUDE.md`.
- No manual recall/prompt-injection code (spec §3.3, user-approved) — cognee is wired as a pure MCP tool, nothing else touches the coordinator/run path.
- `cognee_config`'s access rule is superuser-only (`createRule`/`updateRule`/`deleteRule` all `null`), matching `poco_configs` — NOT the `@request.auth.role = 'admin'` pattern `mcp_servers`/`provider_keys` use. This was a specific correction from the spec's adversarial review; do not "fix" it back to an admin-role rule.
- cognee's LLM credentials are self-contained (`cognee_config.llm_api_key`) — never read `provider_keys` or `ANTHROPIC_API_KEY` for cognee. `provider_keys` is per-user; cognee is a single global background service with no user context.

---

## Task 1: Spike — confirm cognee-mcp is reachable cross-container over HTTP/SSE

This gates every later task that assumes `http://cognee:<port>/mcp` is dialable from the `goose` container. Do not skip or assume the answer.

**Files:**
- Create (scratch, not committed): a throwaway local Docker Compose snippet or two ad-hoc `docker run` commands — nothing under version control.
- Record: `docs/superpowers/plans/2026-07-24-cognee-transport-decision.md`

- [ ] **Step 1: Run cognee-mcp locally in HTTP mode**

```bash
docker network create cognee-spike-net
docker run -d --name cognee-spike --network cognee-spike-net \
  -e LLM_API_KEY=sk-test-placeholder \
  cognee/cognee-mcp:main --transport http --port 8000
docker logs -f cognee-spike   # watch for the actual bind host/port and any startup error
```

If `cognee/cognee-mcp:main` doesn't exist or fails to pull, check cognee's GitHub Container Registry / PyPI page for the current published image tag and substitute it — record whatever tag you actually used in the decision file (Step 4).

- [ ] **Step 2: Try to reach it from a second container on the same network**

```bash
docker run --rm --network cognee-spike-net curlimages/curl:latest \
  curl -sv -X POST http://cognee-spike:8000/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
```

- [ ] **Step 3: Diagnose based on the result**

- **2xx / a JSON-RPC response body** (even an error response, as long as it's not a connection-level rejection) → HTTP transport works cross-container as-is. Record `TRANSPORT=http`, note the port.
- **Connection refused / reset** → check `docker logs cognee-spike` for a bind-address issue (e.g. bound to `127.0.0.1` inside its own container instead of `0.0.0.0`) — look for a `--host 0.0.0.0` or equivalent flag/env var in `docker run cognee-spike --help` or `cognee-mcp --help` and retry Step 1 with it.
- **403 / "Invalid Host header" / "Invalid Origin"** → this is the DNS-rebinding-protection allowlist flagged in the spec (§3.1). Look for an allowlist-widening flag/env var (search `cognee-mcp --help` output and cognee's GitHub repo for terms like `allowed-hosts`, `trusted-hosts`, `CORS`, `DANGEROUSLY_OMIT_AUTH`, or similar) and retry with it set. If no such override exists, fall back to `--transport sse` and repeat Steps 1-2 with an SSE-appropriate request, or note that a stdio-only path is required.

- [ ] **Step 4: Write the decision file**

Create `docs/superpowers/plans/2026-07-24-cognee-transport-decision.md` with exactly this shape (fill in the bracketed values from what you actually found):

```markdown
# cognee Transport Decision

- TRANSPORT: [http | sse | stdio]
- PORT: [port number, if http/sse]
- FLAGS_REQUIRED: [any --flag or env var needed to make it reachable cross-container, or "none"]
- IMAGE_TAG_USED_FOR_SPIKE: [the exact image:tag that worked]
```

Task 3 (docker-compose service) and Task 6 (extension registration) both read this file — do not proceed to those tasks until it exists and TRANSPORT is filled in.

- [ ] **Step 5: Clean up the spike containers**

```bash
docker rm -f cognee-spike
docker network rm cognee-spike-net
```

- [ ] **Step 6: Commit the decision record**

```bash
git add docs/superpowers/plans/2026-07-24-cognee-transport-decision.md
git commit -m "docs: record cognee-mcp transport spike findings"
```

## Task 2: Spike — confirm a viable (non-~27GB) cognee-mcp image

**Files:**
- Record: `docs/superpowers/plans/2026-07-24-cognee-image-decision.md`

- [ ] **Step 1: Check the pulled image's actual size**

```bash
docker images cognee/cognee-mcp --format "{{.Repository}}:{{.Tag}}  {{.Size}}"
```

(If Task 1 used a different image/tag, check that one instead — keep this consistent with the transport decision file.)

- [ ] **Step 2: If it's large (multiple GB, CUDA/torch-heavy), look for a slim/CPU-only tag**

```bash
docker images cognee/cognee-mcp
# also check cognee's Docker Hub / GHCR tag list and its Dockerfile in the
# upstream repo (github.com/topoteretes/cognee) for a CPU-only build arg or
# a separate slim tag
```

- [ ] **Step 3: If no slim tag exists, scope a trimmed custom Dockerfile**

Sketch (don't fully build yet — just confirm feasibility) a `services/cognee/Dockerfile` starting `FROM python:3.12-slim`, installing `cognee[mcp]` via `pip`/`uv` with CPU-only extras excluded, and confirm cognee's local embedding model choice (§3.4 of the spec — local, no API key) doesn't itself pull in a large model download at image-build time that would defeat the purpose. If cognee's local-embedding default is large, note the specific model it uses and whether a smaller local model can be substituted via its config.

- [ ] **Step 4: Write the decision file**

```markdown
# cognee Image Decision

- IMAGE: [image:tag to use in docker-compose.yml, e.g. "cognee/cognee-mcp:main-cpu" or "build: services/cognee"]
- APPROX_SIZE: [size found]
- CUSTOM_DOCKERFILE_NEEDED: [yes | no]
- NOTES: [anything relevant to the size/build tradeoff]
```

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/plans/2026-07-24-cognee-image-decision.md
git commit -m "docs: record cognee-mcp image-size spike findings"
```

## Task 3: docker-compose.yml — add the cognee service

**Files:**
- Modify: `docker-compose.yml`

**Interfaces:**
- Consumes: `TRANSPORT`/`PORT`/`FLAGS_REQUIRED` from Task 1's decision file, `IMAGE`/`CUSTOM_DOCKERFILE_NEEDED` from Task 2's decision file.
- Produces: a `cognee` service reachable at `http://cognee:<PORT>` (or the transport Task 1 settled on) from the `goose` container over `pocketcoder-cognee`; a `cognee_data` volume containing cognee's SQLite/LanceDB/Kuzu files; a `cognee_config` volume that Task 5's hook writes `cognee.env` into and this service reads env vars from.

- [ ] **Step 1: Add the `cognee` service block**

Insert after the `mcp-gateway` service block (after line 120, before the `docker-socket-proxy-write` comment) in `docker-compose.yml`. Use the image from Task 2's decision file; if `CUSTOM_DOCKERFILE_NEEDED: yes`, use a `build:` block instead of `image:` (pattern: copy the `mcp-gateway` service's `build: { context: ., dockerfile: services/cognee/Dockerfile }` shape). Substitute `<PORT>` and any `<FLAGS_REQUIRED>` from Task 1's decision file into the `command:`:

```yaml
  # 🧠 COGNEE (Agent Memory MCP Server)
  # Standalone MCP memory server for Goose — knowledge-graph + vector recall,
  # embedded storage (SQLite + LanceDB), no external DB services. Registered
  # as a live Goose extension by hooks.RegisterCogneeExtension (Task 6), not
  # via the mcp_servers/Docker-MCP-gateway catalog path.
  cognee:
    image: <IMAGE from Task 2 decision file>
    container_name: pocketcoder-cognee
    profiles: ["agent"]
    command: ["--transport", "<TRANSPORT from Task 1 decision file>", "--port", "<PORT from Task 1 decision file>"]
    environment:
      - LLM_API_KEY=${COGNEE_LLM_API_KEY:-}
    volumes:
      - cognee_data:/cognee_data
      - cognee_config:/cognee-config
    networks:
      - pocketcoder-cognee
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:<PORT>/health"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 15s
```

If Task 1 found no flags were needed, drop them from `command:`. If Task 1 found `TRANSPORT: stdio` (HTTP/SSE unreachable cross-container), stop here and flag this to a human — the registration approach in Task 6 assumes network reachability; a stdio-only result invalidates this task's shape and needs a design revisit, not a silent substitution.

- [ ] **Step 2: Add `cognee` to `goose`'s `networks:` list**

In the `goose` service block (`docker-compose.yml:81-84`), add the new network:

```yaml
    networks:
      - pocketcoder-agent
      - pocketcoder-goose-egress
      - pocketcoder-mcp-gateway
      - pocketcoder-cognee
```

- [ ] **Step 3: Mount `cognee_config` into `pocketbase`**

In the `pocketbase` service's `volumes:` (`docker-compose.yml:10-17`), add:

```yaml
      - cognee_config:/cognee-config
```

(PocketBase writes `cognee.env` here in Task 5; it does not need `cognee_data` — only `sqlpage` reads that, per Step 5 below.)

- [ ] **Step 4: Add the new volumes and network to the top-level sections**

In `volumes:` (after `goose_config:` at line 298):

```yaml
  cognee_data:        # cognee's embedded SQLite/LanceDB/Kuzu storage
  cognee_config:       # cognee.env, written by PocketBase, read by cognee
```

In `networks:` (after `pocketcoder-mcp-gateway:` at line 322-323):

```yaml
  # Carries MCP traffic between Goose and cognee only - deliberately separate
  # from pocketcoder-agent (Goose's sole path to/from PocketBase) so this
  # addition doesn't touch that boundary. Mirrors pocketcoder-mcp-gateway.
  pocketcoder-cognee:
    driver: bridge
```

- [ ] **Step 5: Mount `cognee_data` read-only into `sqlpage`**

In the `sqlpage` service's `volumes:` (`docker-compose.yml:170-173`), add:

```yaml
      - cognee_data:/cognee_data:ro
```

- [ ] **Step 6: Verify the compose file is syntactically valid**

```bash
docker compose config --quiet
```

Expected: no output, exit code 0.

- [ ] **Step 7: Commit**

```bash
git add docker-compose.yml
git commit -m "feat(cognee): add cognee service, network, and volumes to compose"
```

## Task 4: PocketBase schema — add the `cognee_config` collection

**Files:**
- Modify: `services/pocketbase/pb_migrations/schema.json`
- Test: `services/pocketbase/pb_migrations/1756000000_schema_test.go` (extend the existing `TestFinalSchemaCollectionsExist` map — this repo's squashed schema migration has exactly one schema file and one schema test file per `CLAUDE.md`; there is no per-collection migration file to create)

**Interfaces:**
- Produces: a `cognee_config` collection with fields `llm_provider` (text), `llm_model` (text), `llm_base_url` (text, optional), `llm_api_key` (text) — consumed by Task 5's render hook via `app.FindRecordsByFilter("cognee_config", ...)`.

Do not hand-type the collection's JSON into `schema.json` from scratch — PocketBase's field `id`s (e.g. `"text1579384326"`) are opaque and must come from PocketBase itself, not be guessed. Capture them the same way the original schema squash did: build the collection with typed Go field structs against a real (temporary) PocketBase app, save it, dump the resulting JSON, then paste that verified JSON into `schema.json`.

- [ ] **Step 1: Write the failing schema test**

Add to `services/pocketbase/pb_migrations/1756000000_schema_test.go`'s `expected` map inside `TestFinalSchemaCollectionsExist` (the map defined at line 18):

```go
		"cognee_config":      {"llm_provider", "llm_model", "llm_base_url", "llm_api_key"},
```

- [ ] **Step 2: Run it to confirm it fails**

```bash
cd services/pocketbase && go test ./pb_migrations/... -run TestFinalSchemaCollectionsExist -v
```

Expected: FAIL — `collection "cognee_config" not found`.

- [ ] **Step 3: Write a throwaway capture test to generate the real collection JSON**

Create `services/pocketbase/pb_migrations/zzz_cognee_dump_test.go` (temporary — deleted in Step 6):

```go
package pb_migrations_test

import (
	"encoding/json"
	"os"
	"testing"

	"github.com/pocketbase/pocketbase/core"
	_ "github.com/qtpi-automaton/pocketcoder/backend/pb_migrations"
)

func TestZZZDumpCogneeConfigCollection(t *testing.T) {
	app := core.NewBaseApp(core.BaseAppConfig{
		DataDir:       t.TempDir(),
		EncryptionEnv: "pb_test_env",
	})
	if err := app.Bootstrap(); err != nil {
		t.Fatal(err)
	}
	if err := app.RunAllMigrations(); err != nil {
		t.Fatal(err)
	}

	collection := core.NewBaseCollection("cognee_config")
	collection.Fields.Add(
		&core.TextField{Name: "llm_provider", Required: true},
		&core.TextField{Name: "llm_model", Required: true},
		&core.TextField{Name: "llm_base_url"},
		&core.TextField{Name: "llm_api_key", Required: true},
	)
	collection.ListRule = nil
	collection.ViewRule = nil
	collection.CreateRule = nil
	collection.UpdateRule = nil
	collection.DeleteRule = nil

	if err := app.Save(collection); err != nil {
		t.Fatal(err)
	}

	raw, err := json.MarshalIndent(collection, "", "  ")
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile("/tmp/cognee_config_collection.json", raw, 0o644); err != nil {
		t.Fatal(err)
	}
	t.Logf("wrote /tmp/cognee_config_collection.json")
}
```

- [ ] **Step 4: Run the capture test and inspect the output**

```bash
cd services/pocketbase && go test ./pb_migrations/... -run TestZZZDumpCogneeConfigCollection -v
cat /tmp/cognee_config_collection.json
```

Confirm the dumped JSON has `"name": "cognee_config"`, four non-system fields (`llm_provider`, `llm_model`, `llm_base_url`, `llm_api_key`) each with a real generated `"id"`, plus the standard system `id`/`created`/`updated` fields matching the shape of every other collection already in `schema.json` (compare against the `healthchecks` collection object as a reference shape).

- [ ] **Step 5: Paste the captured collection into `schema.json`**

Open `services/pocketbase/pb_migrations/schema.json` (a top-level JSON array) and `/tmp/cognee_config_collection.json`. Append the captured collection object as a new array element (comma-separated, matching the existing array formatting). Set `"listRule"`, `"viewRule"`, `"createRule"`, `"updateRule"`, `"deleteRule"` to `null` explicitly if the dump didn't already omit/null them — this is the superuser-only access rule the spec's review corrected (matching `poco_configs`, not `mcp_servers`).

- [ ] **Step 6: Delete the throwaway capture test**

```bash
rm services/pocketbase/pb_migrations/zzz_cognee_dump_test.go
```

- [ ] **Step 7: Run the real schema test and confirm it passes**

```bash
cd services/pocketbase && go test ./pb_migrations/... -run TestFinalSchemaCollectionsExist -v
```

Expected: PASS.

- [ ] **Step 8: Run the full pb_migrations test suite to confirm nothing else broke**

```bash
cd services/pocketbase && go test ./pb_migrations/... -v
```

Expected: all tests PASS (the pre-existing 6 plus the extended one).

- [ ] **Step 9: Commit**

```bash
git add services/pocketbase/pb_migrations/schema.json services/pocketbase/pb_migrations/1756000000_schema_test.go
git commit -m "feat(pocketbase): add cognee_config collection"
```

## Task 5: `cognee_config` render hook

**Files:**
- Create: `services/pocketbase/internal/hooks/cognee_config.go`
- Modify: `services/pocketbase/main.go`

**Interfaces:**
- Consumes: `hooks.registerCrudHooks` and `hooks.renderAndRestart` (both defined in `services/pocketbase/internal/hooks/helpers.go`, already used by `RegisterGooseConfigHooks`); `core.App`.
- Produces: `RegisterCogneeConfigHooks(app core.App)` — called from `main.go` alongside the existing `hooks.RegisterGooseConfigHooks(app, coordGetter)` call at `main.go:68`. Writes `/cognee-config/cognee.env` (the `cognee_config` volume mounted into both `pocketbase` and `cognee` per Task 3).

This mirrors `goose_config.go`'s `RegisterGooseConfigHooks`/`renderGooseConfig` shape, minus the tool-permissions delivery (cognee has no tool-permission concept) and minus the multi-collection resolution (`cognee_config` is self-contained, no `harness_models`/`models` joins needed).

- [ ] **Step 1: Write the failing test**

Create `services/pocketbase/internal/hooks/cognee_config_test.go`:

```go
package hooks_test

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/hooks"
)

func TestRenderCogneeConfigWritesEnvFile(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	dir := t.TempDir()
	hooks.SetCogneeConfigDirForTest(dir)
	defer hooks.SetCogneeConfigDirForTest("/cognee-config")

	coll, err := app.FindCollectionByNameOrId("cognee_config")
	if err != nil {
		t.Fatal(err)
	}
	rec := core.NewRecord(coll)
	rec.Set("llm_provider", "openai")
	rec.Set("llm_model", "gpt-4o-mini")
	rec.Set("llm_base_url", "")
	rec.Set("llm_api_key", "sk-test-123")
	if err := app.Save(rec); err != nil {
		t.Fatal(err)
	}

	hooks.RegisterCogneeConfigHooks(app)

	envPath := filepath.Join(dir, "cognee.env")
	data, err := os.ReadFile(envPath)
	if err != nil {
		t.Fatalf("cognee.env not written: %v", err)
	}
	content := string(data)
	for _, want := range []string{"LLM_PROVIDER=openai", "LLM_MODEL=gpt-4o-mini", "LLM_API_KEY=sk-test-123"} {
		if !contains(content, want) {
			t.Errorf("cognee.env missing %q, got:\n%s", want, content)
		}
	}
}

func contains(haystack, needle string) bool {
	return len(haystack) >= len(needle) && (func() bool {
		for i := 0; i+len(needle) <= len(haystack); i++ {
			if haystack[i:i+len(needle)] == needle {
				return true
			}
		}
		return false
	})()
}
```

- [ ] **Step 2: Run it to confirm it fails**

```bash
cd services/pocketbase && go test ./internal/hooks/... -run TestRenderCogneeConfigWritesEnvFile -v
```

Expected: FAIL — `undefined: hooks.SetCogneeConfigDirForTest` (or similar compile error — the hook doesn't exist yet).

- [ ] **Step 3: Write `cognee_config.go`**

```go
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

// @pocketcoder-core: Cognee Config Hooks. Renders cognee.env from the
// cognee_config collection, then restarts the cognee container so the new
// settings take effect. cognee's LLM credentials are self-contained here —
// deliberately not derived from provider_keys (per-user, no "which user"
// story for a global background service) or ANTHROPIC_API_KEY (goose's own
// key, a separate concern) — see spec 2026-07-24-cognee-agent-memory-design.md §3.4.
package hooks

import (
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/pocketbase/pocketbase/core"
)

// cogneeConfigDir is the PocketBase-side mount of the shared cognee_config
// volume (docker-compose.yml).
var cogneeConfigDir = "/cognee-config"

// SetCogneeConfigDirForTest overrides cogneeConfigDir for tests. Not for
// production use.
func SetCogneeConfigDirForTest(dir string) {
	cogneeConfigDir = dir
}

// RegisterCogneeConfigHooks wires CRUD events on cognee_config to a
// render+restart handler, and runs an initial render on serve startup.
func RegisterCogneeConfigHooks(app core.App) {
	log.Println("🧠 [CogneeConfig] Registering cognee config hooks...")

	handler := func(e *core.RecordEvent) error {
		return renderAndRestart("[CogneeConfig]", func() error { return renderCogneeConfig(app) }, CogneeContainer, e)
	}
	registerCrudHooks(app, "cognee_config", handler)

	app.OnServe().BindFunc(func(e *core.ServeEvent) error {
		if err := renderCogneeConfig(app); err != nil {
			log.Printf("⚠️ [CogneeConfig] initial render failed: %v", err)
		}
		return e.Next()
	})
}

// renderCogneeConfig writes cognee.env from the single cognee_config record,
// if one exists. Returns nil (no-op) if there is no row — cognee then runs
// on whatever's baked into its own image/compose defaults.
func renderCogneeConfig(app core.App) error {
	if err := os.MkdirAll(cogneeConfigDir, 0o755); err != nil {
		return fmt.Errorf("mkdir cognee config dir: %w", err)
	}

	recs, err := app.FindRecordsByFilter("cognee_config", "1=1", "", 1, 0)
	if err != nil {
		return fmt.Errorf("query cognee_config: %w", err)
	}
	if len(recs) == 0 {
		log.Println("ℹ️  [CogneeConfig] no cognee_config row; cognee runs on compose-env defaults")
		return nil
	}
	rec := recs[0]

	lines := fmt.Sprintf(
		"LLM_PROVIDER=%s\nLLM_MODEL=%s\nLLM_BASE_URL=%s\nLLM_API_KEY=%s\n",
		rec.GetString("llm_provider"),
		rec.GetString("llm_model"),
		rec.GetString("llm_base_url"),
		rec.GetString("llm_api_key"),
	)

	path := filepath.Join(cogneeConfigDir, "cognee.env")
	if err := os.WriteFile(path, []byte(lines), 0o600); err != nil {
		return fmt.Errorf("write cognee.env: %w", err)
	}
	return nil
}
```

- [ ] **Step 4: Add `CogneeContainer` to `helpers.go`**

In `services/pocketbase/internal/hooks/helpers.go`, extend the container-name `const` block (line 28-33):

```go
const (
	// GooseContainer is the Goose agent container that consumes the rendered
	// /goose-config/config.yaml + keys.env (plan 2026-07-19-… Task 4).
	GooseContainer   = "pocketcoder-goose"
	GatewayContainer = "pocketcoder-mcp-gateway"
	CogneeContainer  = "pocketcoder-cognee"
)
```

- [ ] **Step 5: Run the test and confirm it passes**

```bash
cd services/pocketbase && go test ./internal/hooks/... -run TestRenderCogneeConfigWritesEnvFile -v
```

Expected: PASS.

- [ ] **Step 6: Wire into `main.go`**

In `services/pocketbase/main.go`, add after the existing goose-config registration (after line 68's `hooks.RegisterGooseConfigHooks(app, coordGetter)`):

```go
	// 3c. Register cognee Config Hooks (cognee.env render + cognee restart)
	hooks.RegisterCogneeConfigHooks(app)
```

- [ ] **Step 7: Run the full hooks test suite**

```bash
cd services/pocketbase && go build ./... && go test ./internal/hooks/... -v
```

Expected: builds clean, all tests PASS.

- [ ] **Step 8: Commit**

```bash
git add services/pocketbase/internal/hooks/cognee_config.go services/pocketbase/internal/hooks/cognee_config_test.go services/pocketbase/internal/hooks/helpers.go services/pocketbase/main.go
git commit -m "feat(pocketbase): render cognee.env from cognee_config, restart cognee on change"
```

## Task 6: cognee ACP extension live-registration hook

**Files:**
- Create: `services/pocketbase/internal/hooks/cognee_extension.go`
- Modify: `services/pocketbase/main.go`

**Interfaces:**
- Consumes: `coordinator.Coordinator.AdminConn` (same as `mcp_gateway.go`); `TRANSPORT`/`PORT` from Task 1's decision file.
- Produces: `RegisterCogneeExtension(coord func() *coordinator.Coordinator)` — called from `main.go`'s `OnServe` handler via `go hooks.RegisterCogneeExtension(coordGetter)`, alongside the existing `go hooks.RegisterMcpGatewayExtension(coordGetter)` call.

This is a near-literal copy of `mcp_gateway.go`'s shape, with the extension name, URL, and (if Task 1 found `TRANSPORT: sse` instead of `http`) the `Server.Type` swapped.

- [ ] **Step 1: Write the failing test**

Create `services/pocketbase/internal/hooks/cognee_extension_test.go` — this mirrors however `mcp_gateway.go`'s registration logic is tested today. First check for an existing `mcp_gateway_test.go`:

```bash
ls services/pocketbase/internal/hooks/mcp_gateway_test.go 2>&1
```

If it exists, read it and write `cognee_extension_test.go` as the same shape (same fake-coordinator/fake-ACP-connection test double), asserting `registerCogneeExtensionOnce` sends an `extensions/add` call with `Server.Name == "cognee"` and `Server.URL == "http://cognee:<PORT>/mcp"` (substitute Task 1's actual port), and that it returns `true` (skip) if `extensions/list` already contains a `"cognee"` entry. If no such test file exists for the gateway either, write `cognee_extension_test.go` as a black-box test asserting `RegisterCogneeExtension` returns immediately (no panic, logs the skip message) when `GOOSE_ACP_URL`/`GOOSE_SERVER__SECRET_KEY`/`GOOSE_WORKSPACE` are unset:

```go
package hooks_test

import (
	"os"
	"testing"

	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/coordinator"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/hooks"
)

func TestRegisterCogneeExtensionSkipsWhenAgentProfileUnconfigured(t *testing.T) {
	os.Unsetenv("GOOSE_ACP_URL")
	os.Unsetenv("GOOSE_SERVER__SECRET_KEY")
	os.Unsetenv("GOOSE_WORKSPACE")

	done := make(chan struct{})
	go func() {
		hooks.RegisterCogneeExtension(func() *coordinator.Coordinator { return nil })
		close(done)
	}()

	select {
	case <-done:
		// returned promptly without retrying — correct when unconfigured
	default:
		t.Fatal("RegisterCogneeExtension should return immediately when agent profile env vars are unset")
	}
}
```

- [ ] **Step 2: Run it to confirm it fails**

```bash
cd services/pocketbase && go test ./internal/hooks/... -run TestRegisterCogneeExtensionSkipsWhenAgentProfileUnconfigured -v
```

Expected: FAIL — `undefined: hooks.RegisterCogneeExtension`.

- [ ] **Step 3: Write `cognee_extension.go`**

Substitute `<PORT>` below with Task 1's decision file value; if Task 1 found `TRANSPORT: sse`, change `Type: "http"` → `Type: "sse"` on `mcpServerHttpParam` (reuse the existing type from `mcp_gateway.go` — it's already generic over transport type via its `Type` field, not HTTP-specific despite the name):

```go
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

// @pocketcoder-core: Cognee Extension Registration. One-time, idempotent
// registration of the cognee memory MCP server as a Goose extension,
// independent of the mcp_servers/Docker-MCP-gateway catalog path (cognee is
// not a catalog server). Mirrors mcp_gateway.go's registration shape. See
// docs/superpowers/specs/2026-07-24-cognee-agent-memory-design.md §3.2 and
// docs/superpowers/plans/2026-07-24-cognee-transport-decision.md for the
// verified transport/port this depends on.
package hooks

import (
	"context"
	"encoding/json"
	"log"
	"os"
	"time"

	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/coordinator"
)

// cogneeExtensionName must match the "name" field in the request built by
// registerCogneeExtensionOnce below.
const cogneeExtensionName = "cognee"

// cogneeURL is cognee's endpoint on the dedicated goose<->cognee Docker
// network (docker-compose.yml). Port verified in
// docs/superpowers/plans/2026-07-24-cognee-transport-decision.md.
const cogneeURL = "http://cognee:<PORT>/mcp"

// RegisterCogneeExtension attempts cognee registration in a bounded retry
// loop and returns once it either succeeds, confirms the extension is
// already present, or exhausts its retries. Intended to be called with `go`
// from main.go's OnServe handler — never blocks PocketBase startup.
func RegisterCogneeExtension(coord func() *coordinator.Coordinator) {
	if os.Getenv("GOOSE_ACP_URL") == "" || os.Getenv("GOOSE_SERVER__SECRET_KEY") == "" || os.Getenv("GOOSE_WORKSPACE") == "" {
		log.Println("ℹ️  [Cognee] agent profile not configured (GOOSE_ACP_URL/GOOSE_SERVER__SECRET_KEY/GOOSE_WORKSPACE unset); skipping cognee registration")
		return
	}

	const maxAttempts = 6
	const retryDelay = 10 * time.Second

	for attempt := 1; attempt <= maxAttempts; attempt++ {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		ok := registerCogneeExtensionOnce(ctx, coord)
		cancel()
		if ok {
			return
		}
		if attempt < maxAttempts {
			log.Printf("🧠 [Cognee] registration attempt %d/%d failed, retrying in %s", attempt, maxAttempts, retryDelay)
			time.Sleep(retryDelay)
		}
	}
	log.Printf("❌ [Cognee] gave up registering cognee extension after %d attempts", maxAttempts)
}

// registerCogneeExtensionOnce does one gate-check-add pass. Returns true if
// the caller should stop retrying (success or already-registered).
func registerCogneeExtensionOnce(ctx context.Context, coord func() *coordinator.Coordinator) bool {
	c := coord()
	if c == nil {
		log.Println("⚠️ [Cognee] agent profile configured but coordinator not yet available")
		return false
	}

	conn, err := c.AdminConn(ctx)
	if err != nil {
		log.Printf("⚠️ [Cognee] AdminConn failed: %v", err)
		return false
	}
	defer conn.Close()

	listRaw, err := conn.CallExtension(ctx, "_goose/unstable/config/extensions/list", struct{}{})
	if err != nil {
		log.Printf("⚠️ [Cognee] config/extensions/list failed: %v", err)
		return false
	}
	var listResp struct {
		Extensions []struct {
			Extension struct {
				Name   string `json:"name"`
				Server struct {
					Name string `json:"name"`
				} `json:"server"`
			} `json:"extension"`
		} `json:"extensions"`
	}
	if err := json.Unmarshal(listRaw, &listResp); err != nil {
		log.Printf("⚠️ [Cognee] failed to parse config/extensions/list response: %v", err)
		return false
	}
	for _, e := range listResp.Extensions {
		name := e.Extension.Server.Name
		if name == "" {
			name = e.Extension.Name
		}
		if name == cogneeExtensionName {
			log.Println("✅ [Cognee] cognee extension already registered")
			return true
		}
	}

	addReq := addConfigExtensionParams{
		Extension: gooseExtensionParam{
			Type: "mcp",
			Server: mcpServerHttpParam{
				Type:    "http",
				Name:    cogneeExtensionName,
				URL:     cogneeURL,
				Headers: []httpHeaderParam{},
			},
		},
		Enabled: true,
	}
	if _, err := conn.CallExtension(ctx, "_goose/unstable/config/extensions/add", addReq); err != nil {
		log.Printf("⚠️ [Cognee] config/extensions/add failed: %v", err)
		return false
	}
	log.Println("✅ [Cognee] registered cognee extension")
	return true
}
```

Note this reuses `addConfigExtensionParams`/`gooseExtensionParam`/`mcpServerHttpParam`/`httpHeaderParam` — all already defined in `mcp_gateway.go` in the same `hooks` package. Do not redefine them here.

- [ ] **Step 4: Replace `<PORT>` in `cogneeURL` with Task 1's actual value, then run the test**

```bash
cd services/pocketbase && go test ./internal/hooks/... -run TestRegisterCogneeExtensionSkipsWhenAgentProfileUnconfigured -v
```

Expected: PASS.

- [ ] **Step 5: Wire into `main.go`**

In `services/pocketbase/main.go`, add after the existing gateway registration (after line 95's `go hooks.RegisterMcpGatewayExtension(coordGetter)`):

```go
			// C2. One-time cognee extension registration (idempotent, retried
			// with backoff — see RegisterCogneeExtension).
			go hooks.RegisterCogneeExtension(coordGetter)
```

- [ ] **Step 6: Full build + test**

```bash
cd services/pocketbase && go build ./... && go test ./... -v 2>&1 | tail -60
```

Expected: builds clean, all tests PASS.

- [ ] **Step 7: Commit**

```bash
git add services/pocketbase/internal/hooks/cognee_extension.go services/pocketbase/internal/hooks/cognee_extension_test.go services/pocketbase/main.go
git commit -m "feat(pocketbase): live-register cognee as a Goose extension"
```

## Task 7: SQLPage visibility — attach cognee's SQLite file, add a memory dashboard

**Files:**
- Modify: `services/sqlpage/dashboard/config/on_connect.sql`
- Create: `services/sqlpage/dashboard/memory.sql`

**Interfaces:**
- Consumes: `cognee_data:/cognee_data:ro` mount added in Task 3 Step 5; assumes cognee's relational store is a SQLite file at `/cognee_data/cognee.db` per the spec (§3.7) — if Task 1/2's spikes revealed cognee actually writes its SQLite file to a different path inside `cognee_data`, use that real path instead (check by inspecting the spike container's filesystem: `docker exec cognee-spike find / -name "*.db" 2>/dev/null` before cleaning it up in Task 1 Step 5, or re-run a quick check now if that was already torn down).

- [ ] **Step 1: Add the cognee attachment to `on_connect.sql`**

`services/sqlpage/dashboard/config/on_connect.sql` currently contains one line (the already-broken `opencode` attachment, left as-is — out of scope per spec §5). Add a second line:

```sql
ATTACH DATABASE '/database/opencode/opencode.db' AS opencode;
ATTACH DATABASE '/cognee_data/cognee.db' AS cognee;
```

- [ ] **Step 2: Write `memory.sql`**

```sql
-- Memory dashboard: recent entries from cognee's knowledge store.
-- Standalone — does not join against the broken opencode/messages queries
-- in index.sql (see spec 2026-07-24-cognee-agent-memory-design.md §2, §5).

SELECT 'title' AS component, 'Agent Memory' AS contents;

SELECT 'table' AS component, 'Recent Memories' AS title;
SELECT * FROM cognee.data_point
ORDER BY created_at DESC
LIMIT 50;
```

The exact table name (`cognee.data_point` above is a placeholder guess based on cognee's typical schema naming) must be verified against the real schema before this is considered done — run:

```bash
docker exec pocketcoder-cognee sh -c "sqlite3 /cognee_data/cognee.db '.tables'" 2>&1 || \
  docker run --rm -v cognee_data:/data:ro alpine sh -c "apk add --no-cache sqlite && sqlite3 /data/cognee.db '.tables'"
```

and replace `cognee.data_point` with whichever table actually holds recent memory entries (likely something storing text content + a timestamp — inspect `.schema <table>` for each candidate table to confirm).

- [ ] **Step 3: Verify SQLPage starts clean with the new attachment**

```bash
docker compose --profile agent up -d cognee sqlpage
docker compose logs sqlpage --tail 30
```

Expected: no `ATTACH DATABASE` errors in the log (a missing `/cognee_data/cognee.db` at this point — before cognee has written any data — may still error; if so, first run a cognee turn via Goose, or manually touch an empty file at that path for this smoke test, then retry).

- [ ] **Step 4: Commit**

```bash
git add services/sqlpage/dashboard/config/on_connect.sql services/sqlpage/dashboard/memory.sql
git commit -m "feat(sqlpage): add cognee memory dashboard"
```

## Task 8: Remove the stale memory-simplification plan

**Files:**
- Delete: `docs/superpowers/plans/2026-07-14-memory-stack-simplification.md`

- [ ] **Step 1: Delete the file**

```bash
git rm docs/superpowers/plans/2026-07-14-memory-stack-simplification.md
```

- [ ] **Step 2: Commit**

```bash
git commit -m "docs: remove stale memory-simplification plan, superseded by 2026-07-24-cognee-agent-memory-design.md"
```

---

## Self-Review

**Spec coverage:** §3.1 (own service + network) → Task 3. §3.2 (ACP live-registration) → Task 6. §3.3 (fully agentic, no injection) → satisfied by omission — no task touches the coordinator/run path, consistent with the spec's explicit decision. §3.4 (self-contained credentials) → Task 5/6 (no `provider_keys`/`ANTHROPIC_API_KEY` reads anywhere). §3.5 (`cognee_config` collection + render hook) → Task 4 + Task 5. §3.6 (open-notebook stays dropped) → no task needed, confirmed already absent. §3.7 (SQLPage) → Task 7. §4 file map's deleted file → Task 8. §6 open questions (transport, image size) → Task 1, Task 2, gating Task 3/6/7 explicitly.

**Placeholder scan:** Task 3/6/7 contain bracketed substitution points (`<PORT>`, `<TRANSPORT>`, `<IMAGE>`) — these are not lazy placeholders; they are values a prior task's spike (Task 1/2) determines empirically and could not be known when this plan was written, with explicit instructions for where to find the real value and how to substitute it. Task 7's table name is flagged as needing verification for the same reason (cognee's real schema isn't knowable without running it). Every other step has concrete, complete code.

**Type consistency:** `RegisterCogneeConfigHooks(app core.App)` (Task 5) and `RegisterCogneeExtension(coord func() *coordinator.Coordinator)` (Task 6) match their `main.go` call sites exactly. `CogneeContainer` (Task 5 Step 4) matches the string used in Task 5 Step 3's `renderAndRestart` call. `cogneeExtensionName`/`cogneeURL` (Task 6) are package-level consts, not re-derived elsewhere. `addConfigExtensionParams`/`gooseExtensionParam`/`mcpServerHttpParam`/`httpHeaderParam` are explicitly noted as reused from `mcp_gateway.go`, not redefined — avoids a duplicate-type compile error.
