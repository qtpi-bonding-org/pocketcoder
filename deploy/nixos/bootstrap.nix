{ config, pkgs, sourceCommit ? "main", releaseManager
, bootstrapScript ? ./bootstrap.sh, statusScript ? ./status.sh, ... }:

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
      releaseManager
    ];
    script = builtins.readFile bootstrapScript;
  };

  environment.etc."pocketcoder/status.sh".source = statusScript;

  systemd.services.pocketcoder-release-metadata = {
    description = "Check GitHub-attested PocketCoder release metadata";
    after = [ "network-online.target" "pocketcoder-bootstrap.service" ];
    wants = [ "network-online.target" ];
    unitConfig.ConditionPathExists = "/opt/pocketcoder/current/bin/pocketcoder-release";
    serviceConfig.Type = "oneshot";
    script = ''
      /opt/pocketcoder/current/bin/pocketcoder-release check-metadata
    '';
  };

  systemd.timers.pocketcoder-release-metadata = {
    description = "Periodically check GitHub-attested PocketCoder release metadata";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "15min";
      OnUnitActiveSec = "6h";
      RandomizedDelaySec = "1h";
      Persistent = true;
    };
  };
}
