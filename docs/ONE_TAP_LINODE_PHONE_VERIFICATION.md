# One-Tap Linode → Phone Verification Tracker

## Goal

Prove the real customer path end to end: install the current PocketCoder
build on a phone, authenticate with Linode, provision a fresh Linode from
the app, connect the phone to that deployment, and send and receive an
agent message.

This is a living execution tracker, not a design document.  Each completed
run must record its UTC timestamp, source commit, release artifact, and
result below so an older image or app build cannot be mistaken for the
current product.

## Latest evidence snapshot

| Field | Value |
| --- | --- |
| Recorded at (UTC) | 2026-08-04T18:58:42Z |
| Source commit | `a3136b14fc6a3c6e1b66c8a65dfa2671ef85afee` |
| Source version | `a3136b14f` — virtual local Ollama model support |
| Published deployment image | manifest reports `af6a1c732792f765427e7a2e30ae992b25499037` |
| Evidence owner | automated local/HTTPS checks; human-device steps remain open |

The published image predates the recorded source commit.  Do **not** treat a
deployment from that image as verification of the current product.  Build,
publish, and record a new image manifest before the production run.

## Status legend

- **Pass** — verified against the version named in the evidence row.
- **Blocked** — a prerequisite is missing; do not start a paid production
  step that depends on it.
- **Pending** — intended test has not been performed.
- **N/A** — not required for the golden path.

## Verification matrix

| Check | Local verified | Production verified |
| --- | --- | --- |
| Current source identity captured | **Pass** — `a3136b14f`, 2026-08-04T18:58:42Z | **Pending** — record the release/IPA build hash and image manifest hash used |
| Deploy/login entry point and chosen admin credentials | **Pass** — focused Flutter suite passed (10 tests) on `a3136b14f` | **Pending** — use the values chosen on the phone to log into the new server |
| Linode OAuth relay reachable and configured | **Pass** — `/` healthy; `/providers` returned GitHub and Linode | **Pending** — real browser consent, callback, claim, and refresh from the phone |
| Image relay reachable | **Pass** — `images.relay.pocketcoder.org/health` and `/image-manifest` returned successfully | **Pending** — verify the production phone build uses the custom relay URL |
| Push relay reachable | **Pass** — account-qualified root returned healthy | **N/A** for sending/receiving an in-app message; separately test a physical-device push later |
| New Linode created and booted | Historical real proof exists in `REMAINING_TESTS_STATUS.md` | **Pending** — create a fresh instance from the released phone build and check the resulting PocketBase health endpoint |
| Phone reaches new server | **Pending** — emulator/device connection is not equivalent | **Pending** — enter or accept the deployed HTTPS address and complete login |
| Send and receive an agent message | Existing local Docker integration evidence only | **Pending** — send a short Goose chat and verify its reply in the phone UI |
| Codex account authentication | **Pass** — ChatGPT device-code login, isolated-volume persistence, and a real model response were verified | **Pending** — implement PocketBase/Flutter auth session and ensure device authorization is enabled in the user’s ChatGPT Security Settings |
| Claude Code account authentication | **Pass** — Claude.ai browser-code login, isolated `HOME` volume persistence, and a real model response were verified | **Pending** — implement PocketBase/Flutter auth session with a controlled code-submission endpoint |
| Cognee memory | **N/A** for the golden path; preserve as a follow-up | **Pending** — configure `COGNEE_LLM_API_KEY`, enable the agent profile, and verify a memory round-trip |

## Required execution order

1. **Publish the exact source to test.** Build the NixOS image from the
   chosen commit, publish it through the image pipeline, then record the
   manifest URL, image commit/hash, app release artifact, and date in a new
   evidence snapshot.
