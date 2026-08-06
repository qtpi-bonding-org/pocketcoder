{ config, pkgs, lib, modulesPath, ... }:

{
  imports = [
    # Linode uses KVM — virtio drivers, QEMU guest agent
    "${modulesPath}/profiles/qemu-guest.nix"
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

  # --- Networking ---
  networking.hostName = "pocketcoder";
  networking.useDHCP = false;
  networking.interfaces.eth0.useDHCP = true;

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
    # Docker's own DNAT/FORWARD rules run outside the firewall's INPUT
    # chain, so `allowedTCPPorts` above can't stop a container from
    # reaching the Linode instance-metadata endpoint -- and any container
    # that can (including goose, which runs model-directed code) could read
    # the same user-data/secrets bootstrap.nix consumes. Docker always
    # creates a DOCKER-USER chain and guarantees it's consulted before its
    # own FORWARD rules, so this is the supported hook point for that.
    extraCommands = ''
      iptables -C DOCKER-USER -d 169.254.169.254 -j DROP 2>/dev/null || \
        iptables -I DOCKER-USER -d 169.254.169.254 -j DROP
    '';
  };

  # --- SSH ---
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
      UseDNS = false;
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

  # --- Docker ---
  virtualisation.docker = {
    enable = true;
    logDriver = "journald";
  };

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
