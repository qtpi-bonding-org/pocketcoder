# The single source of truth for which NixOS release line this image
# pins. Overwritten wholesale by a future `upgrade os` action, never
# text-edited in place -- see release-branch.nix for the established
# pattern this follows. flake.nix's nixpkgs.url input
# has to independently repeat this same value (flake inputs must be
# static string literals, can't reference a value computed elsewhere) --
# deploy/ci/assemble-release-manifest.sh cross-checks the two at publish
# time and fails the build if they ever drift apart.
"26.05"
