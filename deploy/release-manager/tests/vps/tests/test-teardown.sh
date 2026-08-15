. "$VPS_DIR/lib/common.sh"
. "$VPS_DIR/lib/result.sh"
. "$VPS_DIR/lib/teardown.sh"

VPS_REDACTION_READY=1
VPS_REDACTION_VALUES=
# The curl stub embeds this value while the test file is being sourced.  Keep
# it defined because self-test runs with nounset; the fallback case overrides
# it for the actual command invocation below.
RUN_LABEL=

curl_dir="$TEST_TMP/curlbin"
stub_bin "$curl_dir" curl '
for arg in "$@"; do last=$arg; done
case ${CURL_STUB_MODE:-ok} in
  ok)
    case $last in
      *"/linode/instances/"*) exit 0 ;;
      *"/linode/instances"*) echo "{\"data\":[{\"id\":777,\"label\":\"'"$RUN_LABEL"'\"}]}" ;;
    esac ;;
  deletefail)
    case $last in
      *"/linode/instances/"*) exit 22 ;;
      *"/linode/instances"*) echo "{\"data\":[]}" ;;
    esac ;;
esac'

export LINODE_TOKEN=stub-token

# Keep mode does nothing.
result_init "$TEST_TMP/t1"
teardown_set_label run-abc
teardown_set_instance 555
PATH="$curl_dir:$PATH" teardown_run 1
check_rc "teardown: --keep succeeds without deleting" 0 "$?"
result_write passed ''
check "teardown: --keep records not attempted" "false" \
  "$(jq -r '.teardown.attempted' "$TEST_TMP/t1/result.json")"

# Delete by instance id.
result_init "$TEST_TMP/t2"
teardown_set_label run-abc
teardown_set_instance 555
PATH="$curl_dir:$PATH" teardown_run 0
check_rc "teardown: deletes by instance id" 0 "$?"
result_write passed ''
check "teardown: records the deletion" "true" \
  "$(jq -r '.teardown.instanceDeleted' "$TEST_TMP/t2/result.json")"

# Fallback: no instance id captured, sweep by run-unique label.
result_init "$TEST_TMP/t3"
teardown_set_label run-xyz
RUN_LABEL=run-xyz PATH="$curl_dir:$PATH" teardown_run 0
check_rc "teardown: falls back to the run-scoped label sweep" 0 "$?"
result_write passed ''
check "teardown: label sweep records deletion" "true" \
  "$(jq -r '.teardown.instanceDeleted' "$TEST_TMP/t3/result.json")"

# Deletion failure is recorded, not swallowed.
result_init "$TEST_TMP/t4"
teardown_set_label run-abc
teardown_set_instance 555
CURL_STUB_MODE=deletefail PATH="$curl_dir:$PATH" teardown_run 0
check_rc "teardown: deletion failure returns non-zero" 1 "$?"
result_write passed ''
check "teardown: failure is recorded" "false" \
  "$(jq -r '.teardown.succeeded' "$TEST_TMP/t4/result.json")"
