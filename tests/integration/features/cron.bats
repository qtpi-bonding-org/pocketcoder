#!/usr/bin/env bats
# Feature: Cron / Scheduled Agent Tasks
#
# Integration tests for cron job management and scheduled execution.
#
# Tests:
# 1. cron_jobs collection exists with correct fields
# 2. CRUD operations with owner access control
# 3. Cron job with session_mode=existing creates message in linked chat
# 4. Cron job with session_mode=new creates new chat + message
# 5. Disabling a cron job removes it from scheduler
# 6. Updating cron expression re-registers the job
# 7. Unauthenticated requests are rejected
# 8. last_executed and last_status are updated after execution

load '../../helpers/auth.sh'
load '../../helpers/cleanup.sh'
load '../../helpers/wait.sh'
load '../../helpers/assertions.sh'
load '../../helpers/diagnostics.sh'
load '../../helpers/tracking.sh'

setup() {
    load_env
    TEST_ID=$(generate_test_id)
    export CURRENT_TEST_ID="$TEST_ID"
    USER_TOKEN=""
    USER_ID=""
}

teardown() {
    # Clean up cron_jobs records
    if [ -n "$USER_TOKEN" ]; then
        cleanup_cron_jobs || true
        cleanup_test_chats || true
    fi
}

# =============================================================================
# Helpers
# =============================================================================

# Clean up cron_jobs records for this test run
cleanup_cron_jobs() {
    local response
    response=$(curl -s -X GET \
        "$PB_URL/api/collections/cron_jobs/records?filter=name~\"$TEST_ID\"" \
        -H "Authorization: $USER_TOKEN")

    echo "$response" | jq -r '.items[]?.id // empty' 2>/dev/null | while read -r id; do
        [ -n "$id" ] && curl -s -X DELETE \
            "$PB_URL/api/collections/cron_jobs/records/$id" \
            -H "Authorization: $USER_TOKEN" > /dev/null 2>&1 || true
    done
}

# Clean up chats created by cron tests
cleanup_test_chats() {
    local response
    response=$(curl -s -G \
        "$PB_URL/api/collections/chats/records" \
        --data-urlencode "filter=title~'$TEST_ID'" \
        -H "Authorization: $USER_TOKEN")

    echo "$response" | jq -r '.items[]?.id // empty' 2>/dev/null | while read -r id; do
        [ -n "$id" ] && curl -s -X DELETE \
            "$PB_URL/api/collections/chats/records/$id" \
            -H "Authorization: $USER_TOKEN" > /dev/null 2>&1 || true
    done
}

# Create a cron job record; prints JSON response
create_cron_job() {
    local name="$1"
    local cron_expression="$2"
    local prompt="$3"
    local session_mode="$4"
    local extra_fields="${5:-}"

    local data="{
        \"name\": \"$name\",
        \"cron_expression\": \"$cron_expression\",
        \"prompt\": \"$prompt\",
        \"session_mode\": \"$session_mode\",
        \"user\": \"$USER_ID\",
        \"enabled\": true
        ${extra_fields:+,$extra_fields}
    }"

    curl -s -X POST "$PB_URL/api/collections/cron_jobs/records" \
        -H "Content-Type: application/json" \
        -H "Authorization: $USER_TOKEN" \
        -d "$data"
}

# Create a test chat; prints chat ID
create_test_chat() {
    local title="$1"
    local response
    response=$(curl -s -X POST "$PB_URL/api/collections/chats/records" \
        -H "Content-Type: application/json" \
        -H "Authorization: $USER_TOKEN" \
        -d "{\"title\": \"$title\", \"user\": \"$USER_ID\", \"turn\": \"user\"}")
    echo "$response" | jq -r '.id // empty'
}

# =============================================================================
# 1. Collection Exists
# =============================================================================

