-- Live, read-only visibility into PocketBase's own database. JSON mode,
-- rendered natively by the client -- see memory.sql for why (a webview
-- can't trust this deployment's self-signed Caddy CA).

SELECT 'json' AS component;

SELECT
  json(json_object(
    'users', (SELECT count(*) FROM users),
    'chats', (SELECT count(*) FROM chats),
    'agentProfiles', (SELECT count(*) FROM agent_profiles),
    'harnesses', (SELECT count(*) FROM harnesses),
    'mcpServers', (SELECT count(*) FROM mcp_servers),
    'skills', (SELECT count(*) FROM skills)
  )) AS counts,
  json((
    SELECT coalesce(json_group_array(json_object(
      'id', id,
      'title', title,
      'turn', turn,
      'archived', archived,
      'createdAt', created,
      'lastActive', last_active
    )), '[]')
    FROM (
      SELECT * FROM chats
      ORDER BY last_active DESC, id
      LIMIT 50
    )
  )) AS recent_chats;
