# Not a tiered phase: like 10-provision.sh, the orchestrator calls
# vps_promote_candidate directly, in the top-level process, so
# VPS_RELEASE_B_* land where 60-update.sh/70-post-update.sh's
# phase_precondition (itself run via command substitution) can read them.
# This ports the promotion flow from the deleted
# run-vps-script-nixos-upgrade-test.sh: build a fresh, GitHub-attested
# candidate for the checked-out commit, promote it to the nightly channel,
# and wait for the public pointer to actually serve it.

vps_promote_candidate() {
  local repo_root=$1 baseline_digest=$2 branch=$3
  local api auth run state attempt source_commit promotion
  local digest sequence pointer pointer_digest pointer_sequence channel_path

  : "${GH_TOKEN:?GH_TOKEN must be injected by the secrets-daemon}"
  api='https://api.github.com/repos/qtpi-bonding-org/pocketcoder/actions'
  auth=(-H "Authorization: Bearer $GH_TOKEN" -H 'Accept: application/vnd.github+json')
  source_commit=$(git -C "$repo_root" rev-parse HEAD)

  echo "VPS SUITE: triggering CI build for $source_commit" >&2
  # --attest-branch bakes POCKETCODER_GITHUB_WORKFLOW_BRANCH=$branch into
  # the image (see resolver.go's ChannelPath). Without it the image always
  # defaults to trusting "main" regardless of which branch built it --
  # confirmed live: an un-attested candidate built from staging still
  # polled the real, unqualified nightly.json instead of
  # nightly-testing.json once it actually ran pocketcoder-release install,
  # producing "resolved release does not match the expected digest" even
  # though the candidate was correctly promoted to nightly-testing.json.
  # Safe on main too -- attesting "main" is exactly the existing default.
  "$repo_root/deploy/nixos/scripts/trigger-ci-build.sh" --attest-branch >&2 || return 1

  echo "VPS SUITE: waiting for the candidate build" >&2
  run=
  for attempt in $(seq 1 "${VPS_PROMOTE_BUILD_ATTEMPTS:-120}"); do
    run=$(curl -fsSL "${auth[@]}" \
      "$api/workflows/nixos-image.yml/runs?branch=$branch&event=workflow_dispatch&per_page=20" |
      jq -r --arg commit "$source_commit" \
        '.workflow_runs[] | select(.head_sha == $commit) | .id' | head -1)
    if [ -n "$run" ]; then
      state=$(curl -fsSL "${auth[@]}" "$api/runs/$run" | jq -r '[.status,(.conclusion // "")] | @tsv')
      case "$state" in
        $'completed\tsuccess') break ;;
        completed*) echo "candidate build failed: run $run ($state)" >&2; return 1 ;;
      esac
    fi
    run=
    sleep "${VPS_PROMOTE_POLL_INTERVAL:-15}"
  done
  [ -n "$run" ] || { echo "timed out waiting for candidate build for $source_commit" >&2; return 1; }

  echo "VPS SUITE: promoting candidate to nightly" >&2
  promotion=$(cd "$repo_root" && "$repo_root/deploy/nixos/scripts/promote-latest-candidate.sh" nightly) || return 1
  digest=$(printf '%s\n' "$promotion" | sed -n 's/.*manifest=\([0-9a-f]\{64\}\).*/\1/p')
  [ -n "$digest" ] || { echo "promotion did not report a manifest digest" >&2; return 1; }
  [ "$digest" != "$baseline_digest" ] || {
    echo "candidate is identical to the provisioned baseline" >&2
    return 1
  }

  # Mirrors resolver.go's ChannelPath: promote-latest-candidate.sh dispatches
  # release-promotion.yml with ref=$branch, which publishes to the bare
  # "nightly.json" only for main -- every other branch (today, only staging)
  # gets its own "nightly-testing.json" so a staging run can never overwrite
  # the shared pointer a main-trust box actually polls. Polling the wrong
  # path here doesn't touch production, but it does make this phase time out
  # and update/post-update/rollback silently skip instead of exercising them.
  channel_path=nightly
  [ "$branch" = main ] || channel_path=nightly-testing

  echo "VPS SUITE: waiting for the $channel_path pointer to serve $digest" >&2
  sequence=
  for attempt in $(seq 1 "${VPS_PROMOTE_POINTER_ATTEMPTS:-40}"); do
    pointer=$(curl -fsSL "https://images.relay.pocketcoder.org/v1/channels/$channel_path.json" || true)
    pointer_digest=$(printf '%s' "$pointer" | jq -r '.manifest.sha256 // empty' 2>/dev/null || true)
    pointer_sequence=$(printf '%s' "$pointer" | jq -r '.sequence // empty' 2>/dev/null || true)
    if [ "$pointer_digest" = "$digest" ] && [ -n "$pointer_sequence" ]; then
      sequence=$pointer_sequence
      break
    fi
    sleep "${VPS_PROMOTE_POLL_INTERVAL:-15}"
  done
  [ -n "$sequence" ] || { echo "timed out waiting for the $channel_path pointer to serve $digest" >&2; return 1; }

  jq -n --arg digest "$digest" --arg commit "$source_commit" --arg sequence "$sequence" \
    '{digest:$digest,sourceCommit:$commit,sequence:$sequence}'
}
