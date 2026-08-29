# v1.43.0. Bumped from v1.36.0 to pick up v1.39.0's secret-key enforcement on
# the goose serve ACP endpoint (WebSocket included, via ?token=), which lets c1
# reach goose directly over an authenticated WS and retires the nginx relay.
# The wrapper owns only deployment policy; Goose itself remains the agent-server.
FROM ghcr.io/aaif-goose/goose@sha256:b5e2d93bba1a6a6b9302ad3fa70e01fe7a0a5e68c127954653d3b95101c31409

USER root
# .pocketcoder_auth/config is mounted as its own named volume in some
# compose layouts (e.g. docker-compose.agent-test.yml's fixed goose
# fixture). It must exist in the image, or Docker has nothing to
# initialize a fresh named volume from at that path.
RUN mkdir -p /workspace/.pocketcoder_auth/config
COPY entrypoint.sh /usr/local/bin/pocketcoder-goose
RUN chmod 0555 /usr/local/bin/pocketcoder-goose

# Deliberately no USER drop here, matching every sibling harness image
# (server/harness-adapter/Dockerfile, shared by claude-code/codex/opencode,
# has no USER directive at all -- they all run as root). Goose was the only
# harness that dropped to a non-root user, and it's exactly why goose (and
# only goose) hit "permission denied" writing to /workspace: /workspace is
# a named Docker volume, and a chown applied at image build time only
# carries over the FIRST time that specific volume is ever initialized --
# it does nothing for a volume that already existed (e.g. created by an
# older image, or before a chown fix like this repo's own history), which
# then stays root-owned forever regardless of how many times the image is
# rebuilt. Running as root the whole time sidesteps the whole class of bug:
# there is no ownership for a stale volume to get wrong.
WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/pocketcoder-goose"]
