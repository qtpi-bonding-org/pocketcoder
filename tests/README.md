# PocketCoder Test Suite

Simple, focused test suite for verifying the permission/execution split architecture.

## Philosophy

**Happy paths only.** These tests verify that the system works correctly under normal conditions. They don't test error handling or edge cases.

## What's Tested

1. ✅ **Permissions collection exists**
2. ✅ **Read permissions auto-authorize**
3. ✅ **Write permissions auto-authorize**
4. ✅ **Bash permissions stay as draft**
5. ✅ **Permissions can be listed by session**
6. ✅ **Gateway health check** (informational)
7. ✅ **Commands collection exists**

## Prerequisites

- Docker containers running (`docker-compose up`)
- `jq` installed for JSON parsing
- `curl` for API calls

## Usage

```bash
# Run the full test suite
cd tests
chmod +x test_suite.sh
./test_suite.sh
```

## Output

The test suite provides colored output:
- 🔵 **Blue** - Informational messages
- ✅ **Green** - Passed tests
- ❌ **Red** - Failed tests
- ⚠️ **Yellow** - Warnings (non-critical)

Example output:
```
╔════════════════════════════════════════════════════════════════╗
║         PocketCoder Test Suite - Permission/Execution Split    ║
╚════════════════════════════════════════════════════════════════╝

ℹ Setting up test environment...
ℹ Authenticating as agent...
✅ Authenticated successfully

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TEST 1: Permissions Collection Exists
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Permissions collection exists

...

╔════════════════════════════════════════════════════════════════╗
║                        TEST SUMMARY                            ║
╚════════════════════════════════════════════════════════════════╝

  Total Tests:   9
  Passed:        9
  Failed:        0

✅ All tests passed! 🎉
```

## Cleanup

The test suite automatically cleans up test data on exit. Test records are tagged with `source: "test-suite"` for easy identification.

## Adding New Tests

To add a new test:

1. Create a new test section following the existing pattern
2. Use the helper functions:
   - `assert_equals <actual> <expected> <message>`
   - `assert_not_null <value> <message>`
   - `log_info <message>`
   - `log_success <message>`
   - `log_error <message>`
   - `log_warning <message>`

3. Keep it focused on happy paths

Example:
```bash
# ============================================================================
# TEST X: Your Test Name
# ============================================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST X: Your Test Name"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Your test logic here
RESPONSE=$(curl -s ...)
VALUE=$(echo "$RESPONSE" | jq -r '.field')

assert_equals "$VALUE" "expected" "Your assertion message"
echo ""
```

## Troubleshooting

**Authentication fails:**
- Ensure containers are running: `docker-compose ps`
- Check agent user exists: `docker logs pocketcoder-pocketbase | grep Seeding`

**Tests fail:**
- Check PocketBase is accessible: `curl http://localhost:8090/api/health`
- Check Gateway is running: `curl http://localhost:3001/health`
- View logs: `docker-compose logs`

**jq not found:**
```bash
# macOS
brew install jq

# Linux
sudo apt-get install jq
```
