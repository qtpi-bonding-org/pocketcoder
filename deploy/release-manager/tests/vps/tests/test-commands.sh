. "$VPS_DIR/lib/commands.sh"

runner=$(CDPATH= cd -- "$VPS_DIR/../../../.." && pwd)/client/packages/pocketcoder_flutter/lib/infrastructure/os_control/ssh_root_command_runner.dart

check "commands: updateNixOs matches the shipped constant" \
  "nixos-rebuild switch --upgrade" \
  "$(shipped_command updateNixOs)"

check "commands: restartNixOs matches the shipped constant" \
  "systemctl reboot" \
  "$(shipped_command restartNixOs)"

check "commands: saveBackup matches the shipped constant" \
  "docker exec pocketcoder-pocketbase /app/backup_db.sh" \
  "$(shipped_command saveBackup)"

# Drift guard: every command string must literally appear in the Dart source.
# The Dart constants are split across adjacent literals for formatting. Strip
# that formatting before checking their literal value.
dart_source_compact=$(tr -d '[:space:]' < "$runner" | sed "s/'//g; s/\"//g")
for name in restartPocketCoder updatePocketCoder restartNixOs updateNixOs saveBackup \
  exportCaddyCertificate restoreCaddyCertificate; do
  needle=$(shipped_command "$name")
  needle_compact=$(printf '%s' "$needle" | tr -d '[:space:]' | sed "s/'//g; s/\"//g")
  if printf '%s' "$dart_source_compact" | grep -Fq "$needle_compact"; then
    check "commands: $name present in ssh_root_command_runner.dart" yes yes
  else
    check "commands: $name present in ssh_root_command_runner.dart" yes no
  fi
done

shipped_command bogus >/dev/null 2>&1
check_rc "commands: unknown name fails" 1 "$?"