@test "Cron Collection: cron_jobs exists with correct fields" {
    authenticate_superuser

    local response
    response=$(curl -s "$PB_URL/api/collections/cron_jobs" \
        -H "Authorization: $USER_TOKEN")

    local name
    name=$(echo "$response" | jq -r '.name // empty')
    [ "$name" = "cron_jobs" ] || {
        echo "❌ cron_jobs collection not found. Response: $response" >&2
        return 1
    }

    local fields
    fields=$(echo "$response" | jq -r '[.fields[].name] | join(",")')
    echo "$fields" | grep -q "name" || { echo "❌ Missing field: name" >&2; return 1; }
    echo "$fields" | grep -q "cron_expression" || { echo "❌ Missing field: cron_expression" >&2; return 1; }
    echo "$fields" | grep -q "prompt" || { echo "❌ Missing field: prompt" >&2; return 1; }
    echo "$fields" | grep -q "session_mode" || { echo "❌ Missing field: session_mode" >&2; return 1; }
    echo "$fields" | grep -q "chat" || { echo "❌ Missing field: chat" >&2; return 1; }
    echo "$fields" | grep -q "agent" || { echo "❌ Missing field: agent" >&2; return 1; }
    echo "$fields" | grep -q "user" || { echo "❌ Missing field: user" >&2; return 1; }
    echo "$fields" | grep -q "enabled" || { echo "❌ Missing field: enabled" >&2; return 1; }
    echo "$fields" | grep -q "last_executed" || { echo "❌ Missing field: last_executed" >&2; return 1; }
    echo "$fields" | grep -q "last_status" || { echo "❌ Missing field: last_status" >&2; return 1; }
    echo "$fields" | grep -q "last_error" || { echo "❌ Missing field: last_error" >&2; return 1; }

    echo "✓ cron_jobs collection exists with fields: $fields"
}

# =============================================================================
# 2. CRUD + Access Control
# =============================================================================

@test "Cron CRUD: Owner can create and read a cron job" {
    authenticate_user

    local response
    response=$(create_cron_job "test-job-$TEST_ID" "0 * * * *" "Run tests" "new")

    local record_id
    record_id=$(echo "$response" | jq -r '.id // empty')
    [ -n "$record_id" ] && [ "$record_id" != "null" ] || {
        echo "❌ Failed to create cron job. Response: $response" >&2
        return 1
    }

    # Read it back
    local get_response
    get_response=$(curl -s "$PB_URL/api/collections/cron_jobs/records/$record_id" \
        -H "Authorization: $USER_TOKEN")

    local job_name
    job_name=$(echo "$get_response" | jq -r '.name // empty')
    [ "$job_name" = "test-job-$TEST_ID" ] || {
        echo "❌ Name mismatch. Expected: test-job-$TEST_ID, Got: $job_name" >&2
        return 1
    }

    local cron_expr
    cron_expr=$(echo "$get_response" | jq -r '.cron_expression // empty')
    [ "$cron_expr" = "0 * * * *" ] || {
        echo "❌ cron_expression mismatch. Expected: 0 * * * *, Got: $cron_expr" >&2
        return 1
    }

    echo "✓ Owner can create and read cron job (id: $record_id)"
}

@test "Cron CRUD: Owner can update a cron job" {
    authenticate_user

    local response
    response=$(create_cron_job "update-$TEST_ID" "0 * * * *" "Original prompt" "new")
    local record_id
    record_id=$(echo "$response" | jq -r '.id // empty')
    [ -n "$record_id" ] || { echo "❌ Create failed" >&2; return 1; }

    # Update cron expression
    local update_response
    update_response=$(curl -s -X PATCH \
        "$PB_URL/api/collections/cron_jobs/records/$record_id" \
        -H "Content-Type: application/json" \
        -H "Authorization: $USER_TOKEN" \
        -d '{"cron_expression": "*/30 * * * *", "prompt": "Updated prompt"}')

    local updated_expr
    updated_expr=$(echo "$update_response" | jq -r '.cron_expression // empty')
    [ "$updated_expr" = "*/30 * * * *" ] || {
        echo "❌ Update failed. Expected: */30 * * * *, Got: $updated_expr" >&2
        return 1
    }

    echo "✓ Owner can update cron job"
}

