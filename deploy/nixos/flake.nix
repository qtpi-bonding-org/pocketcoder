{
  description = "PocketCoder NixOS server image for Linode";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
    sourceCommit = import ./release-commit.nix;
    releaseManager = import ./release-manager.nix { inherit pkgs; };
  in {
    nixosConfigurations.pocketcoder = nixpkgs.lib.nixosSystem {
      inherit system;
      # configuration.nix imports caddy.nix and bootstrap.nix itself (with
      # sourceCommit/releaseManager computed the same way as below), so a
      # live on-box `nixos-rebuild switch --upgrade` -- no --flake, no
      # specialArgs -- resolves the identical module set. Listing them here
      # too would double-import them.
      modules = [
        ./configuration.nix
      ];
    };

    packages.${system} = {
      release-manager = releaseManager;

    # Built directly via make-disk-image.nix (not nixos-generators' "raw"
    # format) with partitionTableType = "none": this matches Linode's own
    # documented NixOS install approach (unpartitioned disk, GRUB
    # chainloaded from grub.cfg via `forceInstall`/`device = "nodev"` in
    # configuration.nix) -- nixos-generators' raw format instead assumes a
    # partitioned disk with its own fileSystems."/" and grub.device
    # defaults, which directly conflicted with the config below.
      linode-image = import "${nixpkgs}/nixos/lib/make-disk-image.nix" {
        inherit pkgs;
        inherit (pkgs) lib;
        config = self.nixosConfigurations.pocketcoder.config;
        partitionTableType = "none";
        format = "raw";
        # Produces a raw .img suitable for Linode custom images API
        # Upload with: linode-cli image-upload --region us-east result/nixos.img
      };
    };

    # A single assignment: `checks.${system}.a = ...; checks.${system}.b =
    # ...;` as separate top-level bindings does NOT merge the way it would
    # with static attribute names -- `${system}` makes the whole path
    # dynamic, and Nix rejects defining the same dynamic path twice
    # ("dynamic attribute 'x86_64-linux' already defined"). Confirmed live
    # in CI. All checks live in one attrset here instead.
    checks.${system} = {
      ordering = import ./tests/ordering.nix { inherit pkgs self system; };

      # ordering.nix's VM test replaces detect-public-ip.script with a
      # hand-written fake Caddyfile, so it structurally can never catch a
      # syntax error in the real Caddyfile.template -- confirmed live: a
      # Caddyfile.template change (90f12ffaf) shipped an invalid `issuer
      # zerossl` directive (needs an API-key argument it never got) that
      # broke every box's Caddy/HTTPS from first boot, and nothing in CI
      # rendered or parsed the real template to notice. This renders it
      # with the exact sed pipeline caddy.nix uses and runs `caddy
      # validate` against the result.
      caddyfile-validate = pkgs.runCommand "pocketcoder-caddyfile-validate" { } ''
        set -eu
        sed \
          -e 's|{{CADDY_GLOBAL_OPTIONS}}||g' \
          -e 's|{{DOMAIN}}|test.sslip.io|g' \
          -e 's|{{STATUS_ROOT}}|/var/lib/pocketcoder/public|g' \
          -e 's|{{UPSTREAM}}|127.0.0.1:8090|g' \
          ${../../client/packages/pocketcoder_flutter/assets/deployment/Caddyfile.template} \
          > Caddyfile
        ${pkgs.caddy}/bin/caddy validate --config Caddyfile --adapter caddyfile
        touch $out
      '';

      # A module can be syntactically valid Nix and still produce a broken
      # systemd unit -- confirmed live: bootstrap.nix nested
      # StartLimitIntervalSec/StartLimitBurst (a [Unit]-section directive)
      # inside serviceConfig (which only ever writes [Service]), and
      # systemd silently dropped them rather than erroring, leaving the
      # manager's default 10s/burst-5 restart window in effect instead of
      # the intended one. systemd-analyze verify is the tool built to
      # catch exactly this class of "valid config, wrong section" mistake.
      # `systemd-analyze verify` is the properly thorough tool for this,
      # but it needs to create the real /run/systemd/ for its own runtime
      # state regardless of --root or which unit-file form it's given --
      # confirmed live, interactively, both with --root+unit-name (which
      # separately turned out to have its own bug: it resolves
      # ExecStart='s already-absolute /nix/store/... path as if it were
      # relative to --root) and with a direct unit-file path. A nix build
      # sandbox never has a writable /run, and there's no supported way to
      # get one from inside a sandboxed derivation. Falls back to a
      # static, sandbox-safe check for the exact bug class this exists to
      # catch: a [Unit]-only directive silently accepted inside
      # `serviceConfig` (which only ever writes [Service]).
      systemd-units =
        let toplevel = self.nixosConfigurations.pocketcoder.config.system.build.toplevel;
        in pkgs.runCommand "pocketcoder-systemd-verify" { } ''
          set -eu
          fail=0
          for unit in pocketcoder-bootstrap.service caddy.service \
            pocketcoder-tls-status.service pocketcoder-release-metadata.service; do
            echo "checking $unit"
            file="${toplevel}/etc/systemd/system/$unit"
            # Extract only the [Service] section, then look for any
            # directive that belongs to [Unit] instead. This list is the
            # directives most likely to be written expecting [Unit]
            # semantics (restart-limiting, conditions, ordering) -- not
            # exhaustive of every systemd.unit(5) [Unit] key, but it's the
            # class of mistake that's actually plausible here.
            section=$(${pkgs.gawk}/bin/awk \
              '/^\[Service\]/{f=1;next} /^\[/{f=0} f' "$file")
            misplaced=$(printf '%s\n' "$section" | ${pkgs.gnugrep}/bin/grep -E \
              '^(StartLimitIntervalSec|StartLimitBurst|StartLimitAction|ConditionPathExists|ConditionPathExistsGlob|After|Before|Wants|Requires|BindsTo|PartOf|OnFailure)=' \
              || true)
            if [ -n "$misplaced" ]; then
              echo "$unit: [Unit]-only directive(s) found inside [Service]:" >&2
              printf '%s\n' "$misplaced" >&2
              fail=1
            fi
          done
          [ "$fail" -eq 0 ]
          touch $out
        '';
    };
  };
}
