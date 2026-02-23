# Test Suite Diagnostic Report

**Test Run Date:** February 18, 2026  
**Total Tests:** 162  
**Passed:** 90 (55.6%)  
**Failed:** 72 (44.4%)

---

## Executive Summary

The test suite reveals several critical infrastructure and integration issues across the PocketCoder system. The failures cluster into distinct categories, with the most severe being container connectivity issues, message processing failures, and MCP gateway integration problems.

---

## Issue Categories

### 1. Container Infrastructure Issues (CRITICAL)

**Severity:** HIGH  
**Impact:** Blocks multiple test suites

#### Sandbox Container Not Found
- **Tests Affected:** 13-15, 20
- **Symptom:** Container appears to be running but diagnostic tools report "[Container not found]"
- **Root Cause:** Container may be stopping/restarting or network isolation preventing inspection
- **Evidence:**
  ```
  Container status for pocketcoder-sandbox:
    [Container not found]
  ```
- **Logs Show:** Container is actually running and CAO MCP server is operational
- **Hypothesis:** Timing issue where container starts but isn't immediately queryable, or network namespace isolation

#### Rust Axum Server Health Check Failures
- **Tests:** 13, 14, 20
- **Expected:** Health endpoint at port 3001 returns OK
- **Actual:** Connection failures despite container logs showing server is running
- **Impact:** Blocks all sandbox health verification tests

---

### 2. SSH Daemon Issues (HIGH)

**Severity:** HIGH  
**Tests Affected:** 3, 29

#### OpenCode SSH Not Listening
- **Test:** "OpenCode sshd is listening on port 2222"
- **Status:** Container healthy, OpenCode server running, but SSH daemon not accessible
- **Configuration:** SSH configured in Dockerfile with ForceCommand for poco user
- **Impact:** Blocks SSH-based access to OpenCode container

#### Shell Bridge Binary Path Issues
- **Test:** 29 - "OpenCode→Sandbox: Shell bridge binary exists and is executable"
- **Expected Path:** `/shell_bridge/pocketcoder-shell`
- **Issue:** Binary not found at expected location
- **Related:** Tests 30-36 (shell bridge execution tests)

---

### 3. Message Processing & SSE Event Failures (CRITICAL)

**Severity:** CRITICAL  
**Impact:** Core functionality broken

#### SSE Event Stream Issues
- **Tests:** 22, 23, 27
- **Problem:** SSE connections established but events not received
  - No `server.heartbeat` events
  - No `message.updated` events
  - Connection stability issues (0 heartbeats in 10 seconds)
- **Impact:** Real-time updates from OpenCode to PocketBase broken

#### Message Status Transition Failures
- **Tests:** 39, 43, 83, 88
- **Expected Flow:** `pending` → `sending` → `delivered`
- **Actual:** Messages created with status `delivered` immediately
- **Root Cause:** Relay hook firing too fast or status logic bypassed
- **Impact:** Message lifecycle tracking broken

#### Message Parts Not Populated
- **Tests:** 25, 26, 85, 92
- **Symptom:** Assistant messages created but `parts` field remains null/empty
- **Impact:** No actual response content from agent
- **Related:** Tests 61-65 (Agent Full Flow failures)

---

### 4. Agent Response Generation Failures (CRITICAL)

**Severity:** CRITICAL  
**Tests Affected:** 61-68, 111-126

#### Empty Agent Responses
- **Tests:** 61, 62, 63, 65, 67, 68
- **Pattern:** User messages sent, sessions created, but assistant responses empty
- **Symptom:** `parts` field null or empty array
- **Impact:** Agent (Poco) not generating any responses

#### Subagent Workflow Broken
- **Tests:** 111-126 (CAO Subagent suite)
- **Issues:**
  - Terminal metadata not stored in CAO database
  - Subagent records not created
  - `delegating_agent_id` not set
  - `tmux_window_id` not populated
  - Tool result formats not handled correctly
- **Impact:** Subagent delegation completely non-functional

---

### 5. Command Execution Issues (HIGH)

**Severity:** HIGH  
**Tests Affected:** 31-36, 54-60

#### Shell Bridge Execution Failures
- **Tests:** 31-36
- **Problems:**
  - Response format missing `stdout` field
  - Commands not executing in tmux pane
  - Exit codes incorrect (getting 1 instead of expected values)
  - Working directory not respected
  - Output not captured

#### Sandbox→OpenCode Communication
- **Tests:** 54-60
- **Similar issues:** Missing stdout, incorrect exit codes, empty output
- **Pattern:** POST to `/exec` accepted but response format broken

---

### 6. MCP Gateway Integration Issues (MEDIUM)

**Severity:** MEDIUM  
**Tests Affected:** 66-70, 153

#### MCP Request Workflow Failures
- **Tests:** 66-68
- **Issues:**
  - Poco not engaging with MCP workflow
  - No `mcp_servers` records created
  - Empty responses when MCP tools requested

