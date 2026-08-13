# v1.43.0. Bumped from v1.36.0 to pick up v1.39.0's secret-key enforcement on
# the goose serve ACP endpoint (WebSocket included, via ?token=), which lets c1
# reach goose directly over an authenticated WS and retires the nginx relay.
# The wrapper owns only deployment policy; Goose itself remains the agent-server.
FROM ghcr.io/aaif-goose/goose@sha256:b5e2d93bba1a6a6b9302ad3fa70e01fe7a0a5e68c127954653d3b95101c31409

USER root
RUN mkdir -p /workspace/.pocketcoder_auth \
    && chown -R goose:goose /workspace
COPY entrypoint.sh /usr/local/bin/pocketcoder-goose
RUN chmod 0555 /usr/local/bin/pocketcoder-goose

USER goose
WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/pocketcoder-goose"]
