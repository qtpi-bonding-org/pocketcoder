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
# No --secret flag here on purpose: the per-instance secret
# hooks.ProvisionHarnessInstance mints is delivered at container-start time
# via the HARNESS_ADAPTER_SECRET env var, rendered from this harness's
# harnesses.launch_template.env_template (e.g.
# {"HARNESS_ADAPTER_SECRET": "{{.__adapter_secret}}"}) into CreateSpec.Env.
# Docker sets a container's process environment from that Env regardless of
# exec vs shell ENTRYPOINT form, so exec-form below still sees it — no shell
# wrapper needed. harness-adapter reads HARNESS_ADAPTER_SECRET itself
# whenever --secret isn't passed on the command line.
ENTRYPOINT ["harness-adapter", "--cmd", "claude-agent-acp", "--port", "3000"]
