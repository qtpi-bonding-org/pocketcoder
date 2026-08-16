phase_name=update
phase_tier=disruptive

phase_precondition() {
  if [ -z "${VPS_RELEASE_B_DIGEST:-}" ]; then
    echo "no candidate release B was promoted"
    return 1
  fi
  return 0
}

phase_run() {
  local current digest source_commit channel sequence

  dispatch_ssh_command updatePocketCoder \
    "export POCKETCODER_GITHUB_WORKFLOW_BRANCH=${VPS_RELEASE_BRANCH:-main}; " >/dev/null || {
    echo "updatePocketCoder failed" >&2
    return 1
  }

  current=$(ssh_exec 30 'cat /var/lib/pocketcoder/release/current.json')
  digest=$(jq -r '.releaseDigest' <<<"$current")
  source_commit=$(jq -r '.sourceCommit' <<<"$current")
  channel=$(jq -r '.channel' <<<"$current")
  sequence=$(jq -r '.channelSequence' <<<"$current")

  [ "$digest" = "$VPS_RELEASE_B_DIGEST" ] || {
    echo "active digest $digest is not the expected $VPS_RELEASE_B_DIGEST" >&2
    return 1
  }
  [ "$source_commit" = "$VPS_RELEASE_B_SOURCE_COMMIT" ] || {
    echo "active source commit $source_commit is not the expected $VPS_RELEASE_B_SOURCE_COMMIT" >&2
    return 1
  }
  [ "$sequence" = "$VPS_RELEASE_B_SEQUENCE" ] || {
    echo "active sequence $sequence is not the expected $VPS_RELEASE_B_SEQUENCE" >&2
    return 1
  }
  [ "$(ssh_exec 30 'readlink /opt/pocketcoder/current')" = "/opt/pocketcoder/releases/$digest" ] || {
    echo "current symlink does not point at release B" >&2
    return 1
  }

  VPS_PHASE_EVIDENCE=$(jq -n --arg digest "$digest" --arg commit "$source_commit" \
    --arg channel "$channel" --arg sequence "$sequence" \
    '{releaseDigest:$digest,sourceCommit:$commit,channel:$channel,channelSequence:$sequence}')
  return 0
}
