{ config, pkgs, sourceCommit ? "main", ... }:

{
  systemd.services.pocketcoder-bootstrap = {
    description = "PocketCoder first-boot provisioning";
    wantedBy = [ "multi-user.target" ];
    after = [ "docker.service" "network-online.target" "caddy.service" ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" ];
    environment.POCKETCODER_REF = sourceCommit;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "infinity";
    };
    path = with pkgs; [
      curl
      jq
      coreutils
      gnused
      gnugrep
      gawk
      gzip
      gnutar
      config.virtualisation.docker.package
    ];
    script = builtins.readFile ./bootstrap.sh;
  };

  environment.etc."pocketcoder/status.sh".source = ./status.sh;
}
