# Production image for a stdio-native ACP harness behind PocketCoder's
# authenticated WebSocket adapter. Build this Dockerfile once per agent,
# supplying the exact npm package (including version) as ACP_AGENT_PACKAGE.

FROM golang:1.23-bookworm AS adapter-build
WORKDIR /src
COPY server/harness-adapter/go.mod server/harness-adapter/go.sum ./
RUN go mod download
COPY server/harness-adapter/*.go ./
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/harness-adapter .

FROM node:22-bookworm-slim
ARG ACP_AGENT_PACKAGE
RUN test -n "$ACP_AGENT_PACKAGE" \
    && npm install --global --omit=dev "$ACP_AGENT_PACKAGE" \
    && npm cache clean --force

COPY --from=adapter-build /out/harness-adapter /usr/local/bin/harness-adapter
COPY server/harness-adapter/entrypoint.sh /usr/local/bin/pocketcoder-harness-entrypoint
COPY server/harness-adapter/opencode-ollama-config.mjs /usr/local/lib/pocketcoder/opencode-ollama-config.mjs
RUN chmod 0555 /usr/local/bin/pocketcoder-harness-entrypoint
WORKDIR /workspace
EXPOSE 3000

# ProvisionHarnessInstance supplies the agent-specific command as the
# container Cmd from harnesses.launch_template. Keeping only the adapter in
# ENTRYPOINT lets one audited image recipe package any stdio ACP agent.
ENTRYPOINT ["/usr/local/bin/pocketcoder-harness-entrypoint"]
