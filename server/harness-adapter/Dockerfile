# Example: bundling a stdio-native ACP harness (claude-agent-acp) with the
# harness-adapter (§5.4 of the multi-harness selection design spec). This
# is a REFERENCE for populating a harnesses.container_image — not itself
# built by this repo's own compose file, since harness images are
# per-catalog-entry, not part of the base deployment.
FROM node:20-slim AS harness-adapter-build
WORKDIR /adapter
COPY server/harness-adapter/ .
RUN go build -o /usr/local/bin/harness-adapter .  # requires a Go build stage in practice; shown collapsed here for brevity

FROM node:20-slim
RUN npm install -g @zed-industries/claude-agent-acp
COPY --from=harness-adapter-build /usr/local/bin/harness-adapter /usr/local/bin/harness-adapter
EXPOSE 3000
ENTRYPOINT ["harness-adapter", "--cmd", "claude-agent-acp", "--port", "3000"]
