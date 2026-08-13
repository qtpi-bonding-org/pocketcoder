#!/usr/bin/env bash
set -euo pipefail

# Single deterministic OpenAPI generation entry point. The implementation is
# kept in a separate implementation script so CI and developer tooling share
# one stable entry point.
exec "$(dirname "${BASH_SOURCE[0]}")/generate_openapi_impl.sh" "$@"
