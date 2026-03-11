#!/usr/bin/env bats
# Feature: SOP Sealing Hook
#
# Happy-path integration tests for the proposals -> SOP sealing pipeline.
# When a proposal's status is updated to "approved", the Go hook should
# create a sealed SOP record with a SHA256 signature of the content.
#
# No LLM required.

load '../../helpers/auth.sh'
load '../../helpers/cleanup.sh'
load '../../helpers/assertions.sh'
load '../../helpers/tracking.sh'

setup() {
    load_env
    TEST_ID=$(generate_test_id)
    export CURRENT_TEST_ID="$TEST_ID"
}

teardown() {
    # Clean up proposals and sops created during this test
    local token
    token=$(get_admin_token 2>/dev/null) || true

    if [ -n "$token" ]; then
        # Delete proposals matching this test run
        local response
        response=$(curl -s -G \
            "$PB_URL/api/collections/proposals/records" \
            --data-urlencode "filter=name~'$TEST_ID'" \
            --data-urlencode "perPage=100" \
            -H "Authorization: $token")
        echo "$response" | jq -r '.items[]?.id // empty' 2>/dev/null | while read -r id; do
            [ -n "$id" ] && curl -s -X DELETE \
                "$PB_URL/api/collections/proposals/records/$id" \
                -H "Authorization: $token" > /dev/null 2>&1 || true
        done

        # Delete sops matching this test run
        response=$(curl -s -G \
            "$PB_URL/api/collections/sops/records" \
            --data-urlencode "filter=name~'$TEST_ID'" \
            --data-urlencode "perPage=100" \
            -H "Authorization: $token")
        echo "$response" | jq -r '.items[]?.id // empty' 2>/dev/null | while read -r id; do
            [ -n "$id" ] && curl -s -X DELETE \
                "$PB_URL/api/collections/sops/records/$id" \
                -H "Authorization: $token" > /dev/null 2>&1 || true
        done
    fi
}

# =============================================================================
# Helpers
# =============================================================================

# Create a proposal record; prints JSON response
create_proposal() {
    local name="$1"
    local content="$2"
    local status="${3:-draft}"
    local description="${4:-Test proposal for $TEST_ID}"

    pb_create "proposals" "$(jq -n \
        --arg name "$name" \
        --arg content "$content" \
        --arg status "$status" \
        --arg desc "$description" \
        --arg author "human" \
        '{name: $name, content: $content, status: $status, description: $desc, authored_by: $author}')"
}

# =============================================================================
# Tests
# =============================================================================

@test "SOP: create a draft proposal" {
    authenticate_user

    local name="sop_${TEST_ID}"
    local content="All deployments must pass CI before merge."

    run create_proposal "$name" "$content" "draft"
    [ "$status" -eq 0 ]

    local proposal_id
    proposal_id=$(echo "$output" | jq -r '.id // empty')
    assert_not_empty "$proposal_id" "Proposal should have been created"

    local proposal_status
    proposal_status=$(echo "$output" | jq -r '.status // empty')
    assert_equal "draft" "$proposal_status" "Proposal status should be draft"
}

@test "SOP: approving a proposal creates a sealed SOP with signature" {
    authenticate_user

    local name="sop_${TEST_ID}"
    local content="All deployments must pass CI before merge."

    # Create draft proposal
    local create_res
    create_res=$(create_proposal "$name" "$content" "draft")
    local proposal_id
    proposal_id=$(echo "$create_res" | jq -r '.id')
    assert_not_empty "$proposal_id" "Proposal should have been created"

    # Approve the proposal -- this should trigger the sealing hook
    local update_res
    update_res=$(pb_update "proposals" "$proposal_id" '{"status": "approved"}')
    local updated_status
    updated_status=$(echo "$update_res" | jq -r '.status // empty')
    assert_equal "approved" "$updated_status" "Proposal should now be approved"

    # Give the hook a moment to complete (it runs after update success)
    sleep 1

    # Fetch the sealed SOP by name
    local sops_res
    sops_res=$(pb_list "sops" "?filter=name%3D%27${name}%27")
    local sop_count
    sop_count=$(echo "$sops_res" | jq -r '.totalItems // 0')
    assert_equal "1" "$sop_count" "Exactly one SOP should have been created"

    # Verify the SOP fields
    local sop
    sop=$(echo "$sops_res" | jq '.items[0]')

    # Content should match the proposal
    local sop_content
    sop_content=$(echo "$sop" | jq -r '.content')
    assert_equal "$content" "$sop_content" "SOP content should match proposal content"

    # Signature should be a 64-char hex string (SHA256)
    local signature
    signature=$(echo "$sop" | jq -r '.signature')
    assert_not_empty "$signature" "SOP should have a signature"
    local sig_len=${#signature}
    assert_equal "64" "$sig_len" "Signature should be 64 hex characters (SHA256)"

    # approved_at should be set
    local approved_at
    approved_at=$(echo "$sop" | jq -r '.approved_at // empty')
    assert_not_empty "$approved_at" "SOP should have approved_at timestamp"
}

@test "SOP: signature matches SHA256 of content" {
    authenticate_user

    local name="sop_${TEST_ID}_sig"
    local content="Code reviews require at least one approval."

    # Create and approve in one flow
    local create_res
    create_res=$(create_proposal "$name" "$content" "draft")
    local proposal_id
    proposal_id=$(echo "$create_res" | jq -r '.id')
    pb_update "proposals" "$proposal_id" '{"status": "approved"}' > /dev/null

    sleep 1

    # Fetch the SOP
    local sops_res
    sops_res=$(pb_list "sops" "?filter=name%3D%27${name}%27")
    local signature
    signature=$(echo "$sops_res" | jq -r '.items[0].signature')

    # Compute expected SHA256 locally
    local expected_sig
    expected_sig=$(printf '%s' "$content" | sha256sum | awk '{print $1}')

    assert_equal "$expected_sig" "$signature" "SOP signature should match SHA256 of content"
}

@test "SOP: version field exists on sealed SOP record" {
    authenticate_user

    local name="sop_${TEST_ID}_ver"
    local content="Secrets must never be committed to version control."

    local create_res
    create_res=$(create_proposal "$name" "$content" "draft")
    local proposal_id
    proposal_id=$(echo "$create_res" | jq -r '.id')
    pb_update "proposals" "$proposal_id" '{"status": "approved"}' > /dev/null

    sleep 1

    local sops_res
    sops_res=$(pb_list "sops" "?filter=name%3D%27${name}%27")
    local sop
    sop=$(echo "$sops_res" | jq '.items[0]')

    # The version field should be present in the response (even if default/zero)
    local has_version
    has_version=$(echo "$sop" | jq 'has("version")')
    assert_equal "true" "$has_version" "SOP record should have a version field"
}
