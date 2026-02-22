-- Headless Observability API for PocketCoder
-- This file provides a unified JSON summary of the platform state.
-- Databases (opencode, cao) are attached via sqlpage/config/on_connect.sql

-- Set output to JSON mode
SELECT 'json' AS component;

-- 1. System Health & Stats
SELECT 
    (SELECT COUNT(*) FROM messages) AS total_messages,
    (SELECT printf('$%.4f', COALESCE(SUM(CAST(json_extract(data, '$.cost') AS FLOAT)), 0)) FROM opencode.message) AS cumulative_cost,
    (SELECT COALESCE(SUM(CAST(json_extract(data, '$.tokens_total') AS INTEGER)), 0) FROM opencode.message) AS cumulative_tokens,
    (SELECT status FROM healthchecks WHERE name = 'backend' LIMIT 1) AS backend_status;

-- 2. Active Operational Context (CAO)
-- Returns the latest subagent activity
SELECT 
    'operational_tasks' AS key,
    json_group_array(
        json_object(
            'id', id,
            'status', status,
            'sender', sender_id,
            'receiver', receiver_id,
            'summary', substr(message, 1, 100),
            'timestamp', created_at
        )
    ) AS value
FROM (
    SELECT * FROM cao.inbox 
    ORDER BY created_at DESC 
    LIMIT 5
);

-- 3. Token Economics (OpenCode)
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
        COALESCE(json_extract(data, '$.model'), 'unknown') AS model,
        SUM(CAST(COALESCE(json_extract(data, '$.tokens_total'), 0) AS INTEGER)) AS total_tokens
    FROM opencode.message
    GROUP BY model
);
