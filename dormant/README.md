# Dormant Code

Components that are **retained but not part of the current runtime**. Nothing
here is built, deployed, imported, or wired into `docker-compose.yml`. They are
kept as reference and as a head start for future work — not deleted, not active.

They are deliberately excluded from the codebase audit (`tooling/scripts/generate_audit.sh`)
and the docs site (`website/sync.sh`), because they are not product code.

| Component | Language | Was | Reactivates when |
|:---|:---|:---|:---|
| `proxy/` | Rust | The "Sentinel" sandbox execution proxy — a dumb executor that accepted pre-approved command packets and forwarded them to a local shell/tmux session. | PocketCoder reintroduces a separate hardened execution sandbox behind an ACP `terminal/*` seam, instead of letting Goose run its own shell in c2. See `docs/architecture-refactor.md` §"Where isolation is deliberately simplified today." |
| `poco-agents/` | Rust | The original tmux-based sub-agent runtime (spawn/track/tool agents in a sandbox). | Superseded by Goose (c2) spawning `claude-agent-acp` / `codex-acp`. Would only return if the project moved off Goose's own agent/session model. |

## Ground rules

- **Do not import from `dormant/` into active code.** If something here becomes
  needed, move it back into `services/` (or the relevant module) as a deliberate,
  reviewed step — don't reach across the boundary.
- These crates may not compile against current dependencies; they are snapshots,
  not maintained builds.
- Git history is preserved across the move — use `git log --follow` to trace a
  file back through its `services/` life.
