{ pkgs, self, system }:

pkgs.testers.runNixOSTest {
  name = "pocketcoder-caddy-ordering";

  nodes.machine = { ... }: {
    # bootstrap.nix receives this from the real flake's specialArgs. Supply
    # the development default explicitly in the standalone ordering test.
    _module.args.sourceCommit = "main";
    imports = [ ../caddy.nix ../bootstrap.nix ];
    systemd.services.detect-public-ip.script = pkgs.lib.mkForce ''
      mkdir -p /etc/caddy /etc/pocketcoder
      echo 127.0.0.1 > /etc/pocketcoder/ip
      cat > /etc/caddy/Caddyfile <<EOF
      :80 {
        handle /_pocketcoder/status.json {
          uri strip_prefix /_pocketcoder
          root * /var/lib/pocketcoder/public
          file_server
        }
        handle {
          respond "no backend" 502
        }
      }
      EOF
    '';
    systemd.services.pocketcoder-bootstrap.script = pkgs.lib.mkForce ''
      systemctl is-active caddy.service > /var/lib/pocketcoder/caddy-was-active
      sleep 30
    '';
    virtualisation.docker.enable = true;
  };

  testScript = ''
    machine.wait_for_unit("caddy.service")
    machine.wait_for_unit("pocketcoder-bootstrap.service")
    machine.succeed("grep -q '^active$' /var/lib/pocketcoder/caddy-was-active")
    machine.succeed("test -d /var/lib/pocketcoder/public")
    machine.succeed("test $(stat -c %a /var/lib/pocketcoder/public) = 755")
    machine.succeed("echo '{\\\"phase\\\":\\\"loading_images\\\"}' > /var/lib/pocketcoder/public/status.json")
    machine.succeed("chmod 0644 /var/lib/pocketcoder/public/status.json")
    machine.succeed("curl -sf http://localhost/_pocketcoder/status.json | grep -q loading_images")
  '';
}
