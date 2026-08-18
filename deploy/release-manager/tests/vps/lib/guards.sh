#!/usr/bin/env bash
# Preflight checks. Sourced, never executed directly.

guard_required_commands() {
  local missing= command_name
  for command_name in "$@"; do
    command -v "$command_name" >/dev/null 2>&1 || missing="$missing $command_name"
  done
  if [ -n "$missing" ]; then
    echo "required commands unavailable:$missing" >&2
    return 1
  fi
  return 0
}

# Checklist docs are edited locally during test runs; everything else must be
# clean so the provisioned release matches a pushed commit.
guard_clean_checkout() {
  local repo_root=$1 dirty
  dirty=$(git -C "$repo_root" status --porcelain | awk '{print $2}' |
    sed '/^$/d;/^docs\/testing\/mvp-code-gap-todo\.md$/d;/^docs\/testing\/mvp-ultimate-checklist\.md$/d')

  if [ -n "$dirty" ]; then
    echo "checkout is dirty (checklist docs may be edited locally):" >&2
    printf '%s\n' "$dirty" >&2
    return 1
  fi
  return 0
}

guard_release_branch() {
  local repo_root=$1 branch head remote
  branch=$(git -C "$repo_root" symbolic-ref --short HEAD 2>/dev/null || true)
  case $branch in
    main | staging) ;;
    *) echo "VPS tests require a checked-out main or staging branch (found: ${branch:-detached})" >&2
       return 1 ;;
  esac
  head=$(git -C "$repo_root" rev-parse HEAD)
  remote=$(git -C "$repo_root" ls-remote origin "refs/heads/$branch" | awk '{print $1}')

  if [ "$head" != "$remote" ]; then
    echo "HEAD $head is not origin/$branch $remote; push the exact tested commit first" >&2
    return 1
  fi
  printf '%s' "$branch"
}

resolve_flutter_bin() {
  if [ -n "${FLUTTER_BIN:-}" ] && [ -x "${FLUTTER_BIN:-}" ]; then
    printf '%s' "$FLUTTER_BIN"
    return 0
  fi
  local found
  found=$(command -v flutter 2>/dev/null || true)
  if [ -n "$found" ]; then
    printf '%s' "$found"
    return 0
  fi
  echo "flutter not found; set FLUTTER_BIN to the flutter executable" >&2
  return 1
}

resolve_provisioner() {
  local candidate=${VPS_PROVISIONER:-}
  if [ -z "$candidate" ]; then
    echo "no provisioner configured; set VPS_PROVISIONER to an executable that prints handoff JSON on stdout" >&2
    return 1
  fi
  if [ ! -x "$candidate" ]; then
    echo "VPS_PROVISIONER=$candidate is not an executable file" >&2
    return 1
  fi
  printf '%s' "$candidate"
}
