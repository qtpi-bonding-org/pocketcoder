#!/bin/bash
set -e

# Pre-restore: stop the stack before restoring data
docker compose down
