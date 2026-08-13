-- Pocket Memory remains live in WAL mode. mode=ro observes committed WAL
-- content; immutable=1 would incorrectly allow SQLite to ignore it.
ATTACH DATABASE 'file:/memory_data/memory.sqlite3?mode=ro' AS memory;
