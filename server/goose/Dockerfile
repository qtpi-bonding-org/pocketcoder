# v1.43.0. Bumped from v1.36.0 to pick up v1.39.0's secret-key enforcement on
# the goose serve ACP endpoint (WebSocket included, via ?token=), which lets c1
# reach goose directly over an authenticated WS and retires the nginx relay.
# The wrapper owns only deployment policy; Goose itself remains the agent-server.
FROM ghcr.io/aaif-goose/goose@sha256:b5e2d93bba1a6a6b9302ad3fa70e01fe7a0a5e68c127954653d3b95101c31409

USER root
# .pocketcoder_auth/config is mounted as its own named volume in some
# compose layouts (e.g. docker-compose.agent-test.yml's fixed goose
# fixture). It must exist in the image before the chown below, or Docker
# has nothing to copy ownership from when it initializes a fresh named
# volume at that path, and creates it as root:root instead -- silently
# blocking any write goose makes under GOOSE_PATH_ROOT/config (e.g.
# provider credential registration) until someone manually chowns it.
RUN mkdir -p /workspace/.pocketcoder_auth/config \
    && chown -R goose:goose /workspace
COPY entrypoint.sh /usr/local/bin/pocketcoder-goose
RUN chmod 0555 /usr/local/bin/pocketcoder-goose

USER goose
WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/pocketcoder-goose"]
