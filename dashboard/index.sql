-- Unified Dashboard for PocketCoder
-- Databases are attached via sqlpage/config/on_connect.sql

-- Shell Component
SELECT 'shell' AS component,
       'PocketCoder Dashboard' AS title,
       'terminal' AS icon,
       '/' AS link,
       '#22c55e' AS color;

-- Menu Items
SELECT 'Observability' AS title, 'eye' AS icon, '?view=observability' AS link, ($view = 'observability') AS active;
SELECT 'Operations' AS title, 'activity' AS icon, '?view=operations' AS link, ($view = 'operations') AS active;
SELECT 'Analytics' AS title, 'bar-chart' AS icon, '?view=analytics' AS link, ($view = 'analytics') AS active;

-- Routing Logic
SELECT 'title' AS component, 'System Overview' AS contents WHERE $view IS NULL;

--- HOMEPAGE ---
SELECT 'datagrid' AS component WHERE $view IS NULL;
SELECT 'Total Messages' AS title, COUNT(*) AS value, 'blue' AS color FROM messages WHERE $view IS NULL;
SELECT 'Total Cost' AS title, printf('$%.4f', COALESCE(SUM(CAST(json_extract(data, '$.cost') AS FLOAT)), 0)) AS value, 'green' AS color FROM opencode.message WHERE $view IS NULL;
SELECT 'Total Tokens' AS title, printf('%d', COALESCE(SUM(CAST(json_extract(data, '$.tokens_total') AS INTEGER)), 0)) AS value, 'orange' AS color FROM opencode.message WHERE $view IS NULL;

SELECT 'title' AS component, 'Recent Operational Activity' AS contents WHERE $view IS NULL;
SELECT 'table' AS component, 1 AS sort, 1 AS search WHERE $view IS NULL;
SELECT 
    id,
    sender_id AS "From",
    receiver_id AS "To",
    substr(message, 1, 50) || '...' AS Message,
    status AS Status,
    strftime('%Y-%m-%d %H:%M', created_at) AS Created
FROM cao.inbox
WHERE $view IS NULL
ORDER BY created_at DESC
LIMIT 10;

--- OBSERVABILITY VIEW ---
SELECT 'title' AS component, 'Message Delivery Status' AS contents WHERE $view = 'observability';
SELECT 'chart' AS component, 'Delivery Status' AS title, 'pie' AS type WHERE $view = 'observability';
SELECT user_message_status AS label, COUNT(*) AS value
FROM messages
WHERE $view = 'observability'
GROUP BY user_message_status;

SELECT 'title' AS component, 'Messages per Chat' AS contents WHERE $view = 'observability';
SELECT 'table' AS component, 1 AS sort WHERE $view = 'observability';
SELECT 
    c.title AS 'Chat Name',
    COUNT(m.id) AS 'Messages',
    MAX(m.created) AS 'Last Activity'
FROM chats c
LEFT JOIN messages m ON m.chat = c.id
WHERE $view = 'observability'
GROUP BY c.id
ORDER BY 'Last Activity' DESC;

--- OPERATIONS VIEW ---
SELECT 'title' AS component, 'Operational Activity (Agent Inbox)' AS contents WHERE $view = 'operations';
SELECT 'table' AS component, 1 AS search, 1 AS sort WHERE $view = 'operations';
SELECT 
    id,
    status,
    sender_id AS "From",
    receiver_id AS "To",
    message AS Message,
    created_at AS 'Date',
    CASE 
        WHEN status = 'completed' THEN 'green'
        WHEN status = 'failed' THEN 'red'
        ELSE 'orange'
    END AS _sqlpage_color
FROM cao.inbox
WHERE $view = 'operations'
ORDER BY created_at DESC;

--- ANALYTICS VIEW ---
SELECT 'title' AS component, 'Token Usage by Model' AS contents WHERE $view = 'analytics';
SELECT 'chart' AS component, 'Tokens by Model' AS title, 'bar' AS type WHERE $view = 'analytics';
SELECT 
    COALESCE(json_extract(data, '$.model'), 'Unknown') AS label, 
    SUM(CAST(COALESCE(json_extract(data, '$.tokens_total'), 0) AS INTEGER)) AS value
FROM opencode.message
WHERE $view = 'analytics'
GROUP BY label;

SELECT 'title' AS component, 'LLM Performance & Cost' AS contents WHERE $view = 'analytics';
SELECT 'table' AS component, 1 AS sort WHERE $view = 'analytics';
SELECT 
    COALESCE(json_extract(data, '$.model'), 'Unknown') AS Model,
    COALESCE(json_extract(data, '$.provider'), 'Unknown') AS Provider,
    COUNT(*) AS 'Requests',
    printf('%.1f', AVG(CAST(COALESCE(json_extract(data, '$.tokens_total'), 0) AS INTEGER))) AS 'Avg Tokens',
    printf('$%.4f', SUM(CAST(COALESCE(json_extract(data, '$.cost'), 0) AS FLOAT))) AS 'Total Cost'
FROM opencode.message
WHERE $view = 'analytics'
GROUP BY Model, Provider
ORDER BY 'Total Cost' DESC;