@test "Cron CRUD: Owner can delete a cron job" {
    authenticate_user

    local response
    response=$(create_cron_job "delete-$TEST_ID" "0 * * * *" "To be deleted" "new")
    local record_id
    record_id=$(echo "$response" | jq -r '.id // empty')
    [ -n "$record_id" ] || { echo "❌ Create failed" >&2; return 1; }

    local del_code
    del_code=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
        "$PB_URL/api/collections/cron_jobs/records/$record_id" \
        -H "Authorization: $USER_TOKEN")
    [ "$del_code" = "204" ] || {
        echo "❌ Delete returned HTTP $del_code, expected 204" >&2
        return 1
    }

    # Verify gone
    local get_code
    get_code=$(curl -s -o /dev/null -w "%{http_code}" \
        "$PB_URL/api/collections/cron_jobs/records/$record_id" \
        -H "Authorization: $USER_TOKEN")
    [ "$get_code" = "404" ] || {
        echo "❌ Record still exists after delete (HTTP $get_code)" >&2
        return 1
    }

    echo "✓ Owner can delete cron job"
}

@test "Cron CRUD: Unauthenticated request is rejected" {
    local response
    response=$(curl -s -w "\n%{http_code}" -X POST \
        "$PB_URL/api/collections/cron_jobs/records" \
        -H "Content-Type: application/json" \
        -d '{"name": "test", "cron_expression": "* * * * *", "prompt": "test", "session_mode": "new", "user": "fake", "enabled": true}')

    local http_code
    http_code=$(echo "$response" | tail -n 1)
    [ "$http_code" = "400" ] || [ "$http_code" = "401" ] || [ "$http_code" = "403" ] || {
        echo "❌ Unauthenticated create should fail, got HTTP $http_code" >&2
        return 1
    }

    echo "✓ Unauthenticated cron job create rejected (HTTP $http_code)"
}

# =============================================================================
# 3. Cron Hook — Scheduler Registration
# =============================================================================

@test "Cron Hook: Creating enabled job registers it with scheduler" {
    authenticate_user

    local response
    response=$(create_cron_job "sched-$TEST_ID" "0 2 * * *" "Nightly check" "new")
    local record_id
    record_id=$(echo "$response" | jq -r '.id // empty')
    [ -n "$record_id" ] || { echo "❌ Create failed: $response" >&2; return 1; }

    # Wait for hook to process
    sleep 2

    # Check PocketBase logs for registration
    local pb_logs
    pb_logs=$(docker logs pocketcoder-pocketbase 2>&1 | tail -30)

    echo "$pb_logs" | grep -q "Registered job 'sched-$TEST_ID'" || {
        echo "❌ PocketBase did not log cron job registration" >&2
        echo "  Expected log containing: Registered job 'sched-$TEST_ID'" >&2
        echo "  Recent PB logs:" >&2
        echo "$pb_logs" >&2
        return 1
    }

    echo "✓ Creating enabled cron job registers it with scheduler"
}

@test "Cron Hook: Disabling a job removes it from scheduler" {
    authenticate_user

    # Create enabled job
    local response
    response=$(create_cron_job "disable-$TEST_ID" "0 3 * * *" "To be disabled" "new")
    local record_id
    record_id=$(echo "$response" | jq -r '.id // empty')
    [ -n "$record_id" ] || { echo "❌ Create failed" >&2; return 1; }

    sleep 2

    # Disable the job
    curl -s -X PATCH \
        "$PB_URL/api/collections/cron_jobs/records/$record_id" \
        -H "Content-Type: application/json" \
        -H "Authorization: $USER_TOKEN" \
        -d '{"enabled": false}' > /dev/null

    sleep 2

    # Check PocketBase logs for removal
    local pb_logs
    pb_logs=$(docker logs pocketcoder-pocketbase 2>&1 | tail -30)

    echo "$pb_logs" | grep -q "disabled, removed from scheduler" || {
        echo "❌ PocketBase did not log job removal" >&2
        echo "  Expected log containing: disabled, removed from scheduler" >&2
        echo "  Recent PB logs:" >&2
        echo "$pb_logs" >&2
        return 1
    }

    echo "✓ Disabling a cron job removes it from scheduler"
}

