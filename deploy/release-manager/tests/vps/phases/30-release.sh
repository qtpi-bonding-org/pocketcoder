phase_name=release
phase_tier=readonly

phase_run() {
  local status current
  status=$(ssh_exec 60 '/opt/pocketcoder/current/bin/pocketcoder-release status')
  jq -e '.schemaVersion == 1 and (.managerVersion | strings | length > 0) and
    (.current.releaseDigest | strings | test("^[0-9a-f]{64}$"))' <<<"$status" >/dev/null || {
    echo "release status payload is invalid" >&2
    return 1
  }
  current=$(ssh_exec 30 'cat /var/lib/pocketcoder/release/current.json')
  local digest
  digest=$(jq -r '.releaseDigest' <<<"$current")

  [ "$digest" = "$VPS_RELEASE_A_DIGEST" ] || {
    echo "current release $digest does not match the provisioned $VPS_RELEASE_A_DIGEST" >&2
    return 1
  }
  [ "$(ssh_exec 30 'readlink /opt/pocketcoder/current')" = "/opt/pocketcoder/releases/$digest" ] || {
    echo "current symlink does not point at the active release" >&2
    return 1
  }
  VPS_PHASE_EVIDENCE=$(jq -n --arg digest "$digest" '{releaseDigest:$digest}')
  return 0
}