2. **Run the local release gate.** Re-run the focused Flutter deploy-flow
   tests and the backend/harness integration suite on that same source.  The
   current successful Flutter command was:

   ```sh
   cd client
   flutter test \
     packages/pocketcoder_flutter/test/infrastructure/core/external_module_test.dart \
     packages/pocketcoder_flutter/test/presentation/onboarding/onboarding_screen_test.dart \
     packages/pocketcoder_pro/test/presentation/deployment/details_screen_test.dart \
     packages/pocketcoder_pro/test/application/config/config_cubit_test.dart
   ```

3. **Build and install the phone artifact.** Record its commit/version and
   device/OS.  Use a build that contains the account-qualified image-relay
   endpoint.
4. **Perform real Linode OAuth on the phone.** Log in, consent, return to
   PocketCoder, and verify the OAuth token can list regions/plans before
   creating anything.
5. **Provision exactly one cheapest test instance.** Choose the cheapest
   supported plan/region, wait for PocketBase health, then log in using the
   credentials chosen during the deploy flow.
6. **Exercise the user-visible core loop.** Create a Goose chat, send a
   small prompt, and verify the streamed/final reply arrives on the phone.
7. **Tear down the Linode** after collecting the instance ID, URLs, and
   non-secret logs needed for this record.

## Authentication work before peer-harness production proof

### Local spike — 2026-08-04T19:40:04Z

The shared harness image initially lacked a Linux CA certificate bundle.
Node-based network checks worked, while the native Codex and Claude binaries
could not validate their providers' TLS certificates.  The shared image now
installs `ca-certificates`; both rebuilt harness images passed the checks
below.  This Dockerfile change is intentionally recorded as working-tree
evidence until it is committed with the eventual implementation.

| Harness | Verified behavior | Product implication |
| --- | --- | --- |
| Codex | `codex login --device-auth` emitted a URL and short-lived user code; after browser approval, `login status` in a fresh container reported ChatGPT login and a real read-only prompt completed. | Flutter needs only the login URL, user code, expiry, and status. Device authorization must be enabled in ChatGPT Security Settings or start must return a clear actionable failure. |
| Claude Code | `claude auth login --claudeai` emitted an OAuth URL; browser approval returned an authorization code; a controlled stdin bridge delivered it to the waiting process. A fresh container reported Claude.ai login and a real prompt completed. | Flutter needs the OAuth URL, then a one-time “submit authorization code” action. The raw CLI is not a safe UI surface. |
| Isolation | Mounting Codex's volume as Claude's `HOME` and Claude's volume as Codex's home both reported unauthenticated. | Use one private named volume per harness; never share or copy credential files. |

The app does **not** yet use these account credentials.  Today dynamic
harness provisioning only renders `OPENAI_API_KEY` or `ANTHROPIC_API_KEY`
into a container environment.  Replace that path with a narrowly scoped
PocketBase-managed authentication helper:

1. Start a short-lived login subprocess in the selected harness image with
   its private auth volume mounted as `HOME`.
2. Parse and return only provider-approved display fields (URL, device code,
   expiry, status) through authenticated PocketBase endpoints/realtime.
3. For Claude only, accept the one-time browser code through a dedicated
   authenticated endpoint and write it to that subprocess's stdin.  Do not
   use `docker attach`, `docker exec`, or a terminal in Flutter.
4. On success, destroy the auth helper; leave the private volume for the
   normal dynamically provisioned ACP runtime container to mount as `HOME`.
5. Add tests for volume isolation, restart persistence, expiry/cancel, and
   redaction of stdout/stderr, URLs, and credential material from logs.

## Related references

- `docs/REMAINING_TESTS_STATUS.md` — prior live provider/Worker evidence.
- `docs/superpowers/plans/2026-08-02-linode-oauth-relay-migration.md` —
  Linode OAuth implementation and its manual-consent gate.
- `docs/superpowers/specs/2026-07-29-linode-boot-time-image-provisioning-design.md`
  — account-qualified image-relay requirement.
- `LINODE_REVIEWER_ACCESS_TODO.md` — reviewer-account operational notes;
  its old PAT-bypass approach is superseded.