@test "Cron Hook: Updating cron expression re-registers the job" {
    authenticate_user

    local response
    response=$(create_cron_job "reregister-$TEST_ID" "0 4 * * *" "Re-register test" "new")
    local record_id
    record_id=$(echo "$response" | jq -r '.id // empty')
    [ -n "$record_id" ] || { echo "❌ Create failed" >&2; return 1; }

    sleep 2

    # Update the expression
    curl -s -X PATCH \
        "$PB_URL/api/collections/cron_jobs/records/$record_id" \
        -H "Content-Type: application/json" \
        -H "Authorization: $USER_TOKEN" \
        -d '{"cron_expression": "*/15 * * * *"}' > /dev/null

    sleep 2

    # Check PocketBase logs for re-registration with new schedule
    local pb_logs
    pb_logs=$(docker logs pocketcoder-pocketbase 2>&1 | tail -30)

    echo "$pb_logs" | grep -q "Registered job 'reregister-$TEST_ID' with schedule '\\*/15" || {
        echo "❌ PocketBase did not log re-registration with updated schedule" >&2
        echo "  Expected log containing: Registered job 'reregister-$TEST_ID' with schedule '*/15 * * * *'" >&2
        echo "  Recent PB logs:" >&2
        echo "$pb_logs" >&2
        return 1
    }

    echo "✓ Updating cron expression re-registers the job"
}

@test "Cron Hook: Deleting a job removes it from scheduler" {
    authenticate_user

    local response
    response=$(create_cron_job "delcron-$TEST_ID" "0 5 * * *" "Delete test" "new")
    local record_id
    record_id=$(echo "$response" | jq -r '.id // empty')
    [ -n "$record_id" ] || { echo "❌ Create failed" >&2; return 1; }

    sleep 2

    # Delete the job
    curl -s -X DELETE \
        "$PB_URL/api/collections/cron_jobs/records/$record_id" \
        -H "Authorization: $USER_TOKEN" > /dev/null

    sleep 2

    # Check PocketBase logs for removal
    local pb_logs
    pb_logs=$(docker logs pocketcoder-pocketbase 2>&1 | tail -30)

    echo "$pb_logs" | grep -q "Removed job 'delcron-$TEST_ID'" || {
        echo "❌ PocketBase did not log job removal on delete" >&2
        echo "  Recent PB logs:" >&2
        echo "$pb_logs" >&2
        return 1
    }

    echo "✓ Deleting a cron job removes it from scheduler"
}

# =============================================================================
# 4. Execution — session_mode=existing
# =============================================================================

@test "Cron Execution: session_mode=existing creates message in linked chat" {
    authenticate_user

    # Create a test chat
    local chat_id
    chat_id=$(create_test_chat "cron-existing-$TEST_ID")
    [ -n "$chat_id" ] || { echo "❌ Failed to create test chat" >&2; return 1; }

    # Create a cron job with every-minute schedule linked to that chat
    local response
    response=$(create_cron_job "existing-$TEST_ID" "* * * * *" "Cron says hello" "existing" \
        "\"chat\": \"$chat_id\"")
    local record_id
    record_id=$(echo "$response" | jq -r '.id // empty')
    [ -n "$record_id" ] || { echo "❌ Create failed: $response" >&2; return 1; }

    # Wait for cron to fire (up to 90 seconds for the minute boundary)
    echo "  Waiting for cron job to fire (up to 90s)..."
    local attempts=0
    local max_attempts=30
    local found=false

    while [ $attempts -lt $max_attempts ]; do
        sleep 3
        local messages
        messages=$(curl -s -G \
            "$PB_URL/api/collections/messages/records" \
            --data-urlencode "filter=chat='$chat_id'" \
            -H "Authorization: $USER_TOKEN")

        local msg_count
        msg_count=$(echo "$messages" | jq -r '.totalItems // 0')
        if [ "$msg_count" -gt 0 ]; then
            # Verify the message content
            local msg_text
            msg_text=$(echo "$messages" | jq -r '.items[0].parts' 2>/dev/null)
            if echo "$msg_text" | grep -q "Cron says hello"; then
                found=true
                break
            fi
        fi
        attempts=$((attempts + 1))
    done

    [ "$found" = true ] || {
        echo "❌ Cron job did not create message in existing chat within timeout" >&2
        # Check job status for debugging
        local job_status
        job_status=$(curl -s "$PB_URL/api/collections/cron_jobs/records/$record_id" \
            -H "Authorization: $USER_TOKEN")
        echo "  Job status: $(echo "$job_status" | jq -r '.last_status // "not executed"')" >&2
        echo "  Job error: $(echo "$job_status" | jq -r '.last_error // "none"')" >&2
        return 1
    }

    # Verify last_status was updated
    local job_final
    job_final=$(curl -s "$PB_URL/api/collections/cron_jobs/records/$record_id" \
        -H "Authorization: $USER_TOKEN")
    local last_status
    last_status=$(echo "$job_final" | jq -r '.last_status // empty')
    [ "$last_status" = "ok" ] || {
        echo "❌ last_status should be 'ok', got: $last_status" >&2
        return 1
    }

    echo "✓ Cron job with session_mode=existing created message in linked chat"
}

