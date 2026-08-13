-- Headless Observability API for PocketCoder
-- This file provides a unified JSON summary of the platform state.
-- Pocket Memory is attached via config/on_connect.sql. Harness session stores
-- live in account-scoped dynamic volumes, so this deployment-wide dashboard
-- deliberately does not privilege one harness by mounting its private store.

-- Set output to JSON mode
SELECT 'json' AS component;

-- 1. System Health & Stats
SELECT
    0 AS total_messages,
    '$0.0000' AS cumulative_cost,
    0 AS cumulative_tokens,
    (SELECT status FROM healthchecks WHERE name = 'backend' LIMIT 1) AS backend_status;

-- Harness-neutral aggregate usage needs a common metrics contract. Until one
-- exists, return an honest empty series rather than reading Goose-only state.
SELECT
    'token_usage_by_model' AS key,
    json('[]') AS value;
