-- Headless Observability API for PocketCoder
-- This file provides a unified JSON summary of the platform state.
-- Pocket Memory is attached via config/on_connect.sql. Harness session stores
-- live in account-scoped dynamic volumes, so this deployment-wide dashboard
-- deliberately does not privilege one harness by mounting its private store.
--
-- Message/cost/token usage has no real source anywhere in this deployment
-- yet (no such tracking exists in PocketBase's schema) -- left genuinely
-- empty rather than a fabricated non-zero value. Wiring stays in place on
-- both ends (this endpoint, SystemStats, ObservabilityCubit) for whenever
-- real usage tracking exists to back it.

SELECT 'json' AS component;

SELECT
    'token_usage_by_model' AS key,
    json('[]') AS value;
