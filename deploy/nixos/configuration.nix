{ config, pkgs, lib, modulesPath, ... }:

let
  # The image is built from a flake, so /etc/nixos is empty at runtime and
  # the shipped owner-control command (`nixos-rebuild switch --upgrade`, no
  # `--flake`) cannot resolve a configuration unless every module this
  # system needs is inlined here and persisted to /etc/nixos below. See
  # docs/superpowers/specs/2026-08-15-vps-script-test-suite-hardening-design.md,
  # "NixOS configuration fix".
  #
  # caddy.nix and release-manager.nix each read one file from outside
  # deploy/nixos/ via a relative path that only resolves against a full repo
  # checkout (the CI build machine). A live on-box rebuild has no such
  # checkout, so both dependencies are persisted alongside the .nix files
  # under /etc/nixos and each module falls back to the persisted copy when
  # present -- otherwise the original repo-relative path, so the very first
  # (flake) build still works unchanged.
  # `nixos-rebuild`'s NIX_PATH `nixos-config=/etc/nixos/configuration.nix`
  # lookup copies only that one file into the store, without its sibling
  # files -- so a live rebuild's own relative imports/reads from THIS file
  # (and, transitively, from bootstrap.nix once loaded the same way) break
  # even though the siblings are still on disk. An absolute /etc/nixos
  # literal *inside* a coalesced file is fine; a relative one isn't. Every
  # dependency below therefore prefers its real, already-persisted absolute
  # path when present, falling back to the repo-relative path so the very
  # first (flake) build -- which has no /etc/nixos to persist to yet --
  # still resolves against the real checkout unchanged.
  # The persisted path is reached through /etc/nixos -> /etc/static/nixos ->
  # a Nix store path (environment.etc's own symlink chain). Copying a bare
  # symlink as a derivation `src` (release-manager-src, a directory) is
  # copied as the symlink object itself rather than a real directory tree,
  # so `unpackPhase` can't recognize it ("do not know how to unpack source
  # archive") even though the same value works fine as a module `import`.
  # `builtins.path` forces a real, dereferenced content copy either way.
  persisted = name: repoRelative:
    if builtins.pathExists (/etc/nixos + "/${name}")
    then builtins.path { path = /etc/nixos + "/${name}"; inherit name; }
    else repoRelative;

  configurationModule = persisted "configuration.nix" ./configuration.nix;
  caddyModule = persisted "caddy.nix" ./caddy.nix;
  bootstrapModule = persisted "bootstrap.nix" ./bootstrap.nix;
  releaseManagerModule = persisted "release-manager.nix" ./release-manager.nix;
  releaseCommitModule = persisted "release-commit.nix" ./release-commit.nix;
  releaseBranchModule = persisted "release-branch.nix" ./release-branch.nix;
  bootstrapScript = persisted "bootstrap.sh" ./bootstrap.sh;
  statusScript = persisted "status.sh" ./status.sh;
  caddyTemplate = persisted "Caddyfile.template"
    ../../client/packages/pocketcoder_flutter/assets/deployment/Caddyfile.template;
  tlsStatusScript = persisted "tls-status.sh" ../scripts/tls-status.sh;
  releaseManagerSrc = persisted "release-manager-src" ../release-manager;

  sourceCommit = import releaseCommitModule;
  releaseBranch = import releaseBranchModule;
  releaseManager = import releaseManagerModule { inherit pkgs releaseManagerSrc; };

  # The single source of truth for which NixOS release line this image
  # pins. Used below to build the NIX_PATH nixpkgs entry a live
  # `nixos-rebuild switch --upgrade` reads, and exposed as a plain
  # /etc/nixos/nixos-version file so pocketcoder-release can read it without
  # parsing Nix. flake.nix's `nixpkgs.url` input must be kept in sync with
  # this value by hand -- flake inputs have to be static string literals,
  # they can't reference a value computed by the module they're building --
  # but deploy/ci/assemble-release-manifest.sh cross-checks the two at
  # publish time and fails the build if they ever drift apart.
  nixosVersion = "26.05";
