#!/bin/bash

# Run Flutter on the iOS simulator from the app shell
# Note: Ensure an iOS simulator is running (e.g. via 'open -a Simulator')
cd apps/app && flutter run -d iPhone
