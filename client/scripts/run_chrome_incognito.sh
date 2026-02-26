#!/bin/bash

# Run Flutter on Chrome in Incognito mode from the app shell
# This is useful for testing onboarding and auth flows without session persistence
cd apps/app && flutter run -d chrome --web-browser-flag="--incognito"