in
{
  imports = [
    # Linode uses KVM — virtio drivers, QEMU guest agent
    "${modulesPath}/profiles/qemu-guest.nix"
    (import caddyModule { inherit config pkgs caddyTemplate tlsStatusScript; })
    (import bootstrapModule {
      inherit config pkgs sourceCommit releaseBranch releaseManager bootstrapScript statusScript;
    })
  ];

  # Persist every module this configuration needs (plus their repo-external
  # file dependencies) so a live `nixos-rebuild switch --upgrade` -- run
  # with no repo checkout on the box -- can resolve the identical module
  # set the image was originally built with. Each source reuses the same
  # `persisted` value used above to consume it: on the very first build
  # that copies fresh from the repo; on every later live rebuild it
  # re-copies the already-persisted file onto itself, which is an ordinary
  # absolute-path copy, not subject to the coalescing problem above.
  environment.etc."nixos/configuration.nix".source = configurationModule;
  environment.etc."nixos/caddy.nix".source = caddyModule;
  environment.etc."nixos/bootstrap.nix".source = bootstrapModule;
  environment.etc."nixos/release-manager.nix".source = releaseManagerModule;
  environment.etc."nixos/release-commit.nix".source = releaseCommitModule;
  environment.etc."nixos/release-branch.nix".source = releaseBranchModule;
  environment.etc."nixos/bootstrap.sh".source = bootstrapScript;
  environment.etc."nixos/status.sh".source = statusScript;
  environment.etc."nixos/Caddyfile.template".source = caddyTemplate;
  environment.etc."nixos/tls-status.sh".source = tlsStatusScript;
  environment.etc."nixos/release-manager-src".source = releaseManagerSrc;
  environment.etc."nixos/nixos-version".text = nixosVersion;

  nix.nixPath = [
    "nixos-config=/etc/nixos/configuration.nix"
    "nixpkgs=https://github.com/NixOS/nixpkgs/archive/nixos-${nixosVersion}.tar.gz"
  ];

  system.stateVersion = "25.05";

  # --- Nix settings ---
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # --- Linode boot ---
  boot.loader.grub = {
    enable = true;
    forceInstall = true;
    device = "nodev";
    extraConfig = ''
      serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1
      terminal_input serial console
      terminal_output serial console
    '';
  };
  boot.kernelParams = [ "console=ttyS0,115200n8" ];
  boot.loader.timeout = 10;

  # POCO:BEGIN vps-storage
  # Root filesystem (Linode provides a single disk). autoResize is
  # required for boot-time-pull provisioning: dd-ing this image onto a
  # bigger raw disk does not grow the filesystem on its own -- without
  # this, every deployment is capped at the image's original ~4.7GB
  # regardless of the real disk size (docs/superpowers/specs/
  # 2026-07-29-linode-boot-time-image-provisioning-design.md, "NixOS
  # image change required").
  fileSystems."/" = {
    device = "/dev/sda";
    fsType = "ext4";
    autoResize = true;
  };
  # POCO:END vps-storage

  # --- Networking ---
  networking.hostName = "pocketcoder";
  networking.useDHCP = false;
  networking.interfaces.eth0.useDHCP = true;

  # POCO:BEGIN vps-public-firewall
  # Firewall: only expose what's needed
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      80    # HTTP (Caddy → HTTPS redirect)
      443   # HTTPS (Caddy → PocketBase)
      22    # SSH
    ];
    allowedUDPPorts = [
      443   # Caddy HTTP/3
    ];
  };
  # POCO:END vps-public-firewall

  # POCO:BEGIN vps-container-firewall
  # Docker's DNAT/FORWARD path is separate from the host firewall INPUT
  # chain. Apply the same public allowlist as standard Linux after Docker has
  # created DOCKER-USER; this also blocks containers from reaching Linode's
  # metadata service, which can expose bootstrap credentials.
  systemd.services.pocketcoder-docker-firewall = {
    description = "PocketCoder Docker forwarding firewall";
    after = [ "docker.service" ];
    wants = [ "docker.service" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [ pkgs.iptables ];
    script = ''
      set -euo pipefail

      apply_ipv4_rules() {
        iptables -N POCKETCODER-DOCKER 2>/dev/null || true
        iptables -F POCKETCODER-DOCKER
        iptables -A POCKETCODER-DOCKER -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
        iptables -A POCKETCODER-DOCKER -d 169.254.169.254 -j DROP
        iptables -A POCKETCODER-DOCKER -s 127.0.0.0/8 -j RETURN
        iptables -A POCKETCODER-DOCKER -s 10.0.0.0/8 -j RETURN
        iptables -A POCKETCODER-DOCKER -s 172.16.0.0/12 -j RETURN
        iptables -A POCKETCODER-DOCKER -s 192.168.0.0/16 -j RETURN
        iptables -A POCKETCODER-DOCKER -s 100.64.0.0/10 -j RETURN
        iptables -A POCKETCODER-DOCKER -p tcp -m multiport --dports 80,443 -j RETURN
        iptables -A POCKETCODER-DOCKER -m conntrack --ctstate NEW -j DROP
        iptables -A POCKETCODER-DOCKER -j RETURN
        iptables -C DOCKER-USER -j POCKETCODER-DOCKER 2>/dev/null || \
          iptables -I DOCKER-USER 1 -j POCKETCODER-DOCKER
      }

      apply_ipv6_rules() {
        ip6tables -N POCKETCODER-DOCKER 2>/dev/null || true
        ip6tables -F POCKETCODER-DOCKER
        ip6tables -A POCKETCODER-DOCKER -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
        ip6tables -A POCKETCODER-DOCKER -s ::1/128 -j RETURN
        ip6tables -A POCKETCODER-DOCKER -s fc00::/7 -j RETURN
        ip6tables -A POCKETCODER-DOCKER -s fe80::/10 -j RETURN
        ip6tables -A POCKETCODER-DOCKER -p tcp -m multiport --dports 80,443 -j RETURN
        ip6tables -A POCKETCODER-DOCKER -m conntrack --ctstate NEW -j DROP
        ip6tables -A POCKETCODER-DOCKER -j RETURN
        ip6tables -C DOCKER-USER -j POCKETCODER-DOCKER 2>/dev/null || \
          ip6tables -I DOCKER-USER 1 -j POCKETCODER-DOCKER
      }

      apply_ipv4_rules
      apply_ipv6_rules
    '';
  };
  # POCO:END vps-container-firewall

  # --- SSH ---
  # POCO:BEGIN vps-key-only-ssh
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = false;
      AllowAgentForwarding = false;
      AllowTcpForwarding = false;
      PermitTunnel = false;
      MaxAuthTries = 3;
      LoginGraceTime = 20;
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;
      UseDns = false;
    };
  };

  # Public SSH is required for owner administration and first-boot recovery,
  # but password/key-spam should not consume the box indefinitely. This is a
  # second line of defense; the real credential boundary remains the SSH key.
  services.fail2ban = {
    enable = true;
    maxretry = 5;
    bantime = "1h";
    jails = {
      sshd.settings = {
        enabled = true;
        backend = "systemd";
        mode = "aggressive";
        maxretry = 5;
      };
    };
  };
  # POCO:END vps-key-only-ssh

  # --- Docker ---
  # POCO:BEGIN vps-docker-engine
  virtualisation.docker = {
    enable = true;
    logDriver = "journald";
  };
  # POCO:END vps-docker-engine

  # --- System packages ---
  environment.systemPackages = with pkgs; [
    git
    curl
    jq
    htop
  ];

  # --- LISH serial console ---
  systemd.services."serial-getty@ttyS0" = {
    enable = true;
    wantedBy = [ "getty.target" ];
  };
}
