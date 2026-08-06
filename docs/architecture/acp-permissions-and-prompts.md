# ACP permissions and system prompts

PocketCoder has one permission authority: the PocketBase `permission_modes` and
`permission_mode_tools` records. Every harness connection (Goose, Claude Code,
Codex, and OpenCode) enters through ACP, and the coordinator handles the ACP
`session/request_permission` callback.

The coordinator resolves the selected rules before creating a Flutter pending
permission event:

- `allow` selects an offered one-shot allow option automatically;
- `deny` selects an offered one-shot reject option automatically;
- `ask` is the only result that reaches Flutter.

The harness is never allowed to persist a permission decision on PocketCoder's
behalf. Goose's private `_goose/unstable/tools/permissions/set` path has been
removed from this flow.

## System prompts

ACP defines `_meta` as an extension point, but does not define a portable
cross-agent system-prompt field. PocketCoder sends its optional prompt through
the namespaced `_meta.pocketcoder.systemPrompt` value on `session/new` and
`session/load`. An agent may ignore unknown metadata, so this is best-effort.

Prompt delivery must therefore remain a harness capability, not a permission
authority:

- Claude Code: verify the pinned `claude-agent-acp` version's prompt metadata
  support; otherwise use its documented instruction-file mechanism.
- Codex: verify the pinned `codex-acp` version; otherwise use a managed
  `AGENTS.md` fallback only after confirming the exact image behavior.
- OpenCode: its documented `AGENTS.md`/`opencode.json` instruction mechanisms
  are the fallback, with managed markers so user files are not overwritten.
- Goose: do not reintroduce a Goose-private permission or prompt RPC as the
  common path. Use ACP metadata only when supported, otherwise a separately
  verified managed instruction mechanism.

The permission path is shared and enforceable today. Prompt fallback support
must be tested per pinned image before it is enabled in production.

References:

- [Agent Client Protocol](https://github.com/agentclientprotocol/agent-client-protocol)
- [Codex ACP](https://github.com/agentclientprotocol/codex-acp)
- [Claude ACP changelog](https://github.com/agentclientprotocol/claude-agent-acp/blob/main/CHANGELOG.md)
- [OpenCode rules](https://opencode.ai/docs/rules/)
