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
