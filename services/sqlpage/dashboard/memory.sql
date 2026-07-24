-- Memory dashboard: recent entries from cognee's knowledge store.
-- Standalone — does not join against index.sql's goose-sourced queries (see
-- spec 2026-07-24-cognee-agent-memory-design.md §2, §5).
--
-- Table verified against a real running cognee-mcp container (not guessed):
-- cognee's relational SQLite file lives at
-- /cognee_data/system/databases/cognee_db (no .db extension, and under
-- system/databases/ specifically because SYSTEM_ROOT_DIRECTORY is pointed at
-- /cognee_data/system in docker-compose.yml — see spikes/cognee-mcp-transport/).
-- `data` is the table that holds each ingested memory item (name,
-- content_hash, token_count, created_at); cognee's plain-text-guess
-- placeholder `data_point` does not exist in the real schema.

SELECT 'title' AS component, 'Agent Memory' AS contents;

SELECT 'table' AS component, 'Recent Memories' AS title;
SELECT
  name,
  mime_type,
  token_count,
  data_size,
  created_at
FROM cognee.data
ORDER BY created_at DESC
LIMIT 50;
