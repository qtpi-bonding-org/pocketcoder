#!/usr/bin/env bash
# The literal remote commands the app ships, mirrored from
# client/packages/pocketcoder_flutter/lib/infrastructure/os_control/
#   ssh_root_command_runner.dart
# tests/test-commands.sh asserts these still appear in that file, so drift
# fails locally instead of silently passing on a VPS.

shipped_command() {
  case $1 in
    restartPocketCoder)
      cat <<'EOF'
if [ -f /opt/pocketcoder/current/docker-compose.prebuilt.yml ]; then if docker compose version >/dev/null 2>&1; then docker compose --project-name pocketcoder --env-file /var/lib/pocketcoder/config/runtime.env -f /opt/pocketcoder/current/docker-compose.prebuilt.yml restart; else docker-compose --project-name pocketcoder --env-file /var/lib/pocketcoder/config/runtime.env -f /opt/pocketcoder/current/docker-compose.prebuilt.yml restart; fi; else echo "PocketCoder Compose release was not found" >&2; exit 1; fi
EOF
      ;;
    updatePocketCoder)
      cat <<'EOF'
if [ -x /opt/pocketcoder/current/bin/pocketcoder-release ]; then /opt/pocketcoder/current/bin/pocketcoder-release update; else echo "PocketCoder release manager was not found" >&2; exit 1; fi
EOF
      ;;
    restartNixOs) printf '%s\n' 'systemctl reboot' ;;
    updateNixOs) printf '%s\n' 'nixos-rebuild switch --upgrade' ;;
    saveBackup) printf '%s\n' 'docker exec pocketcoder-pocketbase /app/backup_db.sh' ;;
    *) echo "unknown shipped command: $1" >&2; return 1 ;;
  esac
}
