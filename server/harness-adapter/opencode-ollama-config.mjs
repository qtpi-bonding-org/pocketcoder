// Builds the local-provider fragment that Ollama normally passes to OpenCode
// through OPENCODE_CONFIG_CONTENT. Keeping it in the peer image avoids a host
// binary, discovers every model pulled into the shared Ollama service, and
// lets OpenCode merge the fragment with its normal configuration.
//
// MCP gateway attachment does NOT belong here: OpenCode's ACP server (like
// Claude Code's and Codex's ACP adapters) declares mcpServers as part of
// session/new, not a static config file -- PocketBase's session/new
// construction attaches the gateway there instead, uniformly across all
// three peer harnesses. See mcpGatewayAuthHeaders/RegisterMcpGatewayExtension
// for the equivalent Goose-side mechanism (Goose uses a persistent extension
// instead, since it isn't reconnected per-session the same way).
const baseURL = (process.env.OLLAMA_HOST || 'http://ollama:11434').replace(/\/$/, '');
const timeout = AbortSignal.timeout(5000);

try {
  const response = await fetch(baseURL + '/api/tags', {signal: timeout});
  if (!response.ok) {
    throw new Error('Ollama returned ' + response.status);
  }
  const body = await response.json();
  const models = Object.fromEntries(
    (body.models || [])
      .map((model) => model.name)
      .filter((name) => typeof name === 'string' && name.length > 0)
      .map((name) => [name, {name}]),
  );
  process.stdout.write(JSON.stringify({
    provider: {
      ollama: {
        npm: '@ai-sdk/openai-compatible',
        name: 'Ollama (local)',
        options: {baseURL: baseURL + '/v1'},
        models,
      },
    },
  }));
} catch (error) {
  console.error('PocketCoder: could not discover local Ollama models: ' + error.message);
  process.exitCode = 1;
}
