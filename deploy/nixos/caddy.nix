{ config, pkgs, ... }:

{
  # --- IP detection + Caddyfile generation ---
  systemd.services.detect-public-ip = {
    description = "Detect public IP and generate Caddyfile with sslip.io domain";
    wantedBy = [ "multi-user.target" ];
    before = [ "caddy.service" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = with pkgs; [ curl coreutils ];
    script = ''
      set -euo pipefail

      mkdir -p /etc/caddy /etc/pocketcoder

      # Fetch public IP with retries, trying multiple providers each round
      # so a single provider outage doesn't strand the whole deployment.
      PUBLIC_IP=""
      for i in 1 2 3 4 5; do
        for url in https://ifconfig.me/ip https://api.ipify.org https://icanhazip.com; do
          PUBLIC_IP=$(curl -sf --max-time 10 "$url" | tr -d '[:space:]' || true)
          if [ -n "$PUBLIC_IP" ]; then
            break 2
          fi
        done
        echo "Attempt $i: failed to fetch public IP from any provider, retrying in 5s..."
        sleep 5
      done

      if [ -z "$PUBLIC_IP" ]; then
        echo "ERROR: Could not determine public IP after 5 attempts"
        exit 1
      fi

      echo "Detected public IP: $PUBLIC_IP"

      # Convert dots to dashes for sslip.io domain
      IP_DASHED=$(echo "$PUBLIC_IP" | tr '.' '-')
      DOMAIN="''${IP_DASHED}.sslip.io"

      echo "sslip.io domain: $DOMAIN"

      # Write Caddyfile
      cat > /etc/caddy/Caddyfile <<EOF
      http://$DOMAIN {
        handle /_pocketcoder/status.json {
          uri strip_prefix /_pocketcoder
          root * /var/lib/pocketcoder/public
          file_server
        }
        handle {
          redir https://{host}{uri} permanent
        }
      }

      $DOMAIN {
        handle /_pocketcoder/status.json {
          uri strip_prefix /_pocketcoder
          root * /var/lib/pocketcoder/public
          file_server
        }
        handle {
          reverse_proxy localhost:8090
        }
      }
      EOF

      # Write domain env for PocketCoder services
      cat > /etc/pocketcoder/domain.env <<EOF
      BASE_DOMAIN=$DOMAIN
      PUBLIC_IP=$PUBLIC_IP
      PB_URL=https://$DOMAIN
      EOF
    '';
  };

  # --- Caddy reverse proxy ---
  # Enable Caddy but override ExecStart to use our runtime-generated Caddyfile.
  # We can't use services.caddy.configFile because the Caddyfile doesn't exist
  # at Nix evaluation time — it's generated at boot by detect-public-ip.
  services.caddy.enable = true;

  systemd.services.caddy = {
    after = [ "detect-public-ip.service" ];
    requires = [ "detect-public-ip.service" ];
    # The upstream caddy.service unit (pulled in via `systemd.packages =
    # [ cfg.package ]` inside nixpkgs' caddy module) already sets its own
    # ExecStart, and is Type=notify, not oneshot -- so a plain `lib.mkForce
    # "cmd"` here renders as a bare `ExecStart=cmd` override drop-in that
    # gets appended alongside the package's own ExecStart= line rather
    # than replacing it, giving a Type=notify unit two ExecStart
    # directives. systemd rejects that outright at load time ("Unit
    # caddy.service has a bad unit file setting", confirmed via live SSH
    # diagnostics -- Caddy never even attempted to start). The fix is the
    # same empty-string-then-value list nixpkgs' own module uses to
    # override ExecStart on a package-provided unit: the leading "" is
    # the actual systemd directive to reset prior ExecStart= values
    # before setting the real one.
    serviceConfig.ExecStart = [
      ""
      "${pkgs.caddy}/bin/caddy run --config /etc/caddy/Caddyfile --adapter caddyfile"
    ];
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/pocketcoder 0755 root root -"
    "d /var/lib/pocketcoder/public 0755 root root -"
  ];
}
