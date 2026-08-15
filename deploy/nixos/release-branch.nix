# The GitHub Actions workflow-ref branch the box's first-boot bootstrap and
# periodic release-metadata check trust for attestation verification
# (POCKETCODER_GITHUB_WORKFLOW_BRANCH; see
# deploy/release-manager/internal/trust/attestation.go). CI leaves this at
# "main" on every normal build -- it is only ever overwritten to "staging"
# by an explicit, non-default workflow_dispatch input on nixos-image.yml,
# never automatically just because a push happened to build from staging.
# Keep a useful local default for manually-built development images.
"main"
