{ config, pkgs, sourceCommit ? "main", releaseBranch ? "main", releaseManager
, bootstrapScript ? ./bootstrap.sh, statusScript ? ./status.sh, ... }:

{
  systemd.services.pocketcoder-bootstrap = {
    description = "PocketCoder first-boot provisioning";
    wantedBy = [ "multi-user.target" ];
    after = [ "docker.service" "network-online.target" "caddy.service" ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" ];
    environment.POCKETCODER_REF = sourceCommit;
    environment.POCKETCODER_GITHUB_WORKFLOW_BRANCH = releaseBranch;
    # StartLimitIntervalSec/StartLimitBurst are [Unit]-section directives in
    # systemd, and NixOS's systemd module exposes them as top-level service
    # options for exactly that reason -- nesting them inside serviceConfig
    # (which only ever writes [Service]) makes systemd silently ignore them
    # ("Unknown key name" in the journal), leaving the manager's own default
    # (10s interval / burst 5) in effect instead of the wider window we
    # actually want here.
    startLimitIntervalSec = 600;
    startLimitBurst = 5;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "infinity";
      Restart = "on-failure";
      RestartSec = "10s";
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
      util-linux
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
    environment.POCKETCODER_GITHUB_WORKFLOW_BRANCH = releaseBranch;
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