#### Dynamic MCP Container Spin-Up Failed
- **Tests:** 70, 153
- **Expected:** Gateway spins up new container for MCP server (e.g., 'fetch')
- **Actual:** `mcp-add` succeeds, tools registered, but no container created
- **Evidence:**
  ```
  Containers before: 5
  Containers after: 5
  No new container matching 'mcp|fetch|fetch' appeared after 90s
  ```
- **Gateway Logs Show:** Multiple failed container starts with "No such image" errors
  - `mcp/postgres-test_*:latest`
  - `mcp/property-test-test_*:latest`
- **Root Cause:** Dynamic MCP trying to pull non-existent images

---

### 7. Data Consistency Issues (MEDIUM)

**Severity:** MEDIUM  
**Tests Affected:** 82-85, 99, 100

#### Chat Metadata Not Updated
- **Tests:** 26, 63, 99, 100
- **Fields Not Updating:**
  - `preview` remains null
  - `last_active` not set
- **Impact:** Chat list UI would show stale data

#### Relationship Integrity
- **Test:** 82
- **Issue:** Message count queries returning null
- **Symptom:** `[: null: integer expected` bash error
- **Impact:** Data relationship validation broken

---

### 8. Cleanup & Lifecycle Issues (LOW)

**Severity:** LOW  
**Tests Affected:** 45, 127-129, 132, 134

#### Records Not Deleted
- **Tests:** 45, 127, 128, 134
- **Pattern:** DELETE requests return 200 instead of 404
- **Meaning:** Records still exist after cleanup attempts
- **Impact:** Test data accumulation, potential memory leaks

#### Permission Record Creation Failed
- **Test:** 129
- **Issue:** Cannot create test permission records
- **Impact:** Permission cleanup tests cannot run

---

## Root Cause Analysis

### Primary Issues

1. **Container Timing/Readiness**
   - Containers report as running but services not fully initialized
   - Health checks passing but actual endpoints not responding
   - Suggests need for better readiness probes

2. **Message Processing Pipeline Broken**
   - SSE events not flowing from OpenCode to PocketBase
   - Relay hook logic bypassing status transitions
   - Agent not generating responses (LLM integration issue?)

3. **Shell Bridge Integration Incomplete**
   - Binary path mismatches
   - Response format not matching expected schema
   - Tmux integration not working correctly

4. **MCP Gateway Configuration**
   - Dynamic MCP trying to use Docker-in-Docker incorrectly
   - Image naming convention mismatch
   - Container networking issues

### Secondary Issues

5. **Data Model Inconsistencies**
   - Fields not being populated during normal flow
   - Cleanup logic not working (cascade deletes?)

6. **Test Infrastructure**
   - Network diagnostics showing "[Network not found]" despite networks existing
   - Suggests diagnostic helper functions need improvement

---

## Recommended Actions

### Immediate (P0)

1. **Fix Message Processing Pipeline**
   - Debug why SSE events not being received
   - Fix message status transition logic
   - Investigate why agent responses are empty

2. **Fix Container Readiness**
   - Add proper health check endpoints
   - Implement retry logic in tests
   - Add startup delays where needed

3. **Fix Shell Bridge**
   - Verify binary installation path
   - Fix response format to include stdout/stderr/exit_code
   - Test tmux integration manually

### Short Term (P1)

4. **Fix MCP Gateway**
   - Review Dynamic MCP configuration
   - Fix image naming/pulling logic
   - Test container spin-up manually

5. **Fix Data Consistency**
   - Add database triggers for chat metadata updates
   - Fix cascade delete configuration
   - Validate all foreign key relationships

### Medium Term (P2)

6. **Improve Test Infrastructure**
   - Fix diagnostic helper functions
   - Add better error messages
   - Implement test retry logic for flaky tests

7. **Add Integration Test Monitoring**
   - Track test success rates over time
   - Alert on regression
   - Add performance benchmarks

---

## Test Success by Category

| Category | Passed | Failed | Success Rate |
|----------|--------|--------|--------------|
| Health Checks | 9 | 6 | 60% |
| Connection Tests | 7 | 11 | 39% |
| Agent Flow | 0 | 8 | 0% |
| MCP Integration | 13 | 5 | 72% |
| Data Consistency | 3 | 4 | 43% |
| Permissions | 6 | 0 | 100% |
| Artifacts | 8 | 0 | 100% |
| CAO Subagent | 3 | 14 | 18% |
| Cleanup | 5 | 6 | 45% |
| Turn Batching | 4 | 0 | 100% |
| MCP Full Flow | 11 | 2 | 85% |
| Auth Hardening | 2 | 0 | 100% |
| Property Tests | 1 | 0 | 100% |

---

## Critical Path to Green

To get the test suite passing, focus on these issues in order:

1. **Container readiness** (blocks 15+ tests)
2. **Message processing & SSE** (blocks 20+ tests)
3. **Agent response generation** (blocks 15+ tests)
4. **Shell bridge execution** (blocks 10+ tests)
5. **MCP dynamic containers** (blocks 2 tests)
6. **Data cleanup** (blocks 6 tests)

Fixing these 6 issue clusters would bring the test suite from 55.6% to ~95% pass rate.