# =============================================================================
# 5. Execution — session_mode=new
# =============================================================================

@test "Cron Execution: session_mode=new creates new chat with message" {
    authenticate_user

    # Create a cron job that creates a new chat every run
    local response
    response=$(create_cron_job "newchat-$TEST_ID" "* * * * *" "New chat cron test" "new")
    local record_id
    record_id=$(echo "$response" | jq -r '.id // empty')
    [ -n "$record_id" ] || { echo "❌ Create failed: $response" >&2; return 1; }

    # Wait for cron to fire
    echo "  Waiting for cron job to fire (up to 90s)..."
    local attempts=0
    local max_attempts=30
    local found=false

    while [ $attempts -lt $max_attempts ]; do
        sleep 3
        # Search for chats created by this cron job (title contains the job name)
        local chats
        chats=$(curl -s -G \
            "$PB_URL/api/collections/chats/records" \
            --data-urlencode "filter=title~'newchat-$TEST_ID'" \
            -H "Authorization: $USER_TOKEN")

        local chat_count
        chat_count=$(echo "$chats" | jq -r '.totalItems // 0')
        if [ "$chat_count" -gt 0 ]; then
            local chat_id
            chat_id=$(echo "$chats" | jq -r '.items[0].id // empty')

            # Verify message exists in the new chat
            local messages
            messages=$(curl -s -G \
                "$PB_URL/api/collections/messages/records" \
                --data-urlencode "filter=chat='$chat_id'" \
                -H "Authorization: $USER_TOKEN")

            local msg_count
            msg_count=$(echo "$messages" | jq -r '.totalItems // 0')
            if [ "$msg_count" -gt 0 ]; then
                found=true
                break
            fi
        fi
        attempts=$((attempts + 1))
    done

    [ "$found" = true ] || {
        echo "❌ Cron job did not create new chat with message within timeout" >&2
        local job_status
        job_status=$(curl -s "$PB_URL/api/collections/cron_jobs/records/$record_id" \
            -H "Authorization: $USER_TOKEN")
        echo "  Job status: $(echo "$job_status" | jq -r '.last_status // "not executed"')" >&2
        echo "  Job error: $(echo "$job_status" | jq -r '.last_error // "none"')" >&2
        return 1
    }

    echo "✓ Cron job with session_mode=new created new chat with message"
}

# =============================================================================
# 6. Job Status Tracking
# =============================================================================

