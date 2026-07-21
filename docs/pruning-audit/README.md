# Pruning Audit — 2026-07-21

Post-cutover dead-code survey. The project migrated from an **OpenCode/Interface**
reasoning path to **Goose (ACP + AG-UI)**, and the Flutter chat client was rebuilt
on the AG-UI stack (old `chat_screen` and its mappers/clients replaced in place).
This audit hunts for the remnants that cutover left behind.

## Rules for this audit
- **Findings only. Delete nothing.** Each agent writes one report here.
- Every candidate needs **evidence**: the file, why it looks dead (no references,
  retired subsystem, superseded), and a **confidence** (High / Medium / Low).
- When unsure, list it as Low confidence rather than omitting it.
- Note anything that is referenced but *shouldn't* be (zombie wiring).

## Reports
- `01-flutter-presentation.md` — screens, widgets, routes; old chat-stack remnants
- `02-flutter-logic.md` — application/domain/infrastructure: cubits, repos, models, DI
- `03-pocketbase-go.md` — Go backend: retired OpenCode/relay paths, dormant subsystems
- `04-docs-and-scripts.md` — root docs, roadmaps, scripts, spikes, stale .env/backup files
- `05-infra-compose.md` — docker-compose services, Dockerfiles, dropped-field migrations

## Verdict column (filled in by human later)
Keep / Prune / Investigate
