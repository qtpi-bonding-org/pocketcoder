#!/usr/bin/env bash
# Instance teardown. Deletes only what this run created.

VPS_RUN_LABEL=
VPS_INSTANCE_ID=

teardown_set_label() { VPS_RUN_LABEL=$1; }
teardown_set_instance() { VPS_INSTANCE_ID=$1; }

linode_delete_instance() {
  curl --fail --silent --show-error --max-time 60 -X DELETE \
    -H "Authorization: Bearer $LINODE_TOKEN" \
    "https://api.linode.com/v4/linode/instances/$1" >/dev/null
}

linode_find_by_label() {
  local label=$1
  curl --fail --silent --show-error --max-time 60 \
    -H "Authorization: Bearer $LINODE_TOKEN" \
    https://api.linode.com/v4/linode/instances |
    jq -r --arg label "$label" '.data[] | select(.label == $label) | .id'
}

# teardown_run <keep>
teardown_run() {
  local keep=$1 deleted=false detail= ok=true id

  if [ "$keep" = 1 ]; then
    teardown_record false false false "preserved by --keep"
    echo "VPS SUITE: preserving instance ${VPS_INSTANCE_ID:-unknown} (--keep)"
    return 0
  fi

  if [ -n "$VPS_INSTANCE_ID" ]; then
    if linode_delete_instance "$VPS_INSTANCE_ID"; then
      deleted=true
      detail="deleted instance $VPS_INSTANCE_ID"
    else
      ok=false
      detail="failed to delete instance $VPS_INSTANCE_ID"
    fi
  elif [ -n "$VPS_RUN_LABEL" ]; then
    # Provisioning may have died before writing the handoff. Sweep only this
    # run's unique label, never the shared prefix.
    detail="no instance id; sweeping label $VPS_RUN_LABEL"
    for id in $(linode_find_by_label "$VPS_RUN_LABEL"); do
      if linode_delete_instance "$id"; then
        deleted=true
        detail="$detail; deleted $id"
      else
        ok=false
        detail="$detail; failed to delete $id"
      fi
    done
  else
    ok=false
    detail="no instance id and no run label; cannot tear down safely"
  fi

  teardown_record true "$ok" "$deleted" "$detail"
  [ "$ok" = true ]
}
