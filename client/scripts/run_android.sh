#!/bin/bash
# Run the PocketCoder Flutter client on a connected Android device or emulator
cd "$(dirname "$0")/.." || exit 1
flutter run -d android
