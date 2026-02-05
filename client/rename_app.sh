#!/bin/bash

# Flutter App Rename Script
# Usage: ./rename_app.sh "MyNewApp" "com.example.mynewapp"
#
# This script renames the Flutter app throughout the project, including:
# - Package name in pubspec.yaml
# - Android package name and app label
# - iOS bundle identifier and display name
# - Import statements in Dart files
# - App title in main widget

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
NEW_APP_NAME="$1"
NEW_PACKAGE_ID="$2"

if [ -z "$NEW_APP_NAME" ]; then
    echo -e "${RED}Error: App name is required${NC}"
    echo "Usage: $0 \"MyNewApp\" [\"com.example.myapp\"]"
    echo ""
    echo "Arguments:"
    echo "  App Name     - The display name of your app (e.g., 'My Cool App')"
    echo "  Package ID   - Optional. The bundle/package identifier (e.g., 'com.example.mycoolapp')"
    echo "                 If not provided, will be derived from app name"
    exit 1
fi

# Derive package name from app name if not provided
# Convert to lowercase and remove spaces/special chars
SNAKE_CASE_NAME=$(echo "$NEW_APP_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | sed 's/[^a-z0-9_]//g')

if [ -z "$NEW_PACKAGE_ID" ]; then
    NEW_PACKAGE_ID="com.example.$SNAKE_CASE_NAME"
    echo -e "${YELLOW}No package ID provided, using: $NEW_PACKAGE_ID${NC}"
fi

# Current values (from the template)
OLD_PACKAGE_NAME="flutter_starter_template"
OLD_PACKAGE_ID="com.fluttertemplate.flutter_starter_template"
OLD_DISPLAY_NAME="flutter_starter_template"

echo ""
echo -e "${GREEN}=== Flutter App Rename Script ===${NC}"
echo ""
echo "Renaming app to:"
echo "  Display Name: $NEW_APP_NAME"
echo "  Package Name: $SNAKE_CASE_NAME"
echo "  Package ID:   $NEW_PACKAGE_ID"
echo ""

# Function to replace in file
replace_in_file() {
    local file="$1"
    local from="$2"
    local to="$3"
    
    if [ -f "$file" ]; then
        if grep -q "$from" "$file" 2>/dev/null; then
            sed -i '' "s|$from|$to|g" "$file"
            echo "  Updated: $file"
        fi
    fi
}

# Function to replace in all Dart files
replace_in_dart_files() {
    local from="$1"
    local to="$2"
    
    find "$SCRIPT_DIR/lib" -name "*.dart" -type f | while read -r file; do
        if grep -q "$from" "$file" 2>/dev/null; then
            sed -i '' "s|$from|$to|g" "$file"
            echo "  Updated: $file"
        fi
    done
    
    find "$SCRIPT_DIR/test" -name "*.dart" -type f | while read -r file; do
        if grep -q "$from" "$file" 2>/dev/null; then
            sed -i '' "s|$from|$to|g" "$file"
            echo "  Updated: $file"
        fi
    done
}

echo -e "${GREEN}Step 1: Updating pubspec.yaml${NC}"
replace_in_file "$SCRIPT_DIR/pubspec.yaml" "name: $OLD_PACKAGE_NAME" "name: $SNAKE_CASE_NAME"
replace_in_file "$SCRIPT_DIR/pubspec.yaml" "description: \"A robust Flutter project template from the Quanitya architecture.\"" "description: \"$NEW_APP_NAME - A Flutter application.\""

echo ""
echo -e "${GREEN}Step 2: Updating Dart imports${NC}"
replace_in_dart_files "package:$OLD_PACKAGE_NAME/" "package:$SNAKE_CASE_NAME/"

echo ""
echo -e "${GREEN}Step 3: Updating Android configuration${NC}"

# Android app/build.gradle.kts
ANDROID_BUILD="$SCRIPT_DIR/android/app/build.gradle.kts"
if [ -f "$ANDROID_BUILD" ]; then
    sed -i '' "s|namespace = \"$OLD_PACKAGE_ID\"|namespace = \"$NEW_PACKAGE_ID\"|g" "$ANDROID_BUILD"
    sed -i '' "s|applicationId = \"$OLD_PACKAGE_ID\"|applicationId = \"$NEW_PACKAGE_ID\"|g" "$ANDROID_BUILD"
    echo "  Updated: $ANDROID_BUILD"
fi

# Android Manifest
ANDROID_MANIFEST="$SCRIPT_DIR/android/app/src/main/AndroidManifest.xml"
if [ -f "$ANDROID_MANIFEST" ]; then
    sed -i '' "s|android:label=\"$OLD_DISPLAY_NAME\"|android:label=\"$NEW_APP_NAME\"|g" "$ANDROID_MANIFEST"
    echo "  Updated: $ANDROID_MANIFEST"
fi

# Android Kotlin path
OLD_KOTLIN_PATH="$SCRIPT_DIR/android/app/src/main/kotlin/com/fluttertemplate/flutter_starter_template"
NEW_KOTLIN_BASE="$SCRIPT_DIR/android/app/src/main/kotlin"

if [ -d "$OLD_KOTLIN_PATH" ]; then
    # Create new directory structure based on package ID
    NEW_KOTLIN_PATH="$NEW_KOTLIN_BASE/$(echo "$NEW_PACKAGE_ID" | tr '.' '/')"
    mkdir -p "$NEW_KOTLIN_PATH"
    
    # Move MainActivity
    if [ -f "$OLD_KOTLIN_PATH/MainActivity.kt" ]; then
        # Update package declaration in MainActivity
        sed -i '' "s|package com.fluttertemplate.flutter_starter_template|package $NEW_PACKAGE_ID|g" "$OLD_KOTLIN_PATH/MainActivity.kt"
        mv "$OLD_KOTLIN_PATH/MainActivity.kt" "$NEW_KOTLIN_PATH/"
        echo "  Moved: MainActivity.kt to $NEW_KOTLIN_PATH"
    fi
    
    # Remove old directories
    rm -rf "$SCRIPT_DIR/android/app/src/main/kotlin/com/fluttertemplate"
fi

echo ""
echo -e "${GREEN}Step 4: Updating iOS configuration${NC}"

# iOS Info.plist
IOS_INFO_PLIST="$SCRIPT_DIR/ios/Runner/Info.plist"
if [ -f "$IOS_INFO_PLIST" ]; then
    # Update bundle display name
    sed -i '' "s|<string>$OLD_DISPLAY_NAME</string>|<string>$NEW_APP_NAME</string>|g" "$IOS_INFO_PLIST"
    echo "  Updated: $IOS_INFO_PLIST"
fi

# iOS project.pbxproj (bundle identifier)
IOS_PBXPROJ="$SCRIPT_DIR/ios/Runner.xcodeproj/project.pbxproj"
if [ -f "$IOS_PBXPROJ" ]; then
    sed -i '' "s|PRODUCT_BUNDLE_IDENTIFIER = $OLD_PACKAGE_ID|PRODUCT_BUNDLE_IDENTIFIER = $NEW_PACKAGE_ID|g" "$IOS_PBXPROJ"
    echo "  Updated: $IOS_PBXPROJ"
fi

echo ""
echo -e "${GREEN}Step 5: Updating macOS configuration${NC}"

# macOS Info.plist
MACOS_INFO_PLIST="$SCRIPT_DIR/macos/Runner/Info.plist"
if [ -f "$MACOS_INFO_PLIST" ]; then
    sed -i '' "s|<string>$OLD_DISPLAY_NAME</string>|<string>$NEW_APP_NAME</string>|g" "$MACOS_INFO_PLIST"
    echo "  Updated: $MACOS_INFO_PLIST"
fi

# macOS project.pbxproj
MACOS_PBXPROJ="$SCRIPT_DIR/macos/Runner.xcodeproj/project.pbxproj"
if [ -f "$MACOS_PBXPROJ" ]; then
    sed -i '' "s|PRODUCT_BUNDLE_IDENTIFIER = $OLD_PACKAGE_ID|PRODUCT_BUNDLE_IDENTIFIER = $NEW_PACKAGE_ID|g" "$MACOS_PBXPROJ"
    echo "  Updated: $MACOS_PBXPROJ"
fi

echo ""
echo -e "${GREEN}Step 6: Updating Linux configuration${NC}"

# Linux CMakeLists.txt
LINUX_CMAKE="$SCRIPT_DIR/linux/CMakeLists.txt"
if [ -f "$LINUX_CMAKE" ]; then
    sed -i '' "s|set(BINARY_NAME \"$OLD_PACKAGE_NAME\")|set(BINARY_NAME \"$SNAKE_CASE_NAME\")|g" "$LINUX_CMAKE"
    sed -i '' "s|set(APPLICATION_ID \"$OLD_PACKAGE_ID\")|set(APPLICATION_ID \"$NEW_PACKAGE_ID\")|g" "$LINUX_CMAKE"
    echo "  Updated: $LINUX_CMAKE"
fi

echo ""
echo -e "${GREEN}Step 7: Updating Windows configuration${NC}"

# Windows CMakeLists.txt
WINDOWS_CMAKE="$SCRIPT_DIR/windows/CMakeLists.txt"
if [ -f "$WINDOWS_CMAKE" ]; then
    sed -i '' "s|set(BINARY_NAME \"$OLD_PACKAGE_NAME\")|set(BINARY_NAME \"$SNAKE_CASE_NAME\")|g" "$WINDOWS_CMAKE"
    echo "  Updated: $WINDOWS_CMAKE"
fi

echo ""
echo -e "${GREEN}Step 8: Updating Web configuration${NC}"

# Web index.html
WEB_INDEX="$SCRIPT_DIR/web/index.html"
if [ -f "$WEB_INDEX" ]; then
    sed -i '' "s|<title>$OLD_PACKAGE_NAME</title>|<title>$NEW_APP_NAME</title>|g" "$WEB_INDEX"
    echo "  Updated: $WEB_INDEX"
fi

# Web manifest.json
WEB_MANIFEST="$SCRIPT_DIR/web/manifest.json"
if [ -f "$WEB_MANIFEST" ]; then
    sed -i '' "s|\"name\": \"$OLD_PACKAGE_NAME\"|\"name\": \"$NEW_APP_NAME\"|g" "$WEB_MANIFEST"
    sed -i '' "s|\"short_name\": \"$OLD_PACKAGE_NAME\"|\"short_name\": \"$NEW_APP_NAME\"|g" "$WEB_MANIFEST"
    echo "  Updated: $WEB_MANIFEST"
fi

echo ""
echo -e "${GREEN}Step 9: Updating App title in code${NC}"
# Update the app title in app.dart
APP_DART="$SCRIPT_DIR/lib/app/app.dart"
if [ -f "$APP_DART" ]; then
    sed -i '' "s|title: 'Flutter Template'|title: '$NEW_APP_NAME'|g" "$APP_DART"
    echo "  Updated: $APP_DART"
fi

echo ""
echo -e "${GREEN}Step 10: Cleaning up${NC}"
# Remove .iml files (IDE-specific)
find "$SCRIPT_DIR" -name "*.iml" -type f -delete
echo "  Removed .iml files"

# Clean build artifacts
rm -rf "$SCRIPT_DIR/build"
echo "  Removed build directory"

echo ""
echo -e "${GREEN}=== Rename Complete! ===${NC}"
echo ""
echo "Next steps:"
echo "  1. Run 'flutter pub get' to update dependencies"
echo "  2. Run 'dart run build_runner build --delete-conflicting-outputs' to regenerate code"
echo "  3. Run 'flutter analyze' to verify no issues"
echo "  4. Run 'flutter run' to test the app"
echo ""
echo -e "${YELLOW}Note: You may need to manually update the app icons in:${NC}"
echo "  - android/app/src/main/res/mipmap-*/ic_launcher.png"
echo "  - ios/Runner/Assets.xcassets/AppIcon.appiconset/"
echo "  - web/icons/"
echo ""
