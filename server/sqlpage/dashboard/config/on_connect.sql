-- goose's sessions.db is SQLite in WAL mode (spikes/goose-acp-http/README.md)
-- — ATTACHing a WAL database over a plain :ro bind mount fails ("unable to
-- open database file"), because SQLite needs to manage -shm/-wal sidecar
-- state even for readers. The file: URI's immutable=1 tells SQLite the file
-- won't change during this connection and to skip that machinery entirely
-- (verified empirically against the real mounted volume).
ATTACH DATABASE 'file:/goose_data/data/sessions/sessions.db?immutable=1' AS goose;
-- Pocket Memory remains live in WAL mode. mode=ro observes committed WAL
-- content; immutable=1 would incorrectly allow SQLite to ignore it.
ATTACH DATABASE 'file:/memory_data/memory.sqlite3?mode=ro' AS memory;
