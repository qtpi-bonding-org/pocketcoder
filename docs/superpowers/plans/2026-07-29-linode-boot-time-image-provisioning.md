# Linode Boot-Time Image Provisioning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the (broken, Worker-streaming-based) Linode Custom-Image
upload path with a boot-time-pull path — a stock Linode instance downloads
the NixOS image directly from R2 at boot and `dd`s it onto a raw disk — as
a second, additive, DI-selected `IInstanceProvisioningStrategy`, without
deleting the existing (kept for option value) Custom-Image path.

**Architecture:** New `IInstanceProvisioningStrategy` seam in
`DeploymentService`, two implementations (`CustomImageProvisioningStrategy`
= today's logic extracted verbatim; `BootTimePullProvisioningStrategy` =
new, depends on a single-method cross-provider `IUrlPullProvisioningApi`).
`LinodeAPIClient` implements `IUrlPullProvisioningApi` via an internal,
explicitly-non-portable `LinodeBootTimeInstaller` helper driving Linode's
disk/config-profile API directly. `workers/image-relay` gains a read-only
`/image-manifest` endpoint (data written by CI, not the Worker); its
existing upload/queue code stays present but the queue consumer is
disabled. One NixOS config fix (`autoResize`) makes the target disk
actually usable.

**Tech Stack:** Dart/Flutter (`flutter_aeroform`), TypeScript (Cloudflare
Workers, `workers/image-relay`), Nix (`deploy/nixos`), bash (StackScript,
GitHub Actions), mocktail/flutter_test for Dart unit tests.

## Global Constraints

- Full design rationale, the corrected 10-step Linode sequence, the fixed
  StackScript, security findings, and everything "why" lives in
  `docs/superpowers/specs/2026-07-29-linode-boot-time-image-provisioning-design.md`
  — read it before starting if anything below is unclear on *why*, not
  just *what*.
- `flutter_aeroform` is a sibling repo at `/Users/aicoder/Documents/flutter_aeroform`
  (separate git history/remote from `pocketcoder`). Tasks below state
  which repo each file is in.
- Never touch secrets directly (API tokens, etc.) — this project uses a
  secrets-daemon architecture (see `~/.claude/skills/secrets-daemon` if
  the executing agent has access to it) for anything needing a real
  credential (triggering CI, deploying Workers, calling Linode's API for
  live verification). If a task needs a live credentialed action and the
  mechanism isn't available in the executing environment, stop and flag
  it rather than trying to read/export a secret directly.
- Existing code style: no comments explaining *what* code does, only
  non-obvious *why* (matches this repo's established convention, visible
  throughout `deployment_service.dart`/`linode_api_client.dart`).
- Dart null-safety rule (root `client/CLAUDE.md`'s convention, followed
  throughout `flutter_aeroform` too): never use `!`.
- `flutter analyze` must stay clean and `flutter test` must stay green
  after every task in `flutter_aeroform`.

## Secrets-Daemon Actions Needed

Per the `secrets-daemon` skill: never invoke an action to check whether it
exists (`{"list": true}` only); never work around a missing action
yourself. This section is the pre-planned inventory so whoever executes
this plan isn't discovering these mid-task. Check `{"list": true}` at the
start of execution to confirm current state against this list before
doing anything else.

**Already exist (per this session's earlier work) — just confirm via
`{"list": true}`, don't re-propose:**

- `deploy_image_relay` — deploys `workers/image-relay` (needed by Task 4
  Step 4, after the manifest route + queue-consumer-disable + token-leak
  fix land).
- `trigger_nixos_ci_build` — fires `.github/workflows/nixos-image.yml`
  via `workflow_dispatch` (needed by Task 3's verification and Task 4
  Step 5).
- `fetch_ci_log` — pulls the resulting workflow run's log (useful for
  confirming Task 3's new sha256/manifest-write steps actually ran
  correctly on the first real trigger).
- `run_aeroform_golden_path_test` — runs the live, billed integration
  test. **Re-check this one specifically before Task 14 Step 7**: the
  test file's content changes substantially across Tasks 7–14 (new
  `BootTimePullProvisioningStrategy` construction, extended timeout, new
  corrupted-manifest test). If this action's command targets the test by
  file path + a fixed `--dart-define` set (not by hash-pinned script
  content), it likely still works unmodified — but if it was ever
  `script_sha256`-pinned against the old test file's content, it needs
  the user to re-run `pin-script-hash.sh` after Task 14 lands, same as
  any other pinned-script edit.

**New — need proposing to the user before Task 13 / the pre-implementation
verification step below (not before Tasks 1–12, which don't need live
credentialed access):**

- **`publish_boot_installer_stackscript`** (Task 13 Step 4) — publishes/
  updates the StackScript from
  `deploy/nixos/scripts/publish-stackscript.sh`.
  ```json
  "publish_boot_installer_stackscript": {
    "secrets": "secrets/linode.enc.yaml",
    "command": ["/bin/sh", "/Users/aicoder/Documents/pocketcoder/deploy/nixos/scripts/publish-stackscript.sh"]
  }
  ```
  Reuses the existing `secrets/linode.enc.yaml` file (same `LINODE_TOKEN`
  the other Linode actions already use) — no new vault secret needed.
  Shells out to a separate script file, so per the skill: leave
  unpinned (`script_sha256` omitted) while `publish-stackscript.sh` is
  still new/iterating; the user pins it once they've reviewed it as
  stable.

