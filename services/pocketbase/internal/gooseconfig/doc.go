// Package gooseconfig renders PocketBase agent-definition records into Goose's
// native config.yaml + keys env file. Pure (no I/O); the hook layer writes the
// bytes and owns file ownership/permissions.
package gooseconfig
