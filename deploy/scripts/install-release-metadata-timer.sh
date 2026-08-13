#!/bin/sh
set -eu

unit_dir=${POCKETCODER_SYSTEMD_UNIT_DIR:-/etc/systemd/system}
install -d -m 0755 "$unit_dir"
install -m 0644 /dev/null "$unit_dir/pocketcoder-release-metadata.service"
install -m 0644 /dev/null "$unit_dir/pocketcoder-release-metadata.timer"
printf '%s\n' \
  '[Unit]' \
  'Description=Check signed PocketCoder release metadata' \
  '' \
  '[Service]' \
  'Type=oneshot' \
  'ExecStart=/opt/pocketcoder/current/bin/pocketcoder-release check-metadata' \
  > "$unit_dir/pocketcoder-release-metadata.service"
printf '%s\n' \
  '[Unit]' \
  'Description=Periodically check signed PocketCoder release metadata' \
  '' \
  '[Timer]' \
  'OnBootSec=15min' \
  'OnUnitActiveSec=6h' \
  'RandomizedDelaySec=1h' \
  'Persistent=true' \
  '' \
  '[Install]' \
  'WantedBy=timers.target' \
  > "$unit_dir/pocketcoder-release-metadata.timer"
systemctl daemon-reload
systemctl enable --now pocketcoder-release-metadata.timer
