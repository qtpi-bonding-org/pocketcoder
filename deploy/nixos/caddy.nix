{ config, pkgs, lib, ... }:

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

      # Fetch public IP with retries
      PUBLIC_IP=""
      for i in 1 2 3 4 5; do
        PUBLIC_IP=$(curl -sf --max-time 10 https://ifconfig.me/ip || true)
        if [ -n "$PUBLIC_IP" ]; then
          break
        fi
        echo "Attempt $i: failed to fetch public IP, retrying in 5s..."
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
      $DOMAIN {
        reverse_proxy localhost:8090
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
    serviceConfig.ExecStart = lib.mkForce
      "${pkgs.caddy}/bin/caddy run --config /etc/caddy/Caddyfile --adapter caddyfile";
  };
}
