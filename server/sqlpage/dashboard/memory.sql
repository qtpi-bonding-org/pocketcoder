-- Live, read-only visibility into Pocket Memory's canonical tables.
-- JSON mode: the client renders this natively (MemoryDashboardScreen),
-- not via an embedded webview -- a webview would use the OS's own
-- networking stack, which never learns to trust a deployment's
-- self-signed Caddy CA, unlike this app's own pinned HTTP client. Vector
-- and embedding-state tables are deliberately absent from this page.

SELECT 'json' AS component;

SELECT
  json(json_object(
    'observations', (SELECT count(*) FROM memory.observations),
    'interpretations', (SELECT count(*) FROM memory.interpretations),
    'links', (SELECT count(*) FROM memory.interpretation_observations)
  )) AS counts,
  json((
    SELECT coalesce(json_group_array(json_object(
      'accountId', account_id,
      'agentProfileId', agent_profile_id,
      'agentName', agent_name,
      'observations', observations,
      'interpretations', interpretations
    )), '[]')
    FROM (
      SELECT account_id, agent_profile_id, agent_name,
             sum(observations) AS observations,
             sum(interpretations) AS interpretations
      FROM (
        SELECT account_id, agent_profile_id, agent_name,
               count(*) AS observations, 0 AS interpretations
        FROM memory.observations
        GROUP BY account_id, agent_profile_id, agent_name
        UNION ALL
        SELECT account_id, agent_profile_id, agent_name,
               0 AS observations, count(*) AS interpretations
        FROM memory.interpretations
        GROUP BY account_id, agent_profile_id, agent_name
      )
      GROUP BY account_id, agent_profile_id, agent_name
    )
  )) AS by_account,
  json((
    SELECT coalesce(json_group_array(json_object(
      'id', id,
      'accountId', account_id,
      'author', agent_name,
      'body', body,
      'createdAt', datetime(created_at / 1000, 'unixepoch'),
      'updatedAt', datetime(updated_at / 1000, 'unixepoch'),
      'retrievedAt', datetime(retrieved_at / 1000, 'unixepoch')
    )), '[]')
    FROM (
      SELECT * FROM memory.observations
      ORDER BY created_at DESC, id
      LIMIT 50
    )
  )) AS recent_observations,
  json((
    SELECT coalesce(json_group_array(json_object(
      'id', interpretation.id,
      'accountId', interpretation.account_id,
      'author', interpretation.agent_name,
      'body', interpretation.body,
      'createdAt', datetime(interpretation.created_at / 1000, 'unixepoch'),
      'updatedAt', datetime(interpretation.updated_at / 1000, 'unixepoch'),
      'retrievedAt', datetime(interpretation.retrieved_at / 1000, 'unixepoch'),
      'linkedObservations', json((
        SELECT coalesce(json_group_array(observation.body), '[]')
        FROM memory.interpretation_observations AS link
        JOIN memory.observations AS observation
          ON observation.id = link.observation_id
        WHERE link.interpretation_id = interpretation.id
      ))
    )), '[]')
    FROM (
      SELECT * FROM memory.interpretations
      ORDER BY created_at DESC, id
      LIMIT 50
    ) AS interpretation
  )) AS recent_interpretations;
