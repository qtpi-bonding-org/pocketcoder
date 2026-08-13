-- Live, read-only visibility into Pocket Memory's canonical tables.
-- Vector and embedding-state tables are deliberately absent from this page.

SELECT 'title' AS component, 'Agent Memory' AS contents;

SELECT 'card' AS component, 3 AS columns;
SELECT 'Observations' AS title, count(*) AS description
FROM memory.observations;
SELECT 'Interpretations' AS title, count(*) AS description
FROM memory.interpretations;
SELECT 'Links' AS title, count(*) AS description
FROM memory.interpretation_observations;

SELECT 'table' AS component, 'Memory by Account and Author' AS title;
SELECT
  account_id,
  agent_profile_id,
  agent_name,
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
ORDER BY account_id, agent_name, agent_profile_id;

SELECT 'table' AS component, 'Recent Observations' AS title;
SELECT
  id,
  account_id,
  agent_name AS author,
  body,
  datetime(created_at / 1000, 'unixepoch') AS created_at,
  datetime(updated_at / 1000, 'unixepoch') AS updated_at,
  datetime(retrieved_at / 1000, 'unixepoch') AS retrieved_at
FROM memory.observations
ORDER BY created_at DESC, id
LIMIT 50;

SELECT 'table' AS component, 'Recent Interpretations' AS title;
SELECT
  interpretation.id,
  interpretation.account_id,
  interpretation.agent_name AS author,
  interpretation.body,
  count(link.observation_id) AS linked_observations,
  datetime(interpretation.created_at / 1000, 'unixepoch') AS created_at,
  datetime(interpretation.updated_at / 1000, 'unixepoch') AS updated_at,
  datetime(interpretation.retrieved_at / 1000, 'unixepoch') AS retrieved_at
FROM memory.interpretations AS interpretation
LEFT JOIN memory.interpretation_observations AS link
  ON link.interpretation_id = interpretation.id
GROUP BY interpretation.id
ORDER BY interpretation.created_at DESC, interpretation.id
LIMIT 50;

SELECT 'table' AS component, 'Interpretation Details' AS title;
SELECT
  interpretation.id AS interpretation_id,
  interpretation.agent_name AS author,
  interpretation.body AS interpretation,
  COALESCE(group_concat(observation.body, ' | '), '') AS linked_observations
FROM memory.interpretations AS interpretation
LEFT JOIN memory.interpretation_observations AS link
  ON link.interpretation_id = interpretation.id
LEFT JOIN memory.observations AS observation
  ON observation.id = link.observation_id
GROUP BY interpretation.id
ORDER BY interpretation.updated_at DESC, interpretation.id
LIMIT 50;
