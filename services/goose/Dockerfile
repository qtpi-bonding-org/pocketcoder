# Pinned after the Streamable-HTTP ACP compatibility spike. The wrapper owns
# only deployment policy; Goose itself remains the agent-server implementation.
FROM ghcr.io/aaif-goose/goose@sha256:8452dbb1aed8b46ec8b25895a1dd60a2e8ad89a10692f782cff32a6cbe35176e

USER root
RUN mkdir -p /goose /workspace && chown -R goose:goose /goose /workspace
COPY entrypoint.sh /usr/local/bin/pocketcoder-goose
RUN chmod 0555 /usr/local/bin/pocketcoder-goose

USER goose
WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/pocketcoder-goose"]