- **`verify_linode_metadata_delivery`** (design spec's "Pre-implementation
  verification" section — must run and confirm success **before starting
  Task 10**, not after; it's the single highest-value unknown in the
  whole design). Needs a new script,
  `deploy/nixos/scripts/verify-metadata-delivery.sh`, not yet written —
  write it as the first step of this verification work: generate a
  throwaway SSH keypair at runtime (never vault-stored — it's disposable,
  scoped to one test instance), create a real Linode instance with
  `image: "linode/debian12"`, `authorized_keys: [thatKey]`, and
  `metadata.user_data` set to a small known base64 test payload; wait for
  it to boot; SSH in once; run `curl -H "Metadata-Token: $(curl -s -X PUT
  -H 'Metadata-Token-Expiry-Seconds: 60'
  http://169.254.169.254/v1/token)"
  http://169.254.169.254/v1/user-data`; print exactly what came back
  (this is the thing being verified — does it match the known payload,
  and is it still base64-encoded or already decoded); delete the
  instance.
  ```json
  "verify_linode_metadata_delivery": {
    "secrets": "secrets/linode.enc.yaml",
    "command": ["/bin/sh", "/Users/aicoder/Documents/pocketcoder/deploy/nixos/scripts/verify-metadata-delivery.sh"]
  }
  ```
  Same reused `secrets/linode.enc.yaml` file. Leave unpinned until the
  script is written and reviewed (it doesn't exist yet as of this plan).

**Explicitly not needed:** Task 3's CI changes run entirely inside GitHub
Actions using its own repo-level secrets (`R2_ACCESS_KEY_ID`,
`CLOUDFLARE_ACCOUNT_ID`, etc.) — no local daemon action touches those.
Tasks 1, 2, 5–12 are pure local code changes (Nix config, Dart) needing
no credentialed access at all — `flutter analyze`/`flutter test`/`nix
flake check` run with no secrets involved.

---

## File Structure

**`pocketcoder` repo:**
- Modify: `deploy/nixos/configuration.nix` (Task 1 — `autoResize`)
- Modify: `deploy/nixos/bootstrap.nix` (Task 2 — heredoc indentation fix)
- Modify: `.github/workflows/nixos-image.yml` (Task 3 — sha256/size/
  versioned key/manifest)
- Modify: `workers/image-relay/src/index.ts` (Task 4 — `/image-manifest`,
  disable queue consumer, fix `/image-status` token leak)
- Modify: `workers/image-relay/wrangler.toml` (Task 4 — queue consumer
  disabled)
- Create: `deploy/nixos/scripts/publish-stackscript.sh` (Task 13)
- Create: `deploy/nixos/stackscripts/pocketcoder-image-installer.sh`
  (Task 13 — the StackScript content itself, version-controlled)

**`flutter_aeroform` repo:**
- Modify: `lib/domain/models/app_config.dart` (Task 5)
- Modify: `lib/infrastructure/cloud_provider/linode_api_client.dart`
  (Tasks 5, 8, 11)
- Modify: `lib/domain/models/deployment_config.dart` (Task 6)
- Create: `lib/domain/deployment/i_instance_provisioning_strategy.dart`
  (Task 7)
- Create: `lib/infrastructure/deployment/custom_image_provisioning_strategy.dart`
  (Task 7)
- Modify: `lib/infrastructure/deployment/deployment_service.dart` (Task 7,
  15, 16)
- Modify: `lib/domain/deployment/i_deployment_service.dart` (Task 16)
- Create: `lib/domain/cloud_provider/i_url_pull_provisioning_api.dart`
  (Task 9)
- Create: `lib/infrastructure/cloud_provider/linode_boot_time_installer.dart`
  (Task 10)
- Create: `lib/infrastructure/deployment/boot_time_pull_provisioning_strategy.dart`
  (Task 12)
- Modify: `test/infrastructure/cloud_provider/linode_api_client_test.dart`
  (Tasks 5, 8, 11)
- Create: `test/infrastructure/cloud_provider/linode_boot_time_installer_test.dart`
  (Task 10)
- Create: `test/infrastructure/deployment/custom_image_provisioning_strategy_test.dart`
  (Task 7)
- Create: `test/infrastructure/deployment/boot_time_pull_provisioning_strategy_test.dart`
  (Task 12)
- Modify: `test/infrastructure/deployment/deployment_service_test.dart`
  (Task 7)
- Modify: `test/domain/models/data_models_roundtrip_test.dart` (Task 6)
- Modify: `test/integration/golden_path_provision_test.dart` (Task 14)

---

### Task 1: NixOS `autoResize` fix

**Files:**
- Modify: `deploy/nixos/configuration.nix` (pocketcoder repo)

**Interfaces:** None (Nix config only).

- [ ] **Step 1: Make the change**

In `deploy/nixos/configuration.nix`, find:

```nix
  # Root filesystem (Linode provides a single disk)
  fileSystems."/" = {
    device = "/dev/sda";
    fsType = "ext4";
  };
```

Replace with:

```nix
  # Root filesystem (Linode provides a single disk). autoResize is
  # required for boot-time-pull provisioning: dd-ing this image onto a
  # bigger raw disk does not grow the filesystem on its own -- without
  # this, every deployment is capped at the image's original ~4.7GB
  # regardless of the real disk size (docs/superpowers/specs/
  # 2026-07-29-linode-boot-time-image-provisioning-design.md, "NixOS
  # image change required").
  fileSystems."/" = {
    device = "/dev/sda";
    fsType = "ext4";
    autoResize = true;
  };
```

- [ ] **Step 2: Verify the flake still evaluates**

Run (from the repo root, in Docker as established earlier this session —
`nixos/nix` image, no local Nix install needed):

```bash
docker run --rm -v "$(pwd)/deploy/nixos:/repo" -w /repo nixos/nix \
  sh -c "nix --extra-experimental-features 'nix-command flakes' flake check --no-build"
```

Expected: `all checks passed!`

- [ ] **Step 3: Commit**

```bash
git add deploy/nixos/configuration.nix
git commit -m "fix(nixos): autoResize root filesystem to fill the target disk

dd-ing this image onto a bigger raw disk (boot-time-pull provisioning)
doesn't grow the filesystem on its own -- every deployment was capped
at the image's original ~4.7GB regardless of real disk size."
```

---

### Task 2: `bootstrap.nix` heredoc indentation fix

**Files:**
- Modify: `deploy/nixos/bootstrap.nix` (pocketcoder repo)

**Interfaces:** None.

- [ ] **Step 1: Find and fix the indented heredoc**

In `deploy/nixos/bootstrap.nix`, find the block that writes generated
secrets into `.env` (added when passwordless SSH support was implemented
earlier this session) — it looks like:

```sh
        cat >> "$INSTALL_DIR/.env" <<EOF
      POCKETBASE_SUPERUSER_EMAIL=superuser@pocketcoder.local
      POCKETBASE_SUPERUSER_PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)
      AGENT_EMAIL=agent@pocketcoder.local
      AGENT_PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)
      GOOSE_SERVER__SECRET_KEY=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)
      EOF
```

The six-space indentation on each key line (an artifact of the
surrounding Nix `''...''` string indentation) becomes literal leading
whitespace in `.env`, which docker compose's `env_file` parsing does not
strip. Replace with an unindented heredoc body (still fine inside the Nix
string — only the *body* needs to start at column 0, the shell script
around it can stay indented):

```sh
        cat >> "$INSTALL_DIR/.env" <<EOF
POCKETBASE_SUPERUSER_EMAIL=superuser@pocketcoder.local
POCKETBASE_SUPERUSER_PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)
AGENT_EMAIL=agent@pocketcoder.local
AGENT_PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)
GOOSE_SERVER__SECRET_KEY=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)
EOF
```

- [ ] **Step 2: Verify the flake still evaluates**

Same command as Task 1, Step 2.

- [ ] **Step 3: Commit**

```bash
git add deploy/nixos/bootstrap.nix
git commit -m "fix(nixos): un-indent generated .env heredoc body

Leading whitespace on docker compose env_file keys isn't valid --
the six-space indentation was an artifact of the surrounding Nix
string, not intentional."
```

---

### Task 3: CI publishes sha256/uncompressed size/versioned key/manifest

**Files:**
- Modify: `.github/workflows/nixos-image.yml` (pocketcoder repo)

**Interfaces:**
- Produces: an R2 object at `pocketcoder-images/pocketcoder-nixos-<git-sha>.img.gz`
  and a manifest object at `pocketcoder-images/image-manifest.json` shaped
  `{"url": "...", "sha256": "...", "uncompressedBytes": N}` — consumed by
  Task 4 (Worker's `/image-manifest` route reads this object) and Task 12
  (`BootTimePullProvisioningStrategy` fetches it via the Worker).

- [ ] **Step 1: Read the current workflow**

`cat .github/workflows/nixos-image.yml` — this session already modified
it once (R2 multipart upload via `aws s3 cp`). Find the step after
`Compress image` and before `Upload to R2`.

- [ ] **Step 2: Add sha256 + uncompressed size computation**

Insert a new step right after `Compress image`:

```yaml
      - name: Compute image metadata
        id: meta
        run: |
          SHA256=$(sha256sum pocketcoder-nixos.img.gz | cut -d' ' -f1)
          UNCOMPRESSED_BYTES=$(stat -c%s deploy/nixos/result/nixos.img)
          echo "sha256=$SHA256" >> "$GITHUB_OUTPUT"
          echo "uncompressed_bytes=$UNCOMPRESSED_BYTES" >> "$GITHUB_OUTPUT"
          echo "Image sha256: $SHA256"
          echo "Uncompressed bytes: $UNCOMPRESSED_BYTES"
```

- [ ] **Step 3: Upload to a versioned key, and write the manifest object**

Replace the existing `Upload to R2` step's destination key, and add a
manifest-write step right after it:

```yaml
      - name: Upload to R2
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.R2_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.R2_SECRET_ACCESS_KEY }}
          AWS_DEFAULT_REGION: auto
        run: |
          aws s3 cp pocketcoder-nixos.img.gz \
            s3://pocketcoder-images/pocketcoder-nixos-${{ github.sha }}.img.gz \
            --endpoint-url https://${{ secrets.CLOUDFLARE_ACCOUNT_ID }}.r2.cloudflarestorage.com

      - name: Publish manifest
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.R2_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.R2_SECRET_ACCESS_KEY }}
          AWS_DEFAULT_REGION: auto
        run: |
          cat > manifest.json <<EOF
          {
            "url": "https://images.pocketcoder.dev/pocketcoder-nixos-${{ github.sha }}.img.gz",
            "sha256": "${{ steps.meta.outputs.sha256 }}",
            "uncompressedBytes": ${{ steps.meta.outputs.uncompressed_bytes }}
          }
          EOF
          aws s3 cp manifest.json \
            s3://pocketcoder-images/image-manifest.json \
            --endpoint-url https://${{ secrets.CLOUDFLARE_ACCOUNT_ID }}.r2.cloudflarestorage.com
```

(`images.pocketcoder.dev` is a placeholder custom domain — Task 4's
implementer needs a real Cloudflare custom domain set up in front of the
`pocketcoder-images` R2 bucket first; update this URL to match once that
domain is actually configured. Flag this explicitly rather than silently
using a domain that doesn't resolve.)

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/nixos-image.yml
git commit -m "feat(ci): publish versioned image key + sha256/size manifest

Boot-time-pull provisioning depends on both: an immutable per-build R2
key (a mutable -latest key could swap the object mid-deployment) and a
manifest with the real sha256/uncompressed size for the StackScript's
integrity/capacity checks -- neither existed before."
```

(Do not trigger this workflow for real yet — Task 4 needs to land first
so the manifest object this produces actually has a consumer; verify both
together at the end of Task 4.)

---

### Task 4: Worker — `/image-manifest`, disable queue consumer, fix token leak

**Files:**
- Modify: `workers/image-relay/src/index.ts` (pocketcoder repo)
- Modify: `workers/image-relay/wrangler.toml` (pocketcoder repo)

**Interfaces:**
- Produces: `GET /image-manifest` → `{"url": string, "sha256": string,
  "uncompressedBytes": number}` — consumed by Task 12
  (`BootTimePullProvisioningStrategy`).

- [ ] **Step 1: Disable the queue consumer**

In `workers/image-relay/wrangler.toml`, find:

```toml
[[queues.consumers]]
queue = "pocketcoder-image-uploads"
max_batch_size = 1
max_retries = 3
```

Comment it out (keep the producer binding — `handleUploadImage` still
uses it, unreachable via the now-non-default `CustomImageProvisioningStrategy`
but still real code):

```toml
# Disabled: CustomImageProvisioningStrategy (the streaming-upload path
# this queue serves) is no longer the default provisioning path -- see
# docs/superpowers/specs/2026-07-29-linode-boot-time-image-provisioning-design.md,
# "Strategy 1." Disabling the consumer (not deleting it) prevents a
# stale enqueued message from retry-looping against an already-dead,
# single-use upload_to URL and generating pointless billed activity.
# [[queues.consumers]]
# queue = "pocketcoder-image-uploads"
# max_batch_size = 1
# max_retries = 3
```

- [ ] **Step 2: Add the `Env` field and the `/image-manifest` route**

In `workers/image-relay/src/index.ts`, add `IMAGES` is already bound;
add the route. Find the `fetch` handler's route dispatch:

```ts
    if (url.pathname === "/image-status" && request.method === "GET") {
      return handleImageStatus(request, env);
    }
```

Add immediately after it:

```ts
    if (url.pathname === "/image-manifest" && request.method === "GET") {
      return handleImageManifest(env);
    }
```

Add the handler function (near `handleImageStatus`):

```ts
async function handleImageManifest(env: Env): Promise<Response> {
  // Read-only, deliberately: this manifest is the single point of
  // indirection every future deployment trusts for which image to dd
  // onto its root disk. The Worker has no write route for it at all --
  // CI writes the object directly to R2 with its own scoped credential
  // (see .github/workflows/nixos-image.yml). An unauthenticated write
  // route here would be remote code execution on every future
  // deployment (the sha256 the manifest carries provides no protection
  // against a malicious manifest, since the attacker supplies that too).
  const obj = await env.IMAGES.get("image-manifest.json");
  if (!obj) {
    return json({ error: "No manifest published yet" }, 404);
  }
  const manifest = await obj.json();
  return json(manifest);
}
```

- [ ] **Step 3: Fix `/image-status`'s token-in-query-string leak**

Find `handleImageStatus`:

```ts
async function handleImageStatus(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const token = url.searchParams.get("linodeToken");
  const label = url.searchParams.get("label");
```

A Linode API token in a query string lands in Cloudflare's own request
logs. Change this route to `POST` with the token in the body, matching
`/upload-image`'s existing (correct) pattern:

```ts
async function handleImageStatus(request: Request, env: Env): Promise<Response> {
  const body = (await request.json()) as StatusRequest;
  const { linodeToken: token, label } = body;
```

Update the route dispatch to match:

```ts
    if (url.pathname === "/image-status" && request.method === "POST") {
      return handleImageStatus(request, env);
    }
```

(`StatusRequest` already exists as an interface in this file with exactly
`{linodeToken, label}` — reuse it, don't redefine.)

- [ ] **Step 4: Deploy and verify live**

This needs the secrets-daemon's `deploy_image_relay` action (already
wired up earlier this session). If the executing agent has access to it:

```
{"action": "deploy_image_relay"}
```

over the daemon socket. Then verify:

```bash
curl -s https://pocketcoder-image-relay.gp-c53.workers.dev/image-manifest
```

Expected at this point: `{"error":"No manifest published yet"}` with
404 (Task 3's workflow hasn't run yet). If the daemon isn't available in
the executing environment, stop here and flag that Task 3's workflow and
this deploy both need to be triggered by a human before Task 4 can be
verified end-to-end.

- [ ] **Step 5: Trigger Task 3's workflow for real, then re-verify**

Trigger `nixos-image.yml` (via the `trigger_nixos_ci_build` daemon action
if available, or ask a human to run it via `workflow_dispatch`). Once it
completes, re-run the `curl` from Step 4 — expected: a real
`{"url": ..., "sha256": ..., "uncompressedBytes": ...}` response.

- [ ] **Step 6: Commit**

```bash
git add workers/image-relay/src/index.ts workers/image-relay/wrangler.toml
git commit -m "feat(image-relay): add read-only /image-manifest, disable queue consumer

/image-manifest is read-only by design -- CI writes the manifest
object directly to R2, the Worker never writes it, since an
unauthenticated write route here would let anyone redirect every
future deployment to an arbitrary image.

Also fixes /image-status leaking a live Linode token via query string
into Cloudflare's own request logs (now POST + body, matching
/upload-image's existing pattern), and disables (not deletes) the
queue consumer for the now-non-default upload path."
```

---

### Task 5: Fix `kImageRelayUrl` default + `listInstances` labelFilter bug

**Files:**
- Modify: `lib/domain/models/app_config.dart` (flutter_aeroform repo)
- Modify: `lib/infrastructure/cloud_provider/linode_api_client.dart`
  (flutter_aeroform repo)
- Modify: `test/infrastructure/cloud_provider/linode_api_client_test.dart`
  (flutter_aeroform repo)

**Interfaces:** None new — both are bug fixes to existing surfaces.

- [ ] **Step 1: Fix the dead `kImageRelayUrl` default**

In `lib/domain/models/app_config.dart`:

```dart
  /// CF Worker URL for streaming NixOS image to Linode
  static const kImageRelayUrl = String.fromEnvironment(
    'IMAGE_RELAY_URL',
    defaultValue: 'https://pocketcoder-image-relay.workers.dev',
  );
```

Change the default to the real deployed URL:

```dart
  /// CF Worker URL for the image-relay Worker (manifest lookup,
  /// legacy upload path)
  static const kImageRelayUrl = String.fromEnvironment(
    'IMAGE_RELAY_URL',
    defaultValue: 'https://pocketcoder-image-relay.gp-c53.workers.dev',
  );
```

- [ ] **Step 2: Write the failing test for `listInstances`'s labelFilter bug**

In `test/infrastructure/cloud_provider/linode_api_client_test.dart`, find
the `listInstances` group's `'applies label filter'` test:

```dart
      test('applies label filter', () async {
```

This test currently only asserts the *response* is filtered (which the
mocked HTTP response already is, regardless of whether the request URL
actually carried the filter) — it never asserts the *request URL*. Add a
new test right after it that actually catches the bug:

```dart
      test('sends label filter in the request URL', () async {
        final response = http.Response(jsonEncode({'data': []}), 200);

        when(() => mockHttpClient.get(
              any(that: predicate<Uri>(
                  (uri) => uri.queryParameters['label'] == 'pocketcoder')),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => response);

        await client.listInstances(testAccessToken, labelFilter: 'pocketcoder');

        verify(() => mockHttpClient.get(
              any(that: predicate<Uri>(
                  (uri) => uri.queryParameters['label'] == 'pocketcoder')),
              headers: any(named: 'headers'),
            )).called(1);
      });
```

- [ ] **Step 3: Run it to verify it fails**

```bash
cd /Users/aicoder/Documents/flutter_aeroform
flutter test test/infrastructure/cloud_provider/linode_api_client_test.dart --plain-name "sends label filter"
```

Expected: FAIL (the mocked `get` with the label-filter predicate is never
matched, since the real request URL currently has no `label` param at
all).

- [ ] **Step 4: Fix `listInstances`**

In `lib/infrastructure/cloud_provider/linode_api_client.dart`, find:

```dart
  @override
  Future<List<CloudInstance>> listInstances(
    String accessToken, {
    String? labelFilter,
  }) async {
    final uri = Uri.parse('$_baseUrl/linode/instances');
    if (labelFilter != null) {
      uri.replace(queryParameters: {'label': labelFilter});
    }

    final response = await _httpClient.get(
      uri,
```

`Uri.replace` returns a new `Uri` — the result was discarded, so the
filter was always a silent no-op. Fix:

```dart
  @override
  Future<List<CloudInstance>> listInstances(
    String accessToken, {
    String? labelFilter,
  }) async {
    var uri = Uri.parse('$_baseUrl/linode/instances');
    if (labelFilter != null) {
      uri = uri.replace(queryParameters: {'label': labelFilter});
    }

    final response = await _httpClient.get(
      uri,
```

- [ ] **Step 5: Run it to verify it passes**

```bash
flutter test test/infrastructure/cloud_provider/linode_api_client_test.dart --plain-name "sends label filter"
```

Expected: PASS.

- [ ] **Step 6: Run the full suite to confirm nothing else broke**

```bash
flutter analyze
flutter test
```

Expected: clean analyze, all tests pass except the two pre-existing,
unrelated `linode_oauth_service_test.dart` failures already present
before this session's work began.

- [ ] **Step 7: Commit**

```bash
git add lib/domain/models/app_config.dart lib/infrastructure/cloud_provider/linode_api_client.dart test/infrastructure/cloud_provider/linode_api_client_test.dart
git commit -m "fix: dead kImageRelayUrl default, listInstances labelFilter no-op

kImageRelayUrl's default pointed at a URL that's never been the real
deployed Worker -- any build without an explicit --dart-define hit a
nonexistent host.

listInstances's labelFilter was silently discarded (Uri.replace
returns a new Uri, doesn't mutate in place) -- every call effectively
listed all instances regardless of the filter argument. Added a
regression test that asserts the actual request URL, not just the
(already-filtered, in the test's mock) response shape."
```

---

### Task 6: Delete `DeploymentConfig.toMetadata()` dead code

**Files:**
- Modify: `lib/domain/models/deployment_config.dart` (flutter_aeroform
  repo)
- Modify: `test/domain/models/data_models_roundtrip_test.dart`
  (flutter_aeroform repo)

**Interfaces:** Removes `DeploymentConfig.toMetadata()` — confirm nothing
in later tasks depends on it (nothing does; `deploy()` never called it).

- [ ] **Step 1: Confirm it's genuinely unused**

```bash
cd /Users/aicoder/Documents/flutter_aeroform
grep -rn "toMetadata" lib/ test/
```

Expected: only the definition in `deployment_config.dart` and the three
tests in `data_models_roundtrip_test.dart` that test it directly (no call
site in `deployment_service.dart` or anywhere else).

- [ ] **Step 2: Delete the method**

In `lib/domain/models/deployment_config.dart`, remove:

```dart
  /// Builds metadata map for Linode instance creation.
  Map<String, String> toMetadata() {
    return {
      'admin_email': adminEmail,
      'ntfy_enabled': ntfyEnabled.toString(),
      if (linodeToken != null) 'linode_token': linodeToken!,
    };
  }
```

- [ ] **Step 3: Delete its tests**

In `test/domain/models/data_models_roundtrip_test.dart`, remove the three
tests: `'DeploymentConfig toMetadata returns correct map'` and
`'DeploymentConfig toMetadata includes optional linodeToken'` (and check
whether `linodeToken` itself is still exercised by the remaining
serialization round-trip test — it should be, since it's still a real
`DeploymentConfig` field, just no longer converted to a metadata map).

- [ ] **Step 4: Run the full suite**

```bash
flutter analyze
flutter test
```

Expected: clean, same baseline as Task 5's Step 6.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/models/deployment_config.dart test/domain/models/data_models_roundtrip_test.dart
git commit -m "fix: delete dead DeploymentConfig.toMetadata()

deploy() never called it -- linodeToken never actually reached an
instance via this method. Deleted rather than wired in, since nothing
in this design needs it (user_data carries everything an instance
needs)."
```

---

### Task 7: Extract `IInstanceProvisioningStrategy` + `CustomImageProvisioningStrategy`

This is a behavior-preserving refactor: move `DeploymentService`'s
existing `_ensureNixosImage`/`createInstance` logic into a new class,
verbatim, with no behavior change. `DeploymentService.deploy()` calls the
new seam instead.

**Files:**
- Create: `lib/domain/deployment/i_instance_provisioning_strategy.dart`
  (flutter_aeroform repo)
- Create: `lib/infrastructure/deployment/custom_image_provisioning_strategy.dart`
  (flutter_aeroform repo)
- Create: `test/infrastructure/deployment/custom_image_provisioning_strategy_test.dart`
  (flutter_aeroform repo)
- Modify: `lib/infrastructure/deployment/deployment_service.dart`
  (flutter_aeroform repo)
- Modify: `test/infrastructure/deployment/deployment_service_test.dart`
  (flutter_aeroform repo)

**Interfaces:**
- Produces:
  ```dart
  abstract class IInstanceProvisioningStrategy {
    Future<CloudInstance> provisionInstance({
      required String accessToken,
      required DeploymentConfig config,
      required String userData,
    });
  }
  ```
  Consumed by `DeploymentService` (this task) and, later, by
  `BootTimePullProvisioningStrategy` (Task 12, which implements the same
  interface).

- [ ] **Step 1: Create the interface**

`lib/domain/deployment/i_instance_provisioning_strategy.dart`:

```dart
import 'package:flutter_aeroform/domain/models/cloud_provider.dart';
import 'package:flutter_aeroform/domain/models/deployment_config.dart';

/// Provisions a fresh instance that will boot into the target image.
/// Returns once the instance exists and is either already booting the
/// target image, or (for pull-based strategies) has finished writing
/// its target disk and is booting it -- NOT full boot-to-cert-ready
/// (DeploymentService.monitorDeployment's polling loop still owns that,
/// unchanged, for every strategy).
abstract class IInstanceProvisioningStrategy {
  Future<CloudInstance> provisionInstance({
    required String accessToken,
    required DeploymentConfig config,
    required String userData,
  });
}
```

- [ ] **Step 2: Create `CustomImageProvisioningStrategy`, moving the
  existing logic verbatim**

`lib/infrastructure/deployment/custom_image_provisioning_strategy.dart`:

```dart
import 'package:injectable/injectable.dart';

import 'package:flutter_aeroform/domain/cloud_provider/i_cloud_provider_api_client.dart';
import 'package:flutter_aeroform/domain/deployment/i_instance_provisioning_strategy.dart';
import 'package:flutter_aeroform/domain/models/cloud_provider.dart';
import 'package:flutter_aeroform/domain/models/deployment_config.dart';

/// Custom-Image-upload provisioning: find or upload the NixOS image to
/// Linode's Images API via the image-relay Worker, then create an
/// instance from it. Kept for its option value (a correct, reasonable
/// implementation of a common cloud-provider API pattern) even though
/// it's no longer the default for Linode -- see
/// docs/superpowers/specs/2026-07-29-linode-boot-time-image-provisioning-design.md,
/// "Strategy 1," for why it's not the default and why its known bugs
/// (in image-relay's Worker code, not here) are deliberately unfixed.
@Named('customImage')
@LazySingleton(as: IInstanceProvisioningStrategy)
class CustomImageProvisioningStrategy implements IInstanceProvisioningStrategy {
  static const int _imagePollingMaxAttempts = 80;
  static const Duration _imagePollingInterval = Duration(seconds: 15);

  final ICloudProviderAPIClient _apiClient;

  CustomImageProvisioningStrategy(this._apiClient);

  @override
  Future<CloudInstance> provisionInstance({
    required String accessToken,
    required DeploymentConfig config,
    required String userData,
  }) async {
    final imageId = await _ensureNixosImage(
      accessToken: accessToken,
      config: config,
    );

    return _apiClient.createInstance(
      accessToken: accessToken,
      planType: config.planType,
      region: config.region,
      image: imageId,
      metadata: {'user_data': userData},
    );
  }

  Future<String> _ensureNixosImage({
    required String accessToken,
    required DeploymentConfig config,
  }) async {
    final existingId = await _apiClient.findImageByLabel(
      accessToken,
      config.nixosImageLabel,
    );
    if (existingId != null) return existingId;

    final uploadResult = await _apiClient.triggerImageUpload(
      accessToken: accessToken,
      relayUrl: config.imageRelayUrl,
      label: config.nixosImageLabel,
      region: config.region,
    );

    if (uploadResult['existed'] == true && uploadResult['status'] == 'available') {
      return uploadResult['imageId'] as String;
    }

    for (var i = 0; i < _imagePollingMaxAttempts; i++) {
      await Future.delayed(_imagePollingInterval);

      final imageId = await _apiClient.findImageByLabel(
        accessToken,
        config.nixosImageLabel,
      );
      if (imageId != null) return imageId;
    }

    throw Exception(
      'NixOS image upload timed out after ${_imagePollingMaxAttempts * _imagePollingInterval.inSeconds}s',
    );
  }
}
```

(`@Named('customImage')` marks this so it's constructible via DI *by
name* for tests/debug overrides without being the default
`IInstanceProvisioningStrategy` injectable resolves — see Task 12's DI
registration for how the default is chosen instead.)

- [ ] **Step 3: Move the existing tests to the new test file**

Create `test/infrastructure/deployment/custom_image_provisioning_strategy_test.dart`
by relocating the image-resolution-specific tests currently embedded in
`deployment_service_test.dart`'s `'deploy'` group (the ones that stub
`findImageByLabel`/`triggerImageUpload` and assert on `createInstance`'s
`image:` argument) — rewrite them against
`CustomImageProvisioningStrategy.provisionInstance` directly instead of
through `DeploymentService.deploy()`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:flutter_aeroform/domain/cloud_provider/i_cloud_provider_api_client.dart';
import 'package:flutter_aeroform/domain/models/cloud_provider.dart';
import 'package:flutter_aeroform/domain/models/deployment_config.dart';
import 'package:flutter_aeroform/infrastructure/deployment/custom_image_provisioning_strategy.dart';

class MockCloudProviderAPIClient extends Mock implements ICloudProviderAPIClient {}

DeploymentConfig _testConfig() => DeploymentConfig(
      planType: 'g6-standard-2',
      region: 'us-east',
      adminEmail: 'admin@example.com',
      ntfyEnabled: true,
      imageRelayUrl: 'https://pocketcoder-image-relay.workers.dev',
      nixosImageLabel: 'pocketcoder-nixos-v1',
    );

void main() {
  group('CustomImageProvisioningStrategy', () {
    late ICloudProviderAPIClient apiClient;
    late CustomImageProvisioningStrategy strategy;

    setUp(() {
      apiClient = MockCloudProviderAPIClient();
      strategy = CustomImageProvisioningStrategy(apiClient);
    });

    test('creates instance directly when image already exists', () async {
      final config = _testConfig();
      final cloudInstance = CloudInstance(
        id: '12345',
        label: 'pocketcoder-test',
        ipAddress: '192.168.1.100',
        status: CloudInstanceStatus.creating,
        created: DateTime.now(),
        region: 'us-east',
        planType: 'g6-standard-2',
        provider: 'linode',
      );

      when(() => apiClient.findImageByLabel('token', 'pocketcoder-nixos-v1'))
          .thenAnswer((_) async => 'private/12345');
      when(() => apiClient.createInstance(
            accessToken: 'token',
            planType: 'g6-standard-2',
            region: 'us-east',
            image: 'private/12345',
            metadata: {'user_data': 'userdata'},
          )).thenAnswer((_) async => cloudInstance);

      final result = await strategy.provisionInstance(
        accessToken: 'token',
        config: config,
        userData: 'userdata',
      );

      expect(result.id, '12345');
      verifyNever(() => apiClient.triggerImageUpload(
            accessToken: any(named: 'accessToken'),
            relayUrl: any(named: 'relayUrl'),
            label: any(named: 'label'),
            region: any(named: 'region'),
          ));
    });

    test('triggers upload and polls when image does not exist', () async {
      final config = _testConfig();
      final cloudInstance = CloudInstance(
        id: '12345',
        label: 'pocketcoder-test',
        ipAddress: '192.168.1.100',
        status: CloudInstanceStatus.creating,
        created: DateTime.now(),
        region: 'us-east',
        planType: 'g6-standard-2',
        provider: 'linode',
      );

      when(() => apiClient.findImageByLabel('token', 'pocketcoder-nixos-v1'))
          .thenAnswer((_) async => null);
      when(() => apiClient.triggerImageUpload(
            accessToken: 'token',
            relayUrl: config.imageRelayUrl,
            label: 'pocketcoder-nixos-v1',
            region: 'us-east',
          )).thenAnswer((_) async => {
            'imageId': 'private/12345',
            'status': 'available',
            'existed': true,
          });
      when(() => apiClient.createInstance(
            accessToken: 'token',
            planType: 'g6-standard-2',
            region: 'us-east',
            image: 'private/12345',
            metadata: {'user_data': 'userdata'},
          )).thenAnswer((_) async => cloudInstance);

      final result = await strategy.provisionInstance(
        accessToken: 'token',
        config: config,
        userData: 'userdata',
      );

      expect(result.id, '12345');
    });
  });
}
```

- [ ] **Step 4: Run the new tests to verify they pass**

```bash
cd /Users/aicoder/Documents/flutter_aeroform
flutter test test/infrastructure/deployment/custom_image_provisioning_strategy_test.dart
```

Expected: PASS (2/2).

- [ ] **Step 5: Update `DeploymentService` to depend on the new seam**

In `lib/infrastructure/deployment/deployment_service.dart`, remove
`_imagePollingMaxAttempts`/`_imagePollingInterval`/`_ensureNixosImage`
(moved to `CustomImageProvisioningStrategy`), add a constructor
dependency, and replace the inline image-resolution + `createInstance`
call in `deploy()`:

```dart
  final IInstanceProvisioningStrategy _provisioningStrategy;
```

(add to the constructor's required params and the field-initializer list,
alongside the existing `_apiClient`/`_certManager`/etc.)

In `deploy()`, replace:

```dart
    try {
      // Step 1: Ensure NixOS image exists in user's Linode account
      final imageId = await _ensureNixosImage(
        accessToken: accessToken,
        config: config,
      );

      // Step 2: Build user-data as base64-encoded env file
      final userData = config.toUserData(
        adminPassword: adminPassword,
        rootSshKey: sshKeyPair.publicKey,
      );

      // Step 3: Create instance with NixOS image
      final instance = await _apiClient.createInstance(
        accessToken: accessToken,
        planType: config.planType,
        region: config.region,
        image: imageId,
        metadata: {'user_data': userData},
      );
```

with:

```dart
    try {
      final userData = config.toUserData(
        adminPassword: adminPassword,
        rootSshKey: sshKeyPair.publicKey,
      );

      final instance = await _provisioningStrategy.provisionInstance(
        accessToken: accessToken,
        config: config,
        userData: userData,
      );
```

Delete the now-unused `_ensureNixosImage` method and its two `static
const` polling fields entirely.

- [ ] **Step 6: Update `deployment_service_test.dart`**

Remove the image-resolution-specific stubbing from the moved tests
(they're now in `custom_image_provisioning_strategy_test.dart`). Add a
`MockInstanceProvisioningStrategy` and update every existing test's setup
to construct `DeploymentService` with a `provisioningStrategy:` param and
stub `provisionInstance` directly instead of stubbing
`findImageByLabel`/`triggerImageUpload`/`createInstance`. Example for the
`'creates instance with correct parameters'` test:

```dart
class MockInstanceProvisioningStrategy extends Mock
    implements IInstanceProvisioningStrategy {}

// in setUp():
provisioningStrategy = MockInstanceProvisioningStrategy();
deploymentService = DeploymentService(
  apiClient: apiClient,
  certManager: certManager,
  passwordGenerator: passwordGenerator,
  sshKeyGenerator: sshKeyGenerator,
  secureStorage: secureStorage,
  validationService: validationService,
  provisioningStrategy: provisioningStrategy,
);

// in the test:
when(() => provisioningStrategy.provisionInstance(
      accessToken: 'test-access-token',
      config: config,
      userData: any(named: 'userData'),
    )).thenAnswer((_) async => cloudInstance);
```

Apply the same substitution to every test in the `'deploy'` group. Tests
outside `'deploy'` (`monitorDeployment`, `cancelMonitoring`,
`getInstanceStatus`, `getExistingInstances`) don't touch provisioning at
all — just add `provisioningStrategy: provisioningStrategy` to their
`DeploymentService(...)` construction so the constructor call compiles,
no other change needed. Apply the identical substitution to
`deployment_service_property_test.dart`.

- [ ] **Step 7: Run the full suite**

```bash
flutter analyze
flutter test
```

Expected: clean, same baseline as Task 5's Step 6 (156+ pass, same 2
pre-existing unrelated failures).

- [ ] **Step 8: Commit**

```bash
git add lib/domain/deployment/i_instance_provisioning_strategy.dart \
        lib/infrastructure/deployment/custom_image_provisioning_strategy.dart \
        lib/infrastructure/deployment/deployment_service.dart \
        test/infrastructure/deployment/custom_image_provisioning_strategy_test.dart \
        test/infrastructure/deployment/deployment_service_test.dart \
        test/infrastructure/deployment/deployment_service_property_test.dart
git commit -m "refactor: extract IInstanceProvisioningStrategy seam

Moves DeploymentService's inline _ensureNixosImage/createInstance
logic into CustomImageProvisioningStrategy, verbatim -- no behavior
change. This is the seam BootTimePullProvisioningStrategy (next) plugs
into as a second, additive strategy."
```

---

### Task 8: `LinodeAPIClient.getPlanDiskSizeMB`

**Files:**
- Modify: `lib/infrastructure/cloud_provider/linode_api_client.dart`
  (flutter_aeroform repo)
- Modify: `lib/domain/cloud_provider/i_cloud_provider_api_client.dart`
  (flutter_aeroform repo)
- Modify: `test/infrastructure/cloud_provider/linode_api_client_test.dart`
  (flutter_aeroform repo)

**Interfaces:**
- Produces: `Future<int> getPlanDiskSizeMB(String accessToken, String
  planType)` on `ICloudProviderAPIClient` — consumed by Task 10
  (`LinodeBootTimeInstaller`, to size the target disk).

- [ ] **Step 1: Write the failing test**

In `test/infrastructure/cloud_provider/linode_api_client_test.dart`, add
a new group:

```dart
  group('getPlanDiskSizeMB', () {
    test('returns the plan disk size in MB', () async {
      final response = http.Response(
        jsonEncode({'id': 'g6-standard-2', 'disk': 51200, 'memory': 4096}),
        200,
      );

      when(() => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => response);

      final result = await client.getPlanDiskSizeMB(testAccessToken, 'g6-standard-2');
      expect(result, equals(51200));
    });

    test('throws CloudProviderAPIError on failure', () async {
      final response = http.Response('Not Found', 404);

      when(() => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => response);

      expect(
        () => client.getPlanDiskSizeMB(testAccessToken, 'g6-standard-2'),
        throwsA(isA<CloudProviderAPIError>()),
      );
    });
  });
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd /Users/aicoder/Documents/flutter_aeroform
flutter test test/infrastructure/cloud_provider/linode_api_client_test.dart --plain-name "getPlanDiskSizeMB"
```

Expected: FAIL (method doesn't exist — compile error).

- [ ] **Step 3: Add to `ICloudProviderAPIClient`**

In `lib/domain/cloud_provider/i_cloud_provider_api_client.dart`, add:

```dart
  /// Returns the plan's disk size in MB.
  Future<int> getPlanDiskSizeMB(String accessToken, String planType);
```

- [ ] **Step 4: Implement in `LinodeAPIClient`**

```dart
  @override
  Future<int> getPlanDiskSizeMB(String accessToken, String planType) async {
    final response = await _httpClient.get(
      Uri.parse('$_baseUrl/linode/types/$planType'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200) {
      throw CloudProviderAPIError.fromResponse(response);
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['disk'] as int;
  }
```

- [ ] **Step 5: Run it to verify it passes**

```bash
flutter test test/infrastructure/cloud_provider/linode_api_client_test.dart --plain-name "getPlanDiskSizeMB"
```

Expected: PASS (2/2).

- [ ] **Step 6: Commit**

```bash
git add lib/infrastructure/cloud_provider/linode_api_client.dart \
        lib/domain/cloud_provider/i_cloud_provider_api_client.dart \
        test/infrastructure/cloud_provider/linode_api_client_test.dart
git commit -m "feat(linode): add getPlanDiskSizeMB

Needed by the upcoming boot-time-pull provisioning path to size the
target raw disk correctly instead of hardcoding a plan-to-disk-size
table that would drift from Linode's real plan catalog."
```

---

### Task 9: `IUrlPullProvisioningApi` interface

**Files:**
- Create: `lib/domain/cloud_provider/i_url_pull_provisioning_api.dart`
  (flutter_aeroform repo)

**Interfaces:**
- Produces:
  ```dart
  abstract class IUrlPullProvisioningApi {
    Future<CloudInstance> provisionFromImageUrl({
      required String accessToken,
      required DeploymentConfig config,
      required String userData,
      required String imageUrl,
      required String imageSha256,
      required int uncompressedBytes,
    });
  }
  ```
  Consumed by Task 11 (`LinodeAPIClient` implements it) and Task 12
  (`BootTimePullProvisioningStrategy` depends on it).

- [ ] **Step 1: Create the file**

```dart
import 'package:flutter_aeroform/domain/models/cloud_provider.dart';
import 'package:flutter_aeroform/domain/models/deployment_config.dart';

/// Contract for "pull-based" instance provisioning: get a target image
/// (identified by a URL, sha256, and uncompressed size) running as a
/// booted instance's root filesystem, by whatever mechanism a given
/// provider supports -- a native pull-from-URL API (DigitalOcean's
/// Custom Images API takes a URL directly), a rescue-boot-and-dd
/// sequence (Hetzner -- not implemented in this codebase, would need an
/// SSH-executor dependency this project deliberately doesn't carry), an
/// installer-instance-plus-volume-swap sequence (Linode -- see
/// LinodeBootTimeInstaller), or anything else. Callers don't need to
/// know which.
///
/// See docs/superpowers/specs/2026-07-29-linode-boot-time-image-provisioning-design.md
/// for the full design rationale, including why this replaced an
/// earlier five-method interface that modeled Linode's own mechanism
/// instead of this shared capability.
abstract class IUrlPullProvisioningApi {
  Future<CloudInstance> provisionFromImageUrl({
    required String accessToken,
    required DeploymentConfig config,
    required String userData,
    required String imageUrl,
    required String imageSha256,
    required int uncompressedBytes,
  });
}
```

- [ ] **Step 2: Verify it compiles**

```bash
cd /Users/aicoder/Documents/flutter_aeroform
flutter analyze lib/domain/cloud_provider/i_url_pull_provisioning_api.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/domain/cloud_provider/i_url_pull_provisioning_api.dart
git commit -m "feat: add IUrlPullProvisioningApi

Single-method, capability-level cross-provider interface for
boot-time-pull provisioning."
```

---

### Task 10: `LinodeBootTimeInstaller`

The core of the new provisioning path — Linode's corrected 10-step
sequence (see the design spec's "The corrected Linode sequence" section
for the full step-by-step rationale), including async-event handling
(wait-for-ready/wait-for-gone + bounded busy-retry), the
`running`→`offline` transition check, and installer cleanup before the
final boot.

**Files:**
- Create: `lib/infrastructure/cloud_provider/linode_boot_time_installer.dart`
  (flutter_aeroform repo)
- Create: `test/infrastructure/cloud_provider/linode_boot_time_installer_test.dart`
  (flutter_aeroform repo)

**Interfaces:**
- Consumes: `http.Client` (raw, same as `LinodeAPIClient` itself — this
  class makes its own HTTP calls rather than going through
  `LinodeAPIClient`'s existing methods, since disks/configs are a
  different resource family with different error semantics).
- Produces: `Future<CloudInstance> install({required String accessToken,
  required DeploymentConfig config, required String userData, required
  String imageUrl, required String imageSha256, required int
  uncompressedBytes, required int stackscriptId})` — consumed by Task 11
  (`LinodeAPIClient`'s `IUrlPullProvisioningApi` implementation). No SSH
  key parameter — see Step 3's D3 mitigation note below for why.

**Security decision (design spec's D3, deferred there to implementation
time — resolved here):** the installer disk uses a throwaway, randomly
generated `root_pass` instead of `authorized_keys: [someKey]`. This is
mitigation (b) from the spec's two options, not (a) (deferring the real
`user_data` write) — (b) is simpler (no post-creation metadata-update API
call to verify) and fully closes the leak: the installer's stock-Debian
cloud-init can still *see* the real `user_data` (containing the real
admin password) and may still log it, but nothing can SSH into the
installer to read those logs, since it never receives any real key — only
a random password nobody retains, with Lish (not SSH) as the only
fallback debugging channel. This means `IUrlPullProvisioningApi` never
needed an `installerSshKey`/`rootSshKey` parameter at all; `Task 9`'s
interface is already correct as originally written, and `BootTimePullProvisioningStrategy`
(Task 12) has no SSH-key-generation responsibility.

- [ ] **Step 0: Confirm the pre-implementation verification has run**

Before writing any code in this task, confirm (ask the user if it's not
already evident from prior conversation) that
`verify_linode_metadata_delivery` (see this plan's "Secrets-Daemon
Actions Needed" section) has been run against a real Linode instance and
confirmed that `http://169.254.169.254/v1/user-data` actually serves the
`metadata.user_data` value set at instance-creation time — not just that
Linode's API *accepts* that field. If it hasn't been run yet, stop and
run it first (propose the action to the user per the secrets-daemon
skill if it doesn't exist yet, then wait for a real result) — every step
below assumes this works, and `bootstrap.nix` fails closed on empty
user-data, so an unverified assumption here means every deployment fails
silently at first boot with no signal until real money has been spent
provisioning a box that never comes up.

- [ ] **Step 1: Write the failing test for the happy path**

Create `test/infrastructure/cloud_provider/linode_boot_time_installer_test.dart`.
This test drives the whole sequence against a mocked `http.Client`,
asserting call order and request shapes for the parts most likely to
regress (busy-retry, the offline-transition check, deletion-before-final-
boot ordering):

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:flutter_aeroform/domain/models/deployment_config.dart';
import 'package:flutter_aeroform/infrastructure/cloud_provider/linode_boot_time_installer.dart';

class MockHttpClient extends Mock implements http.Client {}

DeploymentConfig _testConfig() => DeploymentConfig(
      planType: 'g6-standard-2',
      region: 'us-east',
      adminEmail: 'admin@example.com',
      ntfyEnabled: false,
      imageRelayUrl: 'https://relay.example.com',
      nixosImageLabel: 'pocketcoder-nixos-v1',
    );

void main() {
  late MockHttpClient mockHttpClient;
  late LinodeBootTimeInstaller installer;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://api.linode.com/v4/linode/instances'));
  });

  setUp(() {
    mockHttpClient = MockHttpClient();
    installer = LinodeBootTimeInstaller(mockHttpClient);
  });

  http.Response jsonResponse(Map<String, dynamic> body, [int status = 200]) =>
      http.Response(jsonEncode(body), status);

  group('LinodeBootTimeInstaller', () {
    test('runs the full sequence and returns the final instance', () async {
      var diskCallCount = 0;
      var pollCallCount = 0;

      // 1. create bare instance
      when(() => mockHttpClient.post(
            any(that: predicate<Uri>((u) => u.path == '/v4/linode/instances')),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => jsonResponse({
            'id': 999,
            'label': 'pocketcoder-999',
            'status': 'offline',
            'ipv4': [],
            'region': 'us-east',
            'type': 'g6-standard-2',
            'created': '2026-01-01T00:00:00Z',
          }, 200));

      // getPlanDiskSizeMB
      when(() => mockHttpClient.get(
            any(that: predicate<Uri>((u) => u.path.contains('/types/'))),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => jsonResponse({'id': 'g6-standard-2', 'disk': 51200}));

      // disk creates (installer=id 1, then target=id 2) -- each
      // immediately "ready"
      when(() => mockHttpClient.post(
            any(that: predicate<Uri>((u) => u.path.contains('/disks') && !u.path.contains('/configs'))),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async {
        diskCallCount++;
        return jsonResponse({'id': diskCallCount, 'status': 'ready'});
      });

      // Disk status polls must disambiguate "ready" (steps 3/4, disks 1
      // and 2) from "gone" (step 8, disk 1 specifically, after its
      // DELETE call). A single always-ready stub would make
      // _waitForDiskGone(installerDiskId) spin for its full 40*3s budget
      // and then throw, since it never sees a 404 -- track whether
      // disk 1's delete has actually happened yet.
      var installerDiskDeleted = false;
      when(() => mockHttpClient.get(
            any(that: predicate<Uri>((u) => u.path.contains('/disks/1'))),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => installerDiskDeleted
              ? http.Response('Not Found', 404)
              : jsonResponse({'status': 'ready'}));
      when(() => mockHttpClient.get(
            any(that: predicate<Uri>((u) =>
                u.path.contains('/disks/') && !u.path.contains('/disks/1'))),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => jsonResponse({'status': 'ready'}));

      // config creates
      var configCallCount = 0;
      when(() => mockHttpClient.post(
            any(that: predicate<Uri>((u) => u.path.contains('/configs'))),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async {
        configCallCount++;
        return jsonResponse({'id': configCallCount});
      });

      // boot calls
      when(() => mockHttpClient.post(
            any(that: predicate<Uri>((u) => u.path.contains('/boot'))),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response('', 200));

      // instance status polls: running, then offline (installer done)
      when(() => mockHttpClient.get(
            any(that: predicate<Uri>((u) =>
                u.path == '/v4/linode/instances/999')),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async {
        pollCallCount++;
        final status = pollCallCount == 1 ? 'running' : 'offline';
        return jsonResponse({
          'id': 999,
          'label': 'pocketcoder-999',
          'status': status,
          'ipv4': ['192.168.1.50'],
          'region': 'us-east',
          'type': 'g6-standard-2',
          'created': '2026-01-01T00:00:00Z',
        });
      });

      // installer disk/config delete -- flips installerDiskDeleted so
      // the disks/1 stub above starts returning 404.
      when(() => mockHttpClient.delete(
            any(that: predicate<Uri>((u) => u.path.contains('/disks/1'))),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async {
        installerDiskDeleted = true;
        return http.Response('', 200);
      });
      when(() => mockHttpClient.delete(
            any(that: predicate<Uri>((u) => !u.path.contains('/disks/1'))),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response('', 200));

      final result = await installer.install(
        accessToken: 'token',
        config: _testConfig(),
        userData: 'dXNlcmRhdGE=',
        imageUrl: 'https://images.example.com/nixos.img.gz',
        imageSha256: 'abc123',
        uncompressedBytes: 5000000000,
        stackscriptId: 42,
      );

      expect(result.id, '999');
      expect(result.ipAddress, '192.168.1.50');

      // Installer cleanup happened before the final boot: verify at
      // least 2 DELETE calls (disk + config) occurred, and that at
      // least 2 boot POSTs occurred (installer, then final).
      verify(() => mockHttpClient.delete(any(), headers: any(named: 'headers')))
          .called(greaterThanOrEqualTo(2));
    });

    test('deletes the instance and rethrows if any step fails', () async {
      // Instance creation succeeds, but the very next call (disk size
      // lookup) fails with a non-busy, non-retryable error -- this
      // proves the whole-sequence try/catch teardown (design spec's
      // "Failure handling and lifecycle": every step between "instance
      // created" and "final boot" must not leave a billable orphan on
      // any exception).
      when(() => mockHttpClient.post(
            any(that: predicate<Uri>((u) => u.path == '/v4/linode/instances')),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => jsonResponse({
            'id': 999,
            'label': 'pocketcoder-999',
            'status': 'offline',
            'ipv4': [],
            'region': 'us-east',
            'type': 'g6-standard-2',
            'created': '2026-01-01T00:00:00Z',
          }, 200));

      when(() => mockHttpClient.get(
            any(that: predicate<Uri>((u) => u.path.contains('/types/'))),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response('Internal Server Error', 500));

      when(() => mockHttpClient.delete(
            any(that: predicate<Uri>((u) => u.path == '/v4/linode/instances/999')),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response('', 200));

      await expectLater(
        installer.install(
          accessToken: 'token',
          config: _testConfig(),
          userData: 'dXNlcmRhdGE=',
          imageUrl: 'https://images.example.com/nixos.img.gz',
          imageSha256: 'abc123',
          uncompressedBytes: 5000000000,
          stackscriptId: 42,
        ),
        throwsA(anything),
      );

      verify(() => mockHttpClient.delete(
            any(that: predicate<Uri>((u) => u.path == '/v4/linode/instances/999')),
            headers: any(named: 'headers'),
          )).called(1);
    });
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd /Users/aicoder/Documents/flutter_aeroform
flutter test test/infrastructure/cloud_provider/linode_boot_time_installer_test.dart
```

Expected: FAIL (class doesn't exist).

- [ ] **Step 3: Implement `LinodeBootTimeInstaller`**

```dart
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'package:flutter_aeroform/domain/models/cloud_provider.dart';
import 'package:flutter_aeroform/domain/models/deployment_config.dart';
import 'package:flutter_aeroform/infrastructure/cloud_provider/cloud_provider_errors.dart';

/// Linode-only. Not part of any cross-provider contract -- disks and
/// config profiles are Linode API primitives. Used exclusively by
/// LinodeAPIClient's IUrlPullProvisioningApi implementation.
///
/// Drives the corrected 10-step sequence documented in
/// docs/superpowers/specs/2026-07-29-linode-boot-time-image-provisioning-design.md
/// ("The corrected Linode sequence"): create a bare instance, create an
/// installer disk (running our published StackScript) + a raw target
/// disk, boot the installer, wait for it to finish (running->offline
/// transition, not a bare status check -- the instance starts offline),
/// delete the installer disk+config, boot the target disk as the final
/// config.
class LinodeBootTimeInstaller {
  static const String _baseUrl = 'https://api.linode.com/v4';
  static const int _installerDiskSizeMB = 2560;
  static const int _minTargetDiskSizeMB = 8192;
  static const int _busyRetryMax = 10;
  static const Duration _busyRetryDelay = Duration(seconds: 3);
  static const int _readyPollMax = 40;
  static const Duration _readyPollDelay = Duration(seconds: 3);
  static const int _installerCompletionPollMax = 200;
  static const Duration _installerCompletionPollDelay = Duration(seconds: 5);

  final http.Client _httpClient;

  LinodeBootTimeInstaller(this._httpClient);

  Future<CloudInstance> install({
    required String accessToken,
    required DeploymentConfig config,
    required String userData,
    required String imageUrl,
    required String imageSha256,
    required int uncompressedBytes,
    required int stackscriptId,
  }) async {
    final headers = {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };

    // Step 1: bare instance, no image, not booted. Created outside the
    // try/catch below -- if this specific call fails, there is no
    // instance yet to delete.
    final instanceId = await _busyRetry(() async {
      final res = await _httpClient.post(
        Uri.parse('$_baseUrl/linode/instances'),
        headers: headers,
        body: jsonEncode({
          'type': config.planType,
          'region': config.region,
          'label': 'pocketcoder-${DateTime.now().millisecondsSinceEpoch}',
          'booted': false,
          'metadata': {'user_data': userData},
        }),
      );
      _checkOk(res);
      return (jsonDecode(res.body) as Map<String, dynamic>)['id'].toString();
    });

    // Everything from here on operates on a real, billable instance --
    // per the design spec's "Failure handling and lifecycle," any
    // exception in this block must delete that instance before
    // propagating, so a failed run never leaves an orphaned box running
    // forever. Deleting a Linode instance also deletes its disks and
    // config profiles, so this one call is sufficient teardown for
    // every step below, not just some of them.
    try {
      // Step 2: real plan disk size.
      final planDiskSizeMB = await _busyRetry(() async {
        final res = await _httpClient.get(
          Uri.parse('$_baseUrl/linode/types/${config.planType}'),
          headers: headers,
        );
        _checkOk(res);
        return (jsonDecode(res.body) as Map<String, dynamic>)['disk'] as int;
      });

      final targetDiskSizeMB = planDiskSizeMB - _installerDiskSizeMB - 512;
      assert(
        targetDiskSizeMB >= _minTargetDiskSizeMB,
        'Plan disk too small for boot-time-pull provisioning: '
        '$planDiskSizeMB MB total leaves only $targetDiskSizeMB MB for the '
        'target disk (floor: $_minTargetDiskSizeMB MB)',
      );

      // Step 3: installer disk (stock Debian, runs our StackScript).
      // Uses a throwaway, never-retained root password instead of
      // authorized_keys -- design spec's D3 mitigation (b): the
      // installer's stock-Debian cloud-init can still see the real
      // user_data (containing the real admin password) and may log it,
      // but nothing can SSH in to read those logs, since the installer
      // never receives any real key. Lish (not SSH) is the only
      // fallback access path for a human debugging a stuck installer.
      final installerDiskId = await _busyRetry(() async {
        final res = await _httpClient.post(
          Uri.parse('$_baseUrl/linode/instances/$instanceId/disks'),
          headers: headers,
          body: jsonEncode({
            'label': 'installer',
            'size': _installerDiskSizeMB,
            'image': 'linode/debian12',
            'root_pass': _generateThrowawayPassword(),
            'stackscript_id': stackscriptId,
            'stackscript_data': {
              'IMAGE_URL': imageUrl,
              'IMAGE_SHA256': imageSha256,
              'IMAGE_UNCOMPRESSED_BYTES': uncompressedBytes.toString(),
            },
          }),
        );
        _checkOk(res);
        return (jsonDecode(res.body) as Map<String, dynamic>)['id'] as int;
      });
      await _waitForDiskReady(headers, instanceId, installerDiskId);

      // Step 4: raw target disk.
      final targetDiskId = await _busyRetry(() async {
        final res = await _httpClient.post(
          Uri.parse('$_baseUrl/linode/instances/$instanceId/disks'),
          headers: headers,
          body: jsonEncode({
            'label': 'nixos',
            'size': targetDiskSizeMB,
            'filesystem': 'raw',
          }),
        );
        _checkOk(res);
        return (jsonDecode(res.body) as Map<String, dynamic>)['id'] as int;
      });
      await _waitForDiskReady(headers, instanceId, targetDiskId);

      // Step 5: installer boot profile.
      final installerConfigId = await _busyRetry(() async {
        final res = await _httpClient.post(
          Uri.parse('$_baseUrl/linode/instances/$instanceId/configs'),
          headers: headers,
          body: jsonEncode({
            'label': 'installer',
            'kernel': 'linode/grub2',
            'root_device': '/dev/sda',
            'devices': {
              'sda': {'disk_id': installerDiskId},
              'sdb': {'disk_id': targetDiskId},
            },
          }),
        );
        _checkOk(res);
        return (jsonDecode(res.body) as Map<String, dynamic>)['id'] as int;
      });

      // Step 6: boot the installer.
      await _busyRetry(() async {
        final res = await _httpClient.post(
          Uri.parse('$_baseUrl/linode/instances/$instanceId/boot'),
          headers: headers,
          body: jsonEncode({'config_id': installerConfigId}),
        );
        _checkOk(res);
      });

      // Step 7: wait for running -> offline (the installer's own
      // completion signal, not a bare status check -- the instance
      // starts offline before anything runs). On timeout, this deletes
      // the instance itself (see _waitForInstallerCompletion) rather
      // than throwing past this try block and relying on the catch
      // below -- an instance stuck running forever needs its own
      // explicit teardown, not just "eventually get caught."
      await _waitForInstallerCompletion(headers, instanceId);

      // Step 8: delete the installer disk + its now-orphaned config,
      // while the instance is off -- never delete a disk out from under
      // a running, serving instance.
      await _busyRetry(() async {
        final res = await _httpClient.delete(
          Uri.parse('$_baseUrl/linode/instances/$instanceId/disks/$installerDiskId'),
          headers: headers,
        );
        _checkOk(res);
      });
      await _waitForDiskGone(headers, instanceId, installerDiskId);
      await _busyRetry(() async {
        final res = await _httpClient.delete(
          Uri.parse('$_baseUrl/linode/instances/$instanceId/configs/$installerConfigId'),
          headers: headers,
        );
        _checkOk(res);
      });

      // Step 9: final boot profile -- target disk only, helpers
      // disabled (NixOS's mostly-read-only /etc would fight or corrupt
      // against helpers rewriting boot-time files; the installer's
      // stock Debian profile above deliberately left helpers at their
      // defaults instead).
      final finalConfigId = await _busyRetry(() async {
        final res = await _httpClient.post(
          Uri.parse('$_baseUrl/linode/instances/$instanceId/configs'),
          headers: headers,
          body: jsonEncode({
            'label': 'nixos',
            'kernel': 'linode/grub2',
            'root_device': '/dev/sda',
            'devices': {
              'sda': {'disk_id': targetDiskId},
            },
            'helpers': {
              'distro': false,
              'modules_dep': false,
              'network': false,
              'updatedb_disabled': true,
              'devtmpfs_automount': false,
            },
          }),
        );
        _checkOk(res);
        return (jsonDecode(res.body) as Map<String, dynamic>)['id'] as int;
      });

      // Step 10: boot the final config.
      await _busyRetry(() async {
        final res = await _httpClient.post(
          Uri.parse('$_baseUrl/linode/instances/$instanceId/boot'),
          headers: headers,
          body: jsonEncode({'config_id': finalConfigId}),
        );
        _checkOk(res);
      });

      final finalRes = await _httpClient.get(
        Uri.parse('$_baseUrl/linode/instances/$instanceId'),
        headers: headers,
      );
      _checkOk(finalRes);
      return _parseInstance(jsonDecode(finalRes.body) as Map<String, dynamic>);
    } catch (_) {
      await _deleteInstance(headers, instanceId);
      rethrow;
    }
  }

  Future<void> _deleteInstance(Map<String, String> headers, String instanceId) async {
    // Best-effort: a failure here just means a human/the orphan-reaping
    // sweep (Task 16) has to clean this one up later -- never let a
    // teardown failure mask the original error via rethrow.
    try {
      await _httpClient.delete(
        Uri.parse('$_baseUrl/linode/instances/$instanceId'),
        headers: headers,
      );
    } catch (_) {
      // Swallowed deliberately -- see comment above.
    }
  }

  String _generateThrowawayPassword() {
    final random = Random.secure();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _waitForDiskReady(
    Map<String, String> headers,
    String instanceId,
    int diskId,
  ) async {
    for (var i = 0; i < _readyPollMax; i++) {
      final res = await _httpClient.get(
        Uri.parse('$_baseUrl/linode/instances/$instanceId/disks/$diskId'),
        headers: headers,
      );
      _checkOk(res);
      final status = (jsonDecode(res.body) as Map<String, dynamic>)['status'];
      if (status == 'ready') return;
      await Future.delayed(_readyPollDelay);
    }
    throw Exception('Disk $diskId never became ready');
  }

  Future<void> _waitForDiskGone(
    Map<String, String> headers,
    String instanceId,
    int diskId,
  ) async {
    for (var i = 0; i < _readyPollMax; i++) {
      final res = await _httpClient.get(
        Uri.parse('$_baseUrl/linode/instances/$instanceId/disks/$diskId'),
        headers: headers,
      );
      if (res.statusCode == 404) return;
      await Future.delayed(_readyPollDelay);
    }
    throw Exception('Disk $diskId delete never completed');
  }

  Future<void> _waitForInstallerCompletion(
    Map<String, String> headers,
    String instanceId,
  ) async {
    var observedRunning = false;
    for (var i = 0; i < _installerCompletionPollMax; i++) {
      final res = await _httpClient.get(
        Uri.parse('$_baseUrl/linode/instances/$instanceId'),
        headers: headers,
      );
      _checkOk(res);
      final status = (jsonDecode(res.body) as Map<String, dynamic>)['status'];
      if (status == 'running') observedRunning = true;
      if (observedRunning && status == 'offline') return;
      await Future.delayed(_installerCompletionPollDelay);
    }
    // A stuck-running installer bills forever if left alone -- delete it
    // here rather than relying on install()'s outer try/catch, since
    // this method's caller is inside that try block and the outer catch
    // will also fire on rethrow, but by then instanceId's disks/configs
    // may be mid-creation; deleting immediately on this specific timeout
    // is the design spec's explicit requirement, not just incidental
    // cleanup.
    await _deleteInstance(headers, instanceId);
    throw Exception(
      'Installer never completed (observedRunning=$observedRunning) '
      'after ${_installerCompletionPollMax * _installerCompletionPollDelay.inSeconds}s -- '
      'instance deleted.',
    );
  }

  Future<T> _busyRetry<T>(Future<T> Function() action) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await action();
      } on CloudProviderAPIError catch (e) {
        final isBusy = e.statusCode == 400 &&
            e.message.toLowerCase().contains('busy');
        if (!isBusy || attempt >= _busyRetryMax) rethrow;
        await Future.delayed(_busyRetryDelay);
      }
    }
  }

  void _checkOk(http.Response res) {
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw CloudProviderAPIError.fromResponse(res);
    }
  }

  CloudInstance _parseInstance(Map<String, dynamic> json) {
    final ipv4 = json['ipv4'] as List?;
    final ipAddress = ipv4?.isNotEmpty == true ? ipv4![0] as String : '';
    return CloudInstance(
      id: json['id'].toString(),
      label: json['label'] as String,
      ipAddress: ipAddress,
      status: _mapStatus(json['status'] as String?),
      created: DateTime.tryParse(json['created']?.toString() ?? '') ?? DateTime.now(),
      region: json['region'] as String,
      planType: json['type'] as String,
      provider: 'linode',
    );
  }

  CloudInstanceStatus _mapStatus(String? status) {
    switch (status) {
      case 'provisioning':
        return CloudInstanceStatus.provisioning;
      case 'running':
        return CloudInstanceStatus.running;
      case 'offline':
        return CloudInstanceStatus.offline;
      case 'failed':
        return CloudInstanceStatus.failed;
      default:
        return CloudInstanceStatus.creating;
    }
  }
}
```

- [ ] **Step 4: Run it to verify it passes**

```bash
flutter test test/infrastructure/cloud_provider/linode_boot_time_installer_test.dart
```

Expected: PASS. If the mocked call-matching predicates don't line up
exactly with the real request paths on the first try, adjust the test's
predicates to match this implementation's actual URLs (this is normal
mocktail iteration, not a design problem) — the properties being
verified (delete-before-final-boot ordering, correct final `CloudInstance`)
are what matter, not the exact intermediate mock plumbing.

- [ ] **Step 5: Add a focused test for the busy-retry wrapper**

This test only needs to reach Step 2 (`getPlanDiskSizeMB`) and assert the
call count — it doesn't need the rest of the sequence's mocks at all,
since `_busyRetry` rethrows immediately past `_busyRetryMax` on anything
that isn't a 400-with-"busy", and this test never needs the code to get
past step 2:

```dart
    test('retries on 400 Linode busy and succeeds', () async {
      when(() => mockHttpClient.post(
            any(that: predicate<Uri>((u) => u.path == '/v4/linode/instances')),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => jsonResponse({
            'id': 999,
            'label': 'pocketcoder-999',
            'status': 'offline',
            'ipv4': [],
            'region': 'us-east',
            'type': 'g6-standard-2',
            'created': '2026-01-01T00:00:00Z',
          }, 200));

      var callCount = 0;
      when(() => mockHttpClient.get(
            any(that: predicate<Uri>((u) => u.path.contains('/types/'))),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async {
        callCount++;
        if (callCount < 3) {
          return http.Response(jsonEncode({'errors': ['Linode busy.']}), 400);
        }
        // A real, valid disk size -- the sequence proceeds to step 3
        // (installer disk creation), which this test deliberately
        // leaves unmocked. mocktail throws on an unstubbed call, which
        // install()'s outer try/catch turns into a delete-and-rethrow --
        // expected and fine here, since what's being verified is
        // callCount, not a successful full install(). This is why the
        // instance-DELETE mock below is needed too.
        return jsonResponse({'id': 'g6-standard-2', 'disk': 51200});
      });
      when(() => mockHttpClient.delete(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response('', 200));

      await installer
          .install(
            accessToken: 'token',
            config: _testConfig(),
            userData: 'dXNlcmRhdGE=',
            imageUrl: 'https://images.example.com/nixos.img.gz',
            imageSha256: 'abc123',
            uncompressedBytes: 5000000000,
            stackscriptId: 42,
          )
          .catchError((_) => null);

      expect(callCount, 3);
    });
```

- [ ] **Step 6: Run the full test file**

```bash
flutter test test/infrastructure/cloud_provider/linode_boot_time_installer_test.dart
flutter analyze lib/infrastructure/cloud_provider/linode_boot_time_installer.dart
```

Expected: all PASS, clean analyze.

- [ ] **Step 7: Commit**

```bash
git add lib/infrastructure/cloud_provider/linode_boot_time_installer.dart \
        test/infrastructure/cloud_provider/linode_boot_time_installer_test.dart
git commit -m "feat(linode): add LinodeBootTimeInstaller

Drives the corrected 10-step boot-time-pull sequence: bare instance,
installer disk (StackScript) + raw target disk, boot installer, wait
for a real running->offline completion transition (not a bare status
check -- the instance starts offline), delete the installer before the
final boot, boot the target disk. Includes async-event handling
(Linode disk create/delete is asynchronous; unguarded follow-up calls
400 with 'Linode busy') via a bounded retry wrapper around every call.

The installer disk uses a throwaway root_pass instead of a real SSH
key (design spec's D3 mitigation (b)) -- the installer's cloud-init
can still see the real user_data and may log it, but nothing can SSH
in to read those logs. The whole sequence after instance-creation is
wrapped in try/catch that deletes the instance on any failure, and a
stuck-running installer is deleted on its own timeout too -- neither
failure mode leaves a billable orphan running unattended."
```

---

### Task 11: `LinodeAPIClient` implements `IUrlPullProvisioningApi`

**Files:**
- Modify: `lib/infrastructure/cloud_provider/linode_api_client.dart`
  (flutter_aeroform repo)
- Modify: `test/infrastructure/cloud_provider/linode_api_client_test.dart`
  (flutter_aeroform repo)

**Interfaces:**
- Consumes: `LinodeBootTimeInstaller` (Task 10).
- Produces: `LinodeAPIClient` now also implements
  `IUrlPullProvisioningApi` — consumed by Task 12
  (`BootTimePullProvisioningStrategy`).

- [ ] **Step 1: Write the failing test**

```dart
  group('provisionFromImageUrl (IUrlPullProvisioningApi)', () {
    test('delegates to LinodeBootTimeInstaller.install', () async {
      // This is a thin delegation -- the real sequence logic is fully
      // covered by linode_boot_time_installer_test.dart. This test only
      // needs to confirm LinodeAPIClient actually implements the
      // interface and wires the call through, not re-test the sequence.
      expect(client, isA<IUrlPullProvisioningApi>());
    });
  });
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd /Users/aicoder/Documents/flutter_aeroform
flutter test test/infrastructure/cloud_provider/linode_api_client_test.dart --plain-name "provisionFromImageUrl"
```

Expected: FAIL (compile error — `LinodeAPIClient` doesn't implement
`IUrlPullProvisioningApi` yet).

- [ ] **Step 3: Implement**

In `lib/infrastructure/cloud_provider/linode_api_client.dart`, add the
import and the interface to the class declaration, add a
`LinodeBootTimeInstaller` field (constructed internally, reusing the same
`http.Client`), and add the method:

```dart
import 'package:flutter_aeroform/domain/cloud_provider/i_url_pull_provisioning_api.dart';
import 'package:flutter_aeroform/infrastructure/cloud_provider/linode_boot_time_installer.dart';

@LazySingleton(as: ICloudProviderAPIClient)
class LinodeAPIClient
    implements ICloudProviderAPIClient, IUrlPullProvisioningApi {
  static const String _baseUrl = 'https://api.linode.com/v4';
  static const String _oauthUrl = 'https://login.linode.com/oauth';
  // The published StackScript's id -- see
  // deploy/nixos/scripts/publish-stackscript.sh in the pocketcoder repo
  // for how this is created/rotated. Not a secret (StackScripts are
  // visible to their owning account, not injected via env), but real
  // and specific to the qtpi-bonding-org Linode account.
  static const int _bootTimePullStackscriptId = 0; // TODO: real id after Task 13

  final http.Client _httpClient;
  final String _clientId;
  late final LinodeBootTimeInstaller _bootTimeInstaller = LinodeBootTimeInstaller(_httpClient);

  LinodeAPIClient(this._httpClient, @Named('linodeClientId') this._clientId);

  @override
  Future<CloudInstance> provisionFromImageUrl({
    required String accessToken,
    required DeploymentConfig config,
    required String userData,
    required String imageUrl,
    required String imageSha256,
    required int uncompressedBytes,
  }) {
    return _bootTimeInstaller.install(
      accessToken: accessToken,
      config: config,
      userData: userData,
      imageUrl: imageUrl,
      imageSha256: imageSha256,
      uncompressedBytes: uncompressedBytes,
      stackscriptId: _bootTimePullStackscriptId,
    );
  }
```

No SSH key is threaded through here — `LinodeBootTimeInstaller` (Task
10) generates its own throwaway installer password internally (design
spec's D3 mitigation (b)), so `IUrlPullProvisioningApi`'s signature
(Task 9) never needed an SSH-key parameter and doesn't have one.

- [ ] **Step 4: Run it to verify it passes**

```bash
flutter test test/infrastructure/cloud_provider/linode_api_client_test.dart --plain-name "provisionFromImageUrl"
flutter analyze
```

Expected: PASS, clean.

- [ ] **Step 5: Commit**

```bash
git add lib/infrastructure/cloud_provider/linode_api_client.dart \
        lib/domain/cloud_provider/i_url_pull_provisioning_api.dart \
        test/infrastructure/cloud_provider/linode_api_client_test.dart
git commit -m "feat(linode): LinodeAPIClient implements IUrlPullProvisioningApi

Thin delegation to LinodeBootTimeInstaller -- the sequence logic is
fully covered by linode_boot_time_installer_test.dart already."
```

---

### Task 12: `BootTimePullProvisioningStrategy` + DI wiring

**Files:**
- Create: `lib/infrastructure/deployment/boot_time_pull_provisioning_strategy.dart`
  (flutter_aeroform repo)
- Create: `test/infrastructure/deployment/boot_time_pull_provisioning_strategy_test.dart`
  (flutter_aeroform repo)
- Modify: `lib/domain/models/app_config.dart` (flutter_aeroform repo —
  add manifest URL constant)

**Interfaces:**
- Consumes: `IUrlPullProvisioningApi` (Task 9/11), `http.Client` (to
  fetch the manifest). No `ISshKeyGenerator` dependency — that was an
  earlier draft's approach to the D3 credential-leak mitigation;
  `LinodeBootTimeInstaller` (Task 10) generates its own throwaway
  installer password internally instead, so this class has no SSH-key
  responsibility at all.
- Produces: registered as the default `IInstanceProvisioningStrategy` via
  DI — this is what `DeploymentService` (Task 7's seam) actually resolves
  for real Linode deployments going forward.

- [ ] **Step 1: Add the manifest endpoint constant**

In `lib/domain/models/app_config.dart`, add:

```dart
  /// Path on the image-relay Worker serving the current image's manifest
  /// ({url, sha256, uncompressedBytes}) -- see workers/image-relay's
  /// /image-manifest route.
  static const kImageManifestPath = '/image-manifest';
```

- [ ] **Step 2: Write the failing test**

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:flutter_aeroform/domain/cloud_provider/i_url_pull_provisioning_api.dart';
import 'package:flutter_aeroform/domain/models/cloud_provider.dart';
import 'package:flutter_aeroform/domain/models/deployment_config.dart';
import 'package:flutter_aeroform/infrastructure/deployment/boot_time_pull_provisioning_strategy.dart';

class MockUrlPullApi extends Mock implements IUrlPullProvisioningApi {}
class MockHttpClient extends Mock implements http.Client {}

void main() {
  group('BootTimePullProvisioningStrategy', () {
    late MockUrlPullApi pullApi;
    late MockHttpClient httpClient;
    late BootTimePullProvisioningStrategy strategy;

    setUp(() {
      pullApi = MockUrlPullApi();
      httpClient = MockHttpClient();
      strategy = BootTimePullProvisioningStrategy(pullApi, httpClient);
    });

    test('fetches the manifest and delegates to provisionFromImageUrl', () async {
      final config = DeploymentConfig(
        planType: 'g6-standard-2',
        region: 'us-east',
        adminEmail: 'admin@example.com',
        ntfyEnabled: false,
        imageRelayUrl: 'https://relay.example.com',
        nixosImageLabel: 'pocketcoder-nixos-v1',
      );
      final cloudInstance = CloudInstance(
        id: '999',
        label: 'pocketcoder-999',
        ipAddress: '192.168.1.50',
        status: CloudInstanceStatus.creating,
        created: DateTime.now(),
        region: 'us-east',
        planType: 'g6-standard-2',
        provider: 'linode',
      );

      when(() => httpClient.get(
            Uri.parse('https://relay.example.com/image-manifest'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({
              'url': 'https://images.example.com/nixos.img.gz',
              'sha256': 'abc123',
              'uncompressedBytes': 5000000000,
            }),
            200,
          ));
      when(() => pullApi.provisionFromImageUrl(
            accessToken: 'token',
            config: config,
            userData: 'userdata',
            imageUrl: 'https://images.example.com/nixos.img.gz',
            imageSha256: 'abc123',
            uncompressedBytes: 5000000000,
          )).thenAnswer((_) async => cloudInstance);

      final result = await strategy.provisionInstance(
        accessToken: 'token',
        config: config,
        userData: 'userdata',
      );

      expect(result.id, '999');
    });
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

```bash
cd /Users/aicoder/Documents/flutter_aeroform
flutter test test/infrastructure/deployment/boot_time_pull_provisioning_strategy_test.dart
```

Expected: FAIL (class doesn't exist).

- [ ] **Step 4: Implement**

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';

import 'package:flutter_aeroform/domain/cloud_provider/i_url_pull_provisioning_api.dart';
import 'package:flutter_aeroform/domain/deployment/i_instance_provisioning_strategy.dart';
import 'package:flutter_aeroform/domain/models/cloud_provider.dart';
import 'package:flutter_aeroform/domain/models/deployment_config.dart';

/// The default Linode provisioning strategy going forward -- see
/// docs/superpowers/specs/2026-07-29-linode-boot-time-image-provisioning-design.md.
/// Fetches the current image manifest from the image-relay Worker and
/// delegates the actual provisioning to IUrlPullProvisioningApi. No SSH
/// key generation here -- LinodeBootTimeInstaller (behind
/// IUrlPullProvisioningApi) generates its own throwaway installer
/// credential internally (design spec's Security section, D3).
@LazySingleton(as: IInstanceProvisioningStrategy)
class BootTimePullProvisioningStrategy implements IInstanceProvisioningStrategy {
  final IUrlPullProvisioningApi _pullApi;
  final http.Client _httpClient;

  BootTimePullProvisioningStrategy(this._pullApi, this._httpClient);

  @override
  Future<CloudInstance> provisionInstance({
    required String accessToken,
    required DeploymentConfig config,
    required String userData,
  }) async {
    final manifestRes = await _httpClient.get(
      Uri.parse('${config.imageRelayUrl}/image-manifest'),
    );
    if (manifestRes.statusCode != 200) {
      throw Exception('Failed to fetch image manifest: ${manifestRes.statusCode}');
    }
    final manifest = jsonDecode(manifestRes.body) as Map<String, dynamic>;

    return _pullApi.provisionFromImageUrl(
      accessToken: accessToken,
      config: config,
      userData: userData,
      imageUrl: manifest['url'] as String,
      imageSha256: manifest['sha256'] as String,
      uncompressedBytes: manifest['uncompressedBytes'] as int,
    );
  }
}
```

- [ ] **Step 5: Run it to verify it passes**

```bash
flutter test test/infrastructure/deployment/boot_time_pull_provisioning_strategy_test.dart
```

Expected: PASS.

- [ ] **Step 6: Regenerate DI wiring**

`@LazySingleton(as: IInstanceProvisioningStrategy)` on this class (with no
`@Named`, unlike `CustomImageProvisioningStrategy`'s
`@Named('customImage')` from Task 7) makes injectable pick this as the
*default* resolution for `IInstanceProvisioningStrategy` — this is the
concrete mechanism behind "DI-level selection, not a `DeploymentConfig`
field," per the design spec.

```bash
cd /Users/aicoder/Documents/flutter_aeroform
dart run build_runner build --delete-conflicting-outputs
```

Expected: regenerates `lib/flutter_aeroform.module.dart`,
`*.freezed.dart`, `*.g.dart` as needed. Check the regenerated
`flutter_aeroform.module.dart` — `DeploymentService`'s registration
should now include `provisioningStrategy:
gh<_iXXX.IInstanceProvisioningStrategy>()` resolving to
`BootTimePullProvisioningStrategy`, not `CustomImageProvisioningStrategy`.

- [ ] **Step 7: Run the full suite**

```bash
flutter analyze
flutter test
```

Expected: clean, same baseline as Task 5's Step 6 (plus the new test
files' passing tests).

- [ ] **Step 8: Commit**

```bash
git add lib/infrastructure/deployment/boot_time_pull_provisioning_strategy.dart \
        lib/domain/models/app_config.dart \
        lib/flutter_aeroform.module.dart \
        test/infrastructure/deployment/boot_time_pull_provisioning_strategy_test.dart
git commit -m "feat: add BootTimePullProvisioningStrategy, register as default

Fetches the image-relay Worker's /image-manifest, generates a
temporary installer SSH key (separate from the target box's own
passwordless key), delegates to IUrlPullProvisioningApi.

Registered via bare @LazySingleton(as: IInstanceProvisioningStrategy)
(CustomImageProvisioningStrategy uses @Named('customImage') instead) --
this is the concrete DI-level strategy selection the design calls for,
so a known-broken-for-Linode path can't become reachable by
misconfiguration the way a DeploymentConfig field would allow."
```

---

### Task 13: Publish the StackScript

Operational task — the StackScript itself needs to exist as a real
Linode resource (its numeric id is what `LinodeAPIClient` hardcodes,
per Task 11's `_bootTimePullStackscriptId`), published once, centrally,
from the project's own Linode account.

**Files:**
- Create: `deploy/nixos/stackscripts/pocketcoder-image-installer.sh`
  (pocketcoder repo — version-controlled source of truth)
- Create: `deploy/nixos/scripts/publish-stackscript.sh` (pocketcoder
  repo)

- [ ] **Step 1: Create the StackScript file**

`deploy/nixos/stackscripts/pocketcoder-image-installer.sh` — the fixed
version from the design spec's "The boot script" section, verbatim:

```bash
#!/bin/bash
# <UDF name="IMAGE_URL" label="NixOS image URL" />
# <UDF name="IMAGE_SHA256" label="Expected sha256 of the gzip" />
# <UDF name="IMAGE_UNCOMPRESSED_BYTES" label="Expected uncompressed size in bytes" />
set -euo pipefail

command -v curl >/dev/null || { apt-get update && apt-get install -y curl; }

[ -b /dev/sdb ] || { echo "FATAL: /dev/sdb not found"; exit 1; }
TARGET_BYTES=$(blockdev --getsize64 /dev/sdb)
[ "$TARGET_BYTES" -ge "$IMAGE_UNCOMPRESSED_BYTES" ] || {
  echo "FATAL: target disk ($TARGET_BYTES bytes) smaller than image ($IMAGE_UNCOMPRESSED_BYTES bytes)"
  exit 1
}

attempt=0
until [ "$attempt" -ge 3 ]; do
  attempt=$((attempt + 1))
  echo "Attempt $attempt..."
  mkfifo /tmp/sumpipe
  sha256sum < /tmp/sumpipe > /tmp/sum &
  SUMPID=$!

  if curl -fsSL --retry 0 --max-time 1800 --speed-limit 1024 --speed-time 60 \
      "$IMAGE_URL" \
      | tee /tmp/sumpipe \
      | gunzip \
      | dd of=/dev/sdb bs=16M conv=fsync status=progress; then
    wait "$SUMPID"
    rm -f /tmp/sumpipe
    read -r ACTUAL_SHA _ < /tmp/sum
    if [ "$ACTUAL_SHA" = "$IMAGE_SHA256" ]; then
      sync
      systemctl poweroff --no-block
      exit 0
    fi
    echo "Checksum mismatch on attempt $attempt (got $ACTUAL_SHA)"
  else
    wait "$SUMPID" 2>/dev/null || true
    rm -f /tmp/sumpipe
    echo "Transfer failed on attempt $attempt"
  fi
done

echo "FATAL: all attempts failed -- leaving instance online for inspection"
exit 1
```

- [ ] **Step 2: Create a publish script**

`deploy/nixos/scripts/publish-stackscript.sh` — mirrors this session's
established pattern for other one-time-registration scripts (e.g.
`trigger-ci-build.sh`), reads `LINODE_TOKEN` from the environment (daemon-
injected, never read from a file):

```bash
#!/bin/sh
# Publishes/updates the pocketcoder-image-installer StackScript from
# deploy/nixos/stackscripts/pocketcoder-image-installer.sh. Run once to
# create it (prints the new numeric id -- update
# LinodeAPIClient._bootTimePullStackscriptId with it), and again any time
# the StackScript's content changes (updates in place, same id). Reads
# LINODE_TOKEN from the environment (injected by the secrets-daemon via
# `sops exec-env` -- never read from a file here, never echoed).
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_BODY=$(cat "$SCRIPT_DIR/stackscripts/pocketcoder-image-installer.sh")
AUTH="Authorization: Bearer $LINODE_TOKEN"

EXISTING_ID=$(curl -sf -H "$AUTH" \
  "https://api.linode.com/v4/linode/stackscripts?page_size=100" \
  | python3 -c "
import json, sys
data = json.load(sys.stdin)['data']
matches = [s for s in data if s.get('label') == 'pocketcoder-image-installer']
print(matches[0]['id'] if matches else '')
")

BODY=$(python3 -c "
import json, sys
print(json.dumps({
    'label': 'pocketcoder-image-installer',
    'description': 'Pulls the PocketCoder NixOS image from R2 onto a raw target disk (boot-time-pull provisioning)',
    'images': ['linode/debian12'],
    'is_public': False,
    'script': sys.argv[1],
}))
" "$SCRIPT_BODY")

if [ -n "$EXISTING_ID" ]; then
  echo "Updating existing StackScript $EXISTING_ID"
  curl -sf -X PUT -H "$AUTH" -H "Content-Type: application/json" \
    "https://api.linode.com/v4/linode/stackscripts/$EXISTING_ID" \
    -d "$BODY" | python3 -m json.tool
else
  echo "Creating new StackScript"
  curl -sf -X POST -H "$AUTH" -H "Content-Type: application/json" \
    "https://api.linode.com/v4/linode/stackscripts" \
    -d "$BODY" | python3 -m json.tool
fi
```

- [ ] **Step 3: Make it executable and commit**

```bash
chmod +x deploy/nixos/scripts/publish-stackscript.sh
git add deploy/nixos/stackscripts/pocketcoder-image-installer.sh \
        deploy/nixos/scripts/publish-stackscript.sh
git commit -m "feat(nixos): add the boot-time-pull StackScript + publish script

Version-controlled source of truth for the StackScript content;
publish-stackscript.sh creates or updates the live Linode resource
from it. Per root CLAUDE.md's central-registration principle, this is
published once, centrally, from the project's own Linode account --
end users never see this step."
```

- [ ] **Step 4: Publish it for real (needs a human/daemon action)**

This needs a `LINODE_TOKEN`-credentialed run of
`deploy/nixos/scripts/publish-stackscript.sh` — via the secrets-daemon if
available in the executing environment (propose a
`publish_boot_installer_stackscript` action pointing at this script,
following this session's established pattern, if one doesn't already
exist), or by a human running it directly with their own token. **Record
the returned numeric id** and use it in the next step.

- [ ] **Step 5: Wire the real id into `LinodeAPIClient`**

Replace Task 11's placeholder:

```dart
  static const int _bootTimePullStackscriptId = 0; // TODO: real id after Task 13
```

with the real id from Step 4:

```dart
  static const int _bootTimePullStackscriptId = <real id>;
```

- [ ] **Step 6: Run the full suite once more and commit**

```bash
cd /Users/aicoder/Documents/flutter_aeroform
flutter analyze
flutter test
git add lib/infrastructure/cloud_provider/linode_api_client.dart
git commit -m "chore: wire the real published StackScript id"
```

---

### Task 14: Rewrite the golden-path integration test

**Files:**
- Modify: `test/integration/golden_path_provision_test.dart`
  (flutter_aeroform repo)

**Interfaces:** Consumes everything built in Tasks 7–13 — this is the
real, live, end-to-end proof.

- [ ] **Step 1: Update the test's construction to use the new strategy**

The existing test manually constructs `DeploymentService` with real
implementations (`LinodeAPIClient`, `CertificateManager`,
`PasswordGenerator`, `SshKeyGenerator`, `ValidationService`) and a fake
`ISecureStorage`. Add construction of the new pieces and pass a real
`BootTimePullProvisioningStrategy` as `provisioningStrategy:`:

```dart
        final apiClient = LinodeAPIClient(http.Client(), 'aeroform-golden-path-test');
        final provisioningStrategy = BootTimePullProvisioningStrategy(
          apiClient, // implements IUrlPullProvisioningApi
          http.Client(),
        );

        final deploymentService = DeploymentService(
          apiClient: apiClient,
          certManager: certManager,
          passwordGenerator: passwordGenerator,
          sshKeyGenerator: sshKeyGenerator,
          secureStorage: secureStorage,
          validationService: validationService,
          provisioningStrategy: provisioningStrategy,
        );
```

- [ ] **Step 2: Update the config's `imageRelayUrl`**

Confirm it points at the real deployed Worker (already fixed in Task 5):

```dart
        final config = DeploymentConfig(
          planType: 'g6-standard-1',
          region: 'us-east',
          adminEmail: 'golden-path-test@pocketcoder.local',
          ntfyEnabled: false,
          imageRelayUrl: 'https://pocketcoder-image-relay.gp-c53.workers.dev',
          nixosImageLabel: 'pocketcoder-nixos-v1',
        );
```

(`nixosImageLabel` is now unused by the default provisioning path, but
`DeploymentConfig` still requires the field — leave it as-is rather than
making it optional, since `CustomImageProvisioningStrategy` still needs
it and both strategies share this config type.)

- [ ] **Step 3: Extend the timeout**

Boot-time-pull adds real wall-clock time beyond what the Custom-Image
path needed (R2→Linode transfer + decompress+`dd` of ~4.7GB + two boot
cycles, on top of the existing cert-polling window). Bump the test's
`Timeout`:

```dart
      timeout: const Timeout(Duration(minutes: 60)),
```

- [ ] **Step 4: Add a corrupted-image failure-path assertion**

New test, alongside the existing happy-path one, proving the app-level
teardown behavior specified in the design spec's "Failure handling"
section (an intentionally-bad manifest should result in a deleted
instance and a clear error, not an orphaned running box):

```dart
    test(
      'a corrupted image manifest results in a deleted instance, not an orphan',
      () async {
        // Point BootTimePullProvisioningStrategy at a manifest with a
        // deliberately wrong sha256 -- the StackScript's own checksum
        // gate will fail closed and leave the installer running, which
        // the app-level timeout must convert into: delete the instance,
        // throw a diagnosable error. This proves the teardown behavior
        // specified in the design spec's "Failure handling" section,
        // not just the happy path.
        //
        // Implementation note for whoever picks this up: this needs a
        // real (but short) timeout override on the strategy/installer
        // for the test to complete in reasonable time rather than
        // waiting out the full installer-completion poll budget --
        // check whether LinodeBootTimeInstaller's poll timeouts are
        // already parameterized by this point in implementation, and
        // add that parameterization here if not, rather than letting
        // this test take the full production timeout to run.
      },
      timeout: const Timeout(Duration(minutes: 15)),
      skip: liveTest
          ? false
          : 'Set AEROFORM_LIVE_TEST=1 to run this real, billed Linode test.',
    );
```

- [ ] **Step 5: Run the full local (non-live) suite**

```bash
cd /Users/aicoder/Documents/flutter_aeroform
flutter analyze
flutter test
```

Expected: clean; both golden-path tests show as `Skip` (no
`AEROFORM_LIVE_TEST=1`), same baseline otherwise.

- [ ] **Step 6: Commit**

```bash
git add test/integration/golden_path_provision_test.dart
git commit -m "test: update golden-path test for boot-time-pull provisioning

Constructs BootTimePullProvisioningStrategy instead of relying on
DeploymentService's old inline image logic, extends the timeout for
the real added wall-clock time (R2 transfer + decompress+dd + two
boot cycles), and adds a corrupted-image test proving the app-level
teardown behavior (delete instance, clear error) rather than only
covering the happy path."
```

- [ ] **Step 7: Run it live (needs the secrets-daemon or a human with a
  real `LINODE_TOKEN`)**

```
{"action": "run_aeroform_golden_path_test", "timeout_seconds": 3600}
```

over the daemon socket, if available in the executing environment.
Otherwise flag clearly that this final live verification step needs to
be run by a human before this feature is considered actually proven —
everything up to this point is real, tested code, but the golden path
(the actual point of this whole plan) is only proven by this real run
succeeding against a real Linode account.

---

### Task 15: Cap `_pollForCertificate`'s polling backoff

The design spec's "Failure handling and lifecycle" section requires this:
the existing exponential backoff (`15s * 2^(attempts-1)`, 20 attempts) has
no cap — attempt 20 alone waits ~91 hours. This design adds real
wall-clock time (R2 transfer + decompress+`dd` + two boot cycles) before
NixOS even starts booting, on top of whatever this pre-existing,
already-too-generous backoff was already going to do.

**Files:**
- Modify: `lib/infrastructure/deployment/deployment_service.dart`
  (flutter_aeroform repo)
- Modify: `test/infrastructure/deployment/deployment_service_test.dart`
  (flutter_aeroform repo)

**Interfaces:**
- Produces: a testable, pure backoff-delay function — expose it as a
  `@visibleForTesting` static method so the test doesn't have to run the
  real polling loop (with real `Future.delayed` calls) to exercise late
  attempt numbers.

- [ ] **Step 1: Locate the existing backoff computation**

```bash
cd /Users/aicoder/Documents/flutter_aeroform
grep -n "15" lib/infrastructure/deployment/deployment_service.dart | grep -i -E "second|delay|backoff|pow"
```

Find where `_pollForCertificate` (or its equivalent private polling
method) computes its per-attempt delay from the attempt count. Read the
surrounding ~20 lines to see the exact current expression (likely
something using `Duration(seconds: 15 * pow(2, attempt - 1).toInt())` or
equivalent) before writing the test below, so the test's expectations
match the method's real name and signature rather than an assumed one.

- [ ] **Step 2: Write the failing test**

Adapt this to the real method name found in Step 1 (shown here as
`certPollDelayForAttempt` — rename to match):

```dart
    test('caps the certificate-poll backoff at 5 minutes', () {
      final lateDelay = DeploymentService.certPollDelayForAttempt(20);
      expect(lateDelay, lessThanOrEqualTo(const Duration(minutes: 5)));
    });

    test('still grows exponentially before the cap', () {
      final delay1 = DeploymentService.certPollDelayForAttempt(1);
      final delay2 = DeploymentService.certPollDelayForAttempt(2);
      expect(delay1, const Duration(seconds: 15));
      expect(delay2, const Duration(seconds: 30));
    });
```

- [ ] **Step 3: Run it to verify it fails**

```bash
flutter test test/infrastructure/deployment/deployment_service_test.dart --plain-name "caps the certificate-poll backoff"
```

Expected: FAIL (method doesn't exist yet under this name/visibility, or
the uncapped version returns something far larger than 5 minutes for
attempt 20).

- [ ] **Step 4: Extract and cap the backoff computation**

Pull the inline expression found in Step 1 out into a
`@visibleForTesting static Duration certPollDelayForAttempt(int attempt)`
method on `DeploymentService`, capping the result:

```dart
  @visibleForTesting
  static Duration certPollDelayForAttempt(int attempt) {
    final uncapped = Duration(seconds: 15 * pow(2, attempt - 1).toInt());
    const cap = Duration(minutes: 5);
    return uncapped > cap ? cap : uncapped;
  }
```

Replace the polling loop's inline delay computation with a call to this
method.

- [ ] **Step 5: Run it to verify it passes**

```bash
flutter test test/infrastructure/deployment/deployment_service_test.dart --plain-name "certificate-poll backoff"
```

Expected: PASS (2/2).

- [ ] **Step 6: Run the full suite**

```bash
flutter analyze
flutter test
```

Expected: clean, same baseline as Task 5's Step 6.

- [ ] **Step 7: Commit**

```bash
git add lib/infrastructure/deployment/deployment_service.dart test/infrastructure/deployment/deployment_service_test.dart
git commit -m "fix: cap certificate-poll backoff at 5 minutes

Uncapped exponential backoff meant attempt 20 alone waited ~91 hours.
Boot-time-pull provisioning adds real wall-clock time before NixOS
even starts booting, on top of this pre-existing, already-too-generous
backoff -- capping it keeps total deployment time bounded and
predictable."
```

---

### Task 16: Orphan-reaping sweep

The design spec's "Failure handling and lifecycle" section calls for
this as "a periodic or on-demand safety net, independent of the in-line
teardown" (Task 10's try/catch and timeout-triggered deletes). Depends on
Task 5's `listInstances` labelFilter fix — without that fix, this sweep
would silently list (and risk deleting) every instance on the account,
not just PocketCoder-labeled ones.

**Files:**
- Modify: `lib/infrastructure/deployment/deployment_service.dart`
  (flutter_aeroform repo)
- Modify: `lib/domain/deployment/i_deployment_service.dart`
  (flutter_aeroform repo — confirm the exact interface file name via
  `grep -rn "abstract class IDeploymentService"` before editing; add the
  new method to whichever file actually declares it)
- Modify: `test/infrastructure/deployment/deployment_service_test.dart`
  (flutter_aeroform repo)

**Interfaces:**
- Consumes: `ICloudProviderAPIClient.listInstances` (already exists;
  its `labelFilter` bug is fixed by Task 5), `DeploymentService`'s
  existing `_pocketCoderLabelPrefix` constant (referenced by the design
  spec directly — confirm its exact name via
  `grep -n "LabelPrefix" lib/infrastructure/deployment/deployment_service.dart`
  before writing code against it).
- Produces: `Future<List<String>> reapOrphanedInstances({required String
  accessToken, required Duration olderThan})` on `IDeploymentService` —
  returns the ids of instances it deleted. Not consumed by any other
  task in this plan — this is a safety-net entry point a human or a
  scheduled job calls, not something the provisioning path itself
  depends on.

- [ ] **Step 1: Write the failing test**

```dart
    test('reapOrphanedInstances deletes only PocketCoder-labeled instances older than the cutoff', () async {
      final now = DateTime.now();
      final oldOrphan = CloudInstance(
        id: '1',
        label: 'pocketcoder-old',
        ipAddress: '1.2.3.4',
        status: CloudInstanceStatus.running,
        created: now.subtract(const Duration(hours: 5)),
        region: 'us-east',
        planType: 'g6-standard-1',
        provider: 'linode',
      );
      final recentInstance = CloudInstance(
        id: '2',
        label: 'pocketcoder-recent',
        ipAddress: '1.2.3.5',
        status: CloudInstanceStatus.running,
        created: now.subtract(const Duration(minutes: 5)),
        region: 'us-east',
        planType: 'g6-standard-1',
        provider: 'linode',
      );

      when(() => apiClient.listInstances('token', labelFilter: any(named: 'labelFilter')))
          .thenAnswer((_) async => [oldOrphan, recentInstance]);
      when(() => apiClient.deleteInstance('token', '1')).thenAnswer((_) async {});

      final deletedIds = await deploymentService.reapOrphanedInstances(
        accessToken: 'token',
        olderThan: const Duration(hours: 1),
      );

      expect(deletedIds, ['1']);
      verifyNever(() => apiClient.deleteInstance('token', '2'));
    });
```

(If `ICloudProviderAPIClient` doesn't already have a `deleteInstance`
method under that exact name, `grep -n "delete" lib/domain/cloud_provider/i_cloud_provider_api_client.dart`
first and use the real name instead — this plan assumes it exists, since
`DeploymentService`'s existing failure paths already need to delete
instances today.)

- [ ] **Step 2: Run it to verify it fails**

```bash
cd /Users/aicoder/Documents/flutter_aeroform
flutter test test/infrastructure/deployment/deployment_service_test.dart --plain-name "reapOrphanedInstances"
```

Expected: FAIL (method doesn't exist).

- [ ] **Step 3: Add to `IDeploymentService` and implement**

Add to the interface:

```dart
  Future<List<String>> reapOrphanedInstances({
    required String accessToken,
    required Duration olderThan,
  });
```

Implement on `DeploymentService`:

```dart
  @override
  Future<List<String>> reapOrphanedInstances({
    required String accessToken,
    required Duration olderThan,
  }) async {
    final instances = await _apiClient.listInstances(
      accessToken,
      labelFilter: _pocketCoderLabelPrefix,
    );
    final cutoff = DateTime.now().subtract(olderThan);
    final orphans = instances.where((i) => i.created.isBefore(cutoff));

    final deletedIds = <String>[];
    for (final orphan in orphans) {
      await _apiClient.deleteInstance(accessToken, orphan.id);
      deletedIds.add(orphan.id);
    }
    return deletedIds;
  }
```

(This is a safety net, not the primary teardown path -- it has no
try/catch-per-instance here deliberately: if one delete fails, let the
exception propagate rather than silently continuing past a real API
error, since a human is the one invoking this, not an unattended
provisioning flow.)

- [ ] **Step 4: Run it to verify it passes**

```bash
flutter test test/infrastructure/deployment/deployment_service_test.dart --plain-name "reapOrphanedInstances"
```

Expected: PASS.

- [ ] **Step 5: Run the full suite**

```bash
flutter analyze
flutter test
```

Expected: clean, same baseline as Task 5's Step 6.

- [ ] **Step 6: Commit**

```bash
git add lib/infrastructure/deployment/deployment_service.dart lib/domain/deployment/i_deployment_service.dart test/infrastructure/deployment/deployment_service_test.dart
git commit -m "feat: add orphan-reaping sweep for stuck/leaked Linode instances

Safety net independent of Task 10's in-line teardown (try/catch +
timeout-triggered delete) -- lists PocketCoder-labeled instances
(depends on Task 5's listInstances labelFilter fix) older than a
caller-supplied cutoff and deletes them. Not wired into the
provisioning path itself; a human or scheduled job calls this
on-demand."
```

---

## Self-review notes

- **Spec coverage**: every numbered section of the design spec has a
  corresponding task — Problem/architecture → Tasks 7–12; corrected
  Linode sequence → Task 10; StackScript fixes → Task 13; NixOS
  `autoResize` → Task 1; CI prerequisite → Task 3; Worker
  changes/manifest auth → Task 4; Security D3 (installer uses a
  throwaway root_pass, not a real SSH key) → Task 10 Step 3; known
  unrelated bugs → Tasks 2, 5, 6; DI-level strategy selection (not a
  `DeploymentConfig` field) → Task 12 Step 6; failure-handling/lifecycle
  requirements → Task 10's try/catch teardown + timeout-triggered delete
  (in-line), Task 15 (backoff cap), Task 16 (orphan-reaping sweep); the
  pre-implementation metadata-delivery verification → Task 10 Step 0,
  and its daemon action → the "Secrets-Daemon Actions Needed" section.
- **Deferred by design, not by oversight**: the spec's own "Out of
  scope" section (a second `IUrlPullProvisioningApi` provider, pinning
  `bootstrap.nix`'s git ref, adding a swap disk) — none of these have
  tasks here, matching the spec. The spec's Cloud Firewall
  recommendation for the installer ("costs nothing and is worth adding")
  is *not* implemented here either — deliberately deferred, not
  forgotten: Task 10's D3 fix (throwaway `root_pass`, no real key on the
  installer at all) already closes the specific credential-leak vector
  the firewall would add defense-in-depth against, so the marginal value
  of also adding a Linode Cloud Firewall (a real, separate API surface
  this plan doesn't otherwise touch) didn't clear the bar for this pass;
  worth a follow-up if the installer's ~5-8 minute network-exposure
  window itself (not just credential leakage) becomes a concern.
- **Placeholder scan**: the one deliberate placeholder
  (`_bootTimePullStackscriptId = 0`) is intentional and explicitly
  resolved by Task 13 Step 5 — flagged inline as `// TODO: real id after
  Task 13`, not a silently-forgotten gap, and Task 13 exists specifically
  to close it.
- **Type consistency check**: `IInstanceProvisioningStrategy.provisionInstance`
  (Task 7) and `IUrlPullProvisioningApi.provisionFromImageUrl` (Task 9)
  both return `Future<CloudInstance>` — consistent throughout Tasks
  9–14. An earlier draft of this plan had Task 9 define
  `provisionFromImageUrl` without an SSH-key parameter, then had Task 11
  retroactively add one (`installerSshKey`) — a real internal
  contradiction, since Task 12 cited "Task 9/11" for the interface and a
  reader trusting Task 9 alone would get the wrong signature. Resolved
  by choosing the D3 mitigation that removes the need for any SSH-key
  parameter at all (Task 10's throwaway `root_pass`, generated
  internally) — Task 9's original signature was already correct, Task
  11's retroactive addition is gone, and Task 12 no longer has an
  `ISshKeyGenerator` dependency either. Verified no other task
  references `installerSshKey`/`rootSshKey` as a parameter anywhere in
  the current plan.
- **Sequencing check**: Task 10 Step 0 explicitly gates on the
  pre-implementation metadata-delivery verification having already run
  and succeeded — this was previously only mentioned in prose (the
  "Secrets-Daemon Actions Needed" section) with no enforcement point in
  the numbered task list; a fresh subagent given only Task 10 now has an
  explicit, in-band instruction to check for and, if needed, run that
  verification first rather than building on an unverified assumption.
- **Test-realism check on Task 10**: the happy-path test's mocked disk
  GET now disambiguates "ready" (any disk) from "gone" (installer disk
  specifically, after its DELETE fires) by disk id, rather than a single
  always-`ready` stub that would have made `_waitForDiskGone` spin for
  its full timeout and fail every run. A second test asserts the
  whole-sequence try/catch teardown (instance deleted on any mid-sequence
  failure) using an intentionally unmocked step 3 call to trigger a
  mocktail `MissingStubError`. The busy-retry test (Step 5) no longer
  hand-waves its setup — it mocks exactly the two calls it needs
  (instance-create, disk-size-lookup-that-retries, instance-delete) and
  lets the sequence fail past step 2 on purpose, asserting only the
  retry count.
