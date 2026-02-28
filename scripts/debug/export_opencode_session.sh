#!/bin/bash

# Script to export OpenCode session data as JSON

if [ "$#" -eq 0 ]; then
    echo "No session ID provided. You will be prompted to choose one."
    docker exec -it pocketcoder-opencode opencode export
else
    SESSION_ID=$1
    echo "Exporting session data for: $SESSION_ID"
    docker exec -it pocketcoder-opencode opencode export "$SESSION_ID"
fi
