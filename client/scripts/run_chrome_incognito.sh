#!/bin/bash

# Run Flutter on Chrome in Incognito mode
# This is useful for testing onboarding and auth flows without session persistence
flutter run -d chrome --web-browser-flag="--incognito"
