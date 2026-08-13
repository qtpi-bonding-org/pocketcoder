{ config, pkgs, sourceCommit ? "main", rootPublicKey ? "", ... }:

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
      config.services.openssh.package
      config.virtualisation.docker.package
    ];
    script = builtins.readFile ./bootstrap.sh;
  };

  environment.etc."pocketcoder/status.sh".source = ./status.sh;
  environment.etc."pocketcoder/release-root.pem" = {
    text = rootPublicKey;
    mode = "0444";
  };
  environment.etc."pocketcoder/release/resolve-signed-release.sh" = {
    source = ../scripts/resolve-signed-release.sh;
    mode = "0555";
  };
  environment.etc."pocketcoder/release/verify-signed-payload.sh" = {
    source = ../release/verify-signed-payload.sh;
    mode = "0555";
  };

  systemd.services.pocketcoder-release-metadata = {
    description = "Check signed PocketCoder release metadata";
    after = [ "network-online.target" "pocketcoder-bootstrap.service" ];
    wants = [ "network-online.target" ];
    unitConfig.ConditionPathExists = "/opt/pocketcoder/current/bin/pocketcoder-release";
    serviceConfig.Type = "oneshot";
    script = ''
      /opt/pocketcoder/current/bin/pocketcoder-release check-metadata
    '';
  };

  systemd.timers.pocketcoder-release-metadata = {
    description = "Periodically check signed PocketCoder release metadata";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "15min";
      OnUnitActiveSec = "6h";
      RandomizedDelaySec = "1h";
      Persistent = true;
    };
  };
}
