#!/bin/bash
# Master test runner for incremental refactor testing
# Executes all zone tests and reports overall pass/fail status

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🧪 Running Incremental Refactor Tests"
echo "======================================"
echo ""

FAILED=0

# Execute Zone A tests (run from host - PocketBase accessible)
echo "📂 Running Zone A tests (PocketBase + Relay)..."
if ! "$SCRIPT_DIR/zone_a_tests.sh"; then
    echo "❌ Zone A tests failed"
    FAILED=1
else
    echo "✅ Zone A tests passed"
fi
echo ""

# Execute Zone B tests (run inside container - OpenCode only accessible inside Docker)
echo "📂 Running Zone B tests (OpenCode)..."
if ! "$SCRIPT_DIR/run_test.sh" b pocketcoder-opencode; then
    echo "❌ Zone B tests failed"
    FAILED=1
else
    echo "✅ Zone B tests passed"
fi
echo ""

# Execute Zone C tests (run from host - needs docker access)
echo "📂 Running Zone C tests (Sandbox)..."
if ! "$SCRIPT_DIR/zone_c_tests.sh"; then
    echo "❌ Zone C tests failed"
    FAILED=1
else
    echo "✅ Zone C tests passed"
fi
echo ""

# Execute Zone D tests (run from host - needs docker access)
echo "📂 Running Zone D tests (CAO Sandbox)..."
if ! "$SCRIPT_DIR/zone_d_tests.sh"; then
    echo "❌ Zone D tests failed"
    FAILED=1
else
    echo "✅ Zone D tests passed"
fi
echo ""

# Execute Zone E tests (run from host - System Integration)
echo "📂 Running Zone E tests (System Integration)..."
if ! "$SCRIPT_DIR/zone_e_system_tests.sh"; then
    echo "❌ Zone E tests failed"
    FAILED=1
else
    echo "✅ Zone E tests passed"
fi
echo ""

# Execute Zone F tests (run from host - Security)
echo "📂 Running Zone F tests (Security)..."
if ! "$SCRIPT_DIR/zone_f_security_tests.sh"; then
    echo "❌ Zone F tests failed"
    FAILED=1
else
    echo "✅ Zone F tests passed"
fi
echo ""

# Execute Zone G tests (run from host - Advanced Features)
echo "📂 Running Zone G tests (Advanced Features)..."
if ! "$SCRIPT_DIR/zone_g_advanced_tests.sh"; then
    echo "❌ Zone G tests failed"
    FAILED=1
else
    echo "✅ Zone G tests passed"
fi
echo ""

echo "======================================"
if [ $FAILED -eq 0 ]; then
    echo "✅ All tests passed!"
    exit 0
else
    echo "❌ Some tests failed"
    echo ""
    echo "For alignment guidance, see: LINEAR_ARCHITECTURE_PLAN.md"
    exit 1
fi