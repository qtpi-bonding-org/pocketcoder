# c1/c2 agent acceptance suite

This is the opt-in acceptance suite for the active runtime:

```text
authenticated test user -> PocketBase c1 -> Goose c2
```

It deliberately does **not** exercise the retired Interface/OpenCode path or
the dormant sandbox/MCP path.

## Run

Provide real Goose/provider configuration and an existing ordinary PocketBase
test account (never a superuser), then run:

```sh
export GOOSE_SERVER__SECRET_KEY='local-test-secret'
export ANTHROPIC_API_KEY='...'
export ANTHROPIC_HOST='https://api.minimax.io/anthropic' # if applicable
export GOOSE_MODEL='MiniMax-M2.5'                        # if applicable
export AGENT_TEST_EMAIL='agent-test@example.com'
export AGENT_TEST_PASSWORD='...'
./tests/compose/agent/run.sh

### Local Ollama integration

This opt-in test uses the Linux-only private Docker topology, pulls a small
tool-calling model into the persistent Ollama volume, verifies a native tool
call, and drives a real Goose ACP turn through the production coordinator.
It is intentionally excluded from normal CI because it downloads a model and
performs CPU inference.

```bash
export GOOSE_SERVER__SECRET_KEY='local-test-secret'
bash ./tests/compose/agent/ollama-integration.sh
```

Use `OLLAMA_SMOKE_MODEL` to select another installed/pullable model and
`OLLAMA_SMOKE_TIMEOUT_SECONDS` to adjust the default five-minute CPU budget.
```

The runner starts only the `agent` profile services plus a disposable BATS
container. It creates and deletes its own chats. Because it uses a real model,
it is intentionally not part of the default fast test command.

## Coverage

- prompt plus same-chat `session/load` reconnect
- owned Goose-history replay and unmapped empty replay
- offered permission allow and deny
- cancel while permission is pending
- concurrent run returns HTTP 409 before a second SSE response begins
- c1 restart invalidates an outstanding in-memory approval and unblocks the
  same chat for a later run
- c2 restart resumes the durable Goose session
