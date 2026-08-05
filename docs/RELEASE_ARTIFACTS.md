# Coupled deployment releases

The Linode deployment is released as one source-identified bundle. A release
is valid only when the NixOS image and Docker image cache were built by the
same GitHub Actions run from the same commit.

## Release flow

`.github/workflows/nixos-image.yml` builds immutable objects named with the
workflow commit:

- `pocketcoder-nixos-<sha>.img.gz`
- `pocketcoder-docker-images-<sha>.tar.gz`
- `release-<sha>.json`

The `promote` job runs only after both build jobs succeed. It validates the
source commit in both metadata files, publishes the coupled release record,
and then advances the mutable compatibility pointers (`image-manifest.json`,
`docker-images-manifest.json`, and the legacy `-latest` objects).

## Exact source pinning

CI overwrites `deploy/nixos/release-commit.nix` with the workflow SHA before
building the NixOS image. That value is passed into the NixOS module and
embedded in the first-boot bootstrap service. Bootstrap fetches and checks out
that exact SHA before starting Docker Compose; it never silently deploys a
later `main` revision.

The Docker cache metadata carries the same SHA. Bootstrap refuses to load a
cache whose source identity does not match the NixOS image and builds the
stack from source instead.

## Verification record

For a phone verification run, record all of these together:

- Git commit SHA
- `release-<sha>.json` source identity
- NixOS image SHA-256
- Docker cache SHA-256
- Flutter artifact version/build
- UTC test timestamp

The release workflow is triggered manually or by a `v*-nixos` tag. A normal
development Docker build remains possible; its NixOS image uses the local
`main` default in `release-commit.nix`.
