# Pruning Audit — Consolidated Summary (2026-07-21)

Five haiku agents surveyed the repo for dead code left by the OpenCode/Interface → Goose (ACP + AG-UI) cutover. Reports `01`–`05` hold the detail. This is the cross-cutting view, ordered by what matters.

Backend `go build ./...` / `go vet ./...` = clean. Flutter `flutter analyze` = 0 errors. So none of this breaks compilation — it's dead weight and one live-but-wrong wiring.

---

## 🔴 Tier 0 — Not just dead: actively wrong (fix regardless of pruning)

**Old `ChatCubit` / `PermissionCubit` still root-provided in `app.dart` (VERIFIED).**
Two `@injectable` classes share each name (`application/chat/chat_cubit.dart` vs `application/agent/chat_cubit.dart`; same for permission). `app.dart` imports the OLD files, so `getIt<ChatCubit>()..initialize()` at the app root runs the **OpenCode flow on every launch**: `ensureChat("PocketCoder Main")` (creates a stray chat), `getOpencodeId()`, and cold/hot pipe realtime subscriptions — against schema fields that were dropped. Caught by try/catch so no crash, but wrong. The real chat UI (`chat_screen.dart`) already re-provides the NEW cubits locally, so removing the OLD root providers + imports is safe and *improves* e2e cleanliness.

Fix: drop the two OLD BlocProviders + imports from `app.dart`; then the whole OLD Flutter stack below becomes deletable.

---

## 🟠 Tier 1 — High-confidence dead code (safe to prune)

### Flutter — old OpenCode/Interface logic stack (report 02)
- `application/chat/chat_cubit.dart` (OLD), `application/chat/chat_list_cubit.dart`
- `application/permission/permission_cubit.dart` (OLD), `application/question/question_cubit.dart`
- `domain/communication/i_chat_repository.dart`, `infrastructure/communication/chat_repository.dart`
- `domain/hitl/i_hitl_repository.dart`, `infrastructure/hitl/hitl_repository.dart`
- `ChatDao` + `MessageDao` in `infrastructure/communication/communication_daos.dart` (keep `SandboxAgentDao`)
- `PocketCoderApi` in `infrastructure/core/api_client.dart` (only used by the two dead repos)
- Remove matching factory/lazySingleton lines in `bootstrap.config.dart` (regen via build_runner)

### Flutter — old presentation renderers (report 01)
- `presentation/chat/mappers/chat_message_mapper.dart` (self-marked "not currently used")
- `presentation/core/widgets/question_prompt.dart`
- `presentation/core/widgets/speech_bubble.dart`
- `presentation/core/widgets/thoughts_stream.dart`
(All 17 routed screens are live; no orphaned screens.)

### PocketBase Go (report 03)
- Empty dirs: `internal/agents/`, `internal/auth/`
- Unused packages: `internal/permission/` (evaluator.go), `internal/utils/` (wildcard.go)
- `internal/agent/executor/sandbox.go` — dormant; **but** flagged elsewhere as "preserved for future Goose tool." Decide keep-vs-cut deliberately.
- Stale comments only: `hooks/cron.go`, `hooks/mcp.go`, `provisioning/sops.go` (`.opencode/` path)

### Infra / services (report 05)
- `services/opencode/` — dir + node_modules, no Dockerfile, not in compose, not in git
- `services/interface/` — Dockerfile deleted (a77049b18), artifacts remain, not in compose
- Dead env vars in `.env`: `OPENCODE_URL`, `ENABLE_GO_RELAY`, `OPENCODE_EXPERIMENTAL*`, `OPEN_NOTEBOOK_ENCRYPTION_KEY`; `GEMINI_API_KEY` only feeds dormant c3 `mcp-gateway`

### Docs / scripts / cruft (report 04)
- `client/ai-opencode.txt`, `client/FLUTTER_*.md` (5 roadmap/gap docs), `client/DATA_ARCHITECTURE_PLAN.md`
- Scripts: `scripts/network_matrix_test.{sh,py}`, `scripts/debug/export_opencode_session.sh`, `query-agent-tools.sh`, `scripts/investigate/cao_db_*.sh` (3)
- Cruft: `.env.backup`, `.env.bak`, `client/melos_pocketcoder_workspace.iml`

---

## 🟡 Tier 2 — Investigate before acting (don't auto-delete)

- **`README.md`, `DEVELOPMENT.md`, `SECURITY.md`** (report 04) — flagged "stale" but these are top-level project docs. **Update, don't delete** — they should describe the Goose architecture.
- **Applied PB migrations** (report 05) — dropped fields/collections (`messages`, `permissions`, `acp_terminals`, `chats.engine_type`, etc.) are already applied. **Do NOT delete applied migrations** (breaks history). Candidate only for a future forward drop-migration if any dead collection lingers.
- **`sandbox_agents` collection + `executor/sandbox.go` + `SandboxAgentDao`** — explicitly preserved for a future Goose tool. Keep unless you're sure that future is cancelled.
- **`services/poco-agents/` + `services/proxy/` (Rust)** — Cargo.toml present, referenced nowhere. Confirm they're not a separate planned workstream before removing.
- **Dormant `mcp-gateway` (c3) + `sandbox` compose services** — intentionally dormant, not dead. Keep.
- **`spikes/goose-acp-http/`** — served its purpose; worth keeping as a locked decision record.

---

## Suggested order of operations
1. **Tier 0** — clean `app.dart` (removes the wrong-startup behavior). Verify app still boots + tests green.
2. **Tier 1 Flutter** — delete old logic + presentation stack together (they're mutually referencing), regen DI, run `flutter analyze` + tests.
3. **Tier 1 Go/infra/docs** — delete dead services/dirs/scripts, prune `.env`, fix stale comments.
4. **Tier 2** — decide each item with intent; nothing here is auto-safe.

Nothing in Tiers 0–1 is referenced by the live Goose/AG-UI path (verified: zero cross-pollination between old and new stacks).