@test "Cron Status: last_executed is updated after job runs" {
    authenticate_user

    local response
    response=$(create_cron_job "status-$TEST_ID" "* * * * *" "Status check" "new")
    local record_id
    record_id=$(echo "$response" | jq -r '.id // empty')
    [ -n "$record_id" ] || { echo "❌ Create failed" >&2; return 1; }

    # Verify last_executed is initially empty
    local initial_last_exec
    initial_last_exec=$(echo "$response" | jq -r '.last_executed // empty')
    [ -z "$initial_last_exec" ] || [ "$initial_last_exec" = "" ] || {
        echo "❌ last_executed should be empty initially, got: $initial_last_exec" >&2
        return 1
    }

    # Wait for execution
    echo "  Waiting for cron job to execute (up to 90s)..."
    local attempts=0
    local max_attempts=30

    while [ $attempts -lt $max_attempts ]; do
        sleep 3
        local job_record
        job_record=$(curl -s "$PB_URL/api/collections/cron_jobs/records/$record_id" \
            -H "Authorization: $USER_TOKEN")

        local last_exec
        last_exec=$(echo "$job_record" | jq -r '.last_executed // empty')
        if [ -n "$last_exec" ] && [ "$last_exec" != "" ]; then
            local last_status
            last_status=$(echo "$job_record" | jq -r '.last_status // empty')
            [ "$last_status" = "ok" ] || {
                echo "❌ last_status should be 'ok', got: $last_status" >&2
                local last_err
                last_err=$(echo "$job_record" | jq -r '.last_error // empty')
                echo "  last_error: $last_err" >&2
                return 1
            }
            echo "✓ last_executed updated to: $last_exec, last_status: $last_status"
            return 0
        fi
        attempts=$((attempts + 1))
    done

    echo "❌ last_executed was not updated within timeout" >&2
    return 1
}

# =============================================================================
# 7. Error Handling
# =============================================================================

@test "Cron Error: session_mode=existing without chat records error" {
    authenticate_user

    # Create a cron job with session_mode=existing but no chat linked
    local response
    response=$(create_cron_job "noref-$TEST_ID" "* * * * *" "Missing chat ref" "existing")
    local record_id
    record_id=$(echo "$response" | jq -r '.id // empty')
    [ -n "$record_id" ] || { echo "❌ Create failed: $response" >&2; return 1; }

    # Wait for execution
    echo "  Waiting for cron job to execute and fail (up to 90s)..."
    local attempts=0
    local max_attempts=30

    while [ $attempts -lt $max_attempts ]; do
        sleep 3
        local job_record
        job_record=$(curl -s "$PB_URL/api/collections/cron_jobs/records/$record_id" \
            -H "Authorization: $USER_TOKEN")

        local last_status
        last_status=$(echo "$job_record" | jq -r '.last_status // empty')
        if [ "$last_status" = "error" ]; then
            local last_error
            last_error=$(echo "$job_record" | jq -r '.last_error // empty')
            echo "$last_error" | grep -qi "no chat" || echo "$last_error" | grep -qi "existing" || {
                echo "⚠️ Error message doesn't mention missing chat: $last_error" >&2
            }
            echo "✓ Job correctly reported error for missing chat reference (error: $last_error)"
            return 0
        fi
        attempts=$((attempts + 1))
    done

    echo "❌ Job did not report error within timeout" >&2
    return 1
}

# =============================================================================
# 8. Created Job is Disabled by Default Test
# =============================================================================

@test "Cron CRUD: Creating a disabled job does not register it" {
    authenticate_user

    local data="{
        \"name\": \"disabled-$TEST_ID\",
        \"cron_expression\": \"0 * * * *\",
        \"prompt\": \"Should not run\",
        \"session_mode\": \"new\",
        \"user\": \"$USER_ID\",
        \"enabled\": false
    }"

    local response
    response=$(curl -s -X POST "$PB_URL/api/collections/cron_jobs/records" \
        -H "Content-Type: application/json" \
        -H "Authorization: $USER_TOKEN" \
        -d "$data")

    local record_id
    record_id=$(echo "$response" | jq -r '.id // empty')
    [ -n "$record_id" ] || { echo "❌ Create failed: $response" >&2; return 1; }

    sleep 2

    # Check PocketBase logs — should say disabled
    local pb_logs
    pb_logs=$(docker logs pocketcoder-pocketbase 2>&1 | tail -20)

    echo "$pb_logs" | grep -q "disabled-$TEST_ID.*disabled" || {
        echo "❌ PocketBase should log that disabled job was not registered" >&2
        echo "  Recent PB logs:" >&2
        echo "$pb_logs" >&2
        return 1
    }

    echo "✓ Disabled cron job was not registered with scheduler"
}
