-- Headless Observability API for PocketCoder
-- This file provides a unified JSON summary of the platform state.
-- Databases (goose, memory) are attached via config/on_connect.sql.
--
-- Previously read from an `opencode` database/schema that no longer exists
-- anywhere in this repo (opencode was fully removed — see git history);
-- rewritten against goose's own session store instead (real schema
-- verified against a live goose_data volume: sessions/messages tables,
-- sessions.accumulated_total_tokens/accumulated_cost,
-- sessions.model_config_json holding {"model_name": ...}).

-- Set output to JSON mode
SELECT 'json' AS component;

-- 1. System Health & Stats
SELECT
    (SELECT COUNT(*) FROM goose.messages) AS total_messages,
    (SELECT printf('$%.4f', COALESCE(SUM(accumulated_cost), 0)) FROM goose.sessions) AS cumulative_cost,
    (SELECT COALESCE(SUM(accumulated_total_tokens), 0) FROM goose.sessions) AS cumulative_tokens,
    (SELECT status FROM healthchecks WHERE name = 'backend' LIMIT 1) AS backend_status;

-- 2. Token Economics (Goose sessions)
-- Grouped token usage for chart data in Flutter
SELECT
    'token_usage_by_model' AS key,
    json_group_array(
        json_object(
            'model', model,
            'tokens', total_tokens
        )
    ) AS value
FROM (
    SELECT
        COALESCE(json_extract(model_config_json, '$.model_name'), 'unknown') AS model,
        SUM(COALESCE(accumulated_total_tokens, 0)) AS total_tokens
    FROM goose.sessions
    GROUP BY model
);
