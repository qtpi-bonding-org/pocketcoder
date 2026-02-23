#!/bin/bash
# purity_check.sh
# Verifies that a package and its local dependencies in the workspace are FOSS-pure.

PACKAGE=$1
if [ -z "$PACKAGE" ]; then
  echo "Usage: $0 <package_name>"
  exit 1
fi

echo "Checking purity for $PACKAGE..."

# 1. Get all local packages that $PACKAGE depends on (using Melos)
# We can use melos list --graph and parse it, or just use the known structure.
# For a more robust check, we can use 'melos list --scope=$PACKAGE --include-dependencies --json'

DEPS_JSON=$(melos list --scope=$PACKAGE --include-dependencies --json)

# 2. Check each package in the dependency list
echo "$DEPS_JSON" | grep -oE '"path":"[^"]+"' | cut -d'"' -f4 | while read -r pkg_path; do
  echo "  Inspecting $pkg_path..."
  # Check pubspec.yaml for forbidden strings
  if grep -riE "firebase|revenuecat|purchases_flutter" "$pkg_path/pubspec.yaml" | grep -v "#" > /dev/null; then
    echo "  ERROR: Proprietary dependency found in $pkg_path/pubspec.yaml"
    grep -niE "firebase|revenuecat|purchases_flutter" "$pkg_path/pubspec.yaml" | grep -v "#"
    exit 1
  fi
  
  # Check lib/ for forbidden imports (excluding comments)
  if grep -rk "import" "$pkg_path/lib" | grep -riE "firebase|revenuecat|purchases_flutter" > /dev/null; then
    echo "  ERROR: Proprietary import found in $pkg_path/lib"
    grep -rk "import" "$pkg_path/lib" | grep -riE "firebase|revenuecat|purchases_flutter"
    exit 1
  fi
done

if [ $? -eq 0 ]; then
  echo "SUCCESS: $PACKAGE and its local dependencies are FOSS-pure."
else
  exit 1
fi
