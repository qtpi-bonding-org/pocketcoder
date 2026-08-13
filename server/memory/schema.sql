-- SPDX-License-Identifier: AGPL-3.0-or-later

CREATE TABLE memory_schema (
    schema_id TEXT PRIMARY KEY CHECK (schema_id = 'pocket-memory-v1')
) STRICT;
INSERT INTO memory_schema(schema_id) VALUES ('pocket-memory-v1');

CREATE TABLE observations (
    storage_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    id               TEXT NOT NULL UNIQUE,
    account_id       TEXT NOT NULL,
    agent_profile_id TEXT NOT NULL,
    agent_name       TEXT NOT NULL,
    body             TEXT NOT NULL CHECK (length(trim(body)) > 0),
    created_at       INTEGER NOT NULL,
    updated_at       INTEGER NOT NULL,
    retrieved_at     INTEGER NOT NULL
) STRICT;

CREATE INDEX observations_account_created
    ON observations(account_id, created_at DESC);
CREATE INDEX observations_account_agent_created
    ON observations(account_id, agent_profile_id, created_at DESC);
CREATE INDEX observations_account_retrieved
    ON observations(account_id, retrieved_at DESC);

CREATE TABLE interpretations (
    storage_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    id               TEXT NOT NULL UNIQUE,
    account_id       TEXT NOT NULL,
    agent_profile_id TEXT NOT NULL,
    agent_name       TEXT NOT NULL,
    body             TEXT NOT NULL CHECK (length(trim(body)) > 0),
    created_at       INTEGER NOT NULL,
    updated_at       INTEGER NOT NULL,
    retrieved_at     INTEGER NOT NULL
) STRICT;

CREATE INDEX interpretations_account_created
    ON interpretations(account_id, created_at DESC);
CREATE INDEX interpretations_account_agent_created
    ON interpretations(account_id, agent_profile_id, created_at DESC);
CREATE INDEX interpretations_account_retrieved
    ON interpretations(account_id, retrieved_at DESC);

CREATE TABLE interpretation_observations (
    interpretation_id TEXT NOT NULL
        REFERENCES interpretations(id) ON DELETE CASCADE,
    observation_id    TEXT NOT NULL
        REFERENCES observations(id) ON DELETE CASCADE,
    PRIMARY KEY (interpretation_id, observation_id)
) STRICT;

CREATE INDEX interpretation_observations_by_observation
    ON interpretation_observations(observation_id, interpretation_id);

CREATE VIRTUAL TABLE observations_fts USING fts5(
    body,
    content = 'observations',
    content_rowid = 'storage_id',
    tokenize = 'unicode61 remove_diacritics 2'
);

CREATE TRIGGER observations_fts_insert AFTER INSERT ON observations BEGIN
    INSERT INTO observations_fts(rowid, body) VALUES (new.storage_id, new.body);
END;

CREATE TRIGGER observations_fts_delete AFTER DELETE ON observations BEGIN
    INSERT INTO observations_fts(observations_fts, rowid, body)
    VALUES ('delete', old.storage_id, old.body);
END;

CREATE TRIGGER observations_fts_update AFTER UPDATE OF body ON observations BEGIN
    INSERT INTO observations_fts(observations_fts, rowid, body)
    VALUES ('delete', old.storage_id, old.body);
    INSERT INTO observations_fts(rowid, body) VALUES (new.storage_id, new.body);
END;

CREATE VIRTUAL TABLE interpretations_fts USING fts5(
    body,
    content = 'interpretations',
    content_rowid = 'storage_id',
    tokenize = 'unicode61 remove_diacritics 2'
);

CREATE TRIGGER interpretations_fts_insert AFTER INSERT ON interpretations BEGIN
    INSERT INTO interpretations_fts(rowid, body)
    VALUES (new.storage_id, new.body);
END;

CREATE TRIGGER interpretations_fts_delete AFTER DELETE ON interpretations BEGIN
    INSERT INTO interpretations_fts(interpretations_fts, rowid, body)
    VALUES ('delete', old.storage_id, old.body);
END;

CREATE TRIGGER interpretations_fts_update AFTER UPDATE OF body ON interpretations BEGIN
    INSERT INTO interpretations_fts(interpretations_fts, rowid, body)
    VALUES ('delete', old.storage_id, old.body);
    INSERT INTO interpretations_fts(rowid, body)
    VALUES (new.storage_id, new.body);
END;

CREATE VIRTUAL TABLE observation_vectors USING vec0(
    storage_id INTEGER PRIMARY KEY,
    embedding FLOAT[384] distance_metric=cosine,
    account_id TEXT PARTITION KEY
);

CREATE TABLE observation_embedding_state (
    storage_id        INTEGER PRIMARY KEY
        REFERENCES observations(storage_id) ON DELETE CASCADE,
    source_hash       BLOB NOT NULL CHECK (length(source_hash) = 32),
    embedding_version TEXT NOT NULL,
    embedded_at       INTEGER NOT NULL
) STRICT;

CREATE TRIGGER observations_vector_delete AFTER DELETE ON observations BEGIN
    DELETE FROM observation_vectors WHERE storage_id = old.storage_id;
END;

CREATE TRIGGER observations_vector_invalidate AFTER UPDATE OF body ON observations BEGIN
    DELETE FROM observation_vectors WHERE storage_id = old.storage_id;
    DELETE FROM observation_embedding_state WHERE storage_id = old.storage_id;
END;

CREATE VIRTUAL TABLE interpretation_vectors USING vec0(
    storage_id INTEGER PRIMARY KEY,
    embedding FLOAT[384] distance_metric=cosine,
    account_id TEXT PARTITION KEY
);

CREATE TABLE interpretation_embedding_state (
    storage_id        INTEGER PRIMARY KEY
        REFERENCES interpretations(storage_id) ON DELETE CASCADE,
    source_hash       BLOB NOT NULL CHECK (length(source_hash) = 32),
    embedding_version TEXT NOT NULL,
    embedded_at       INTEGER NOT NULL
) STRICT;

CREATE TRIGGER interpretations_vector_delete AFTER DELETE ON interpretations BEGIN
    DELETE FROM interpretation_vectors WHERE storage_id = old.storage_id;
END;

CREATE TRIGGER interpretations_vector_invalidate AFTER UPDATE OF body ON interpretations BEGIN
    DELETE FROM interpretation_vectors WHERE storage_id = old.storage_id;
    DELETE FROM interpretation_embedding_state WHERE storage_id = old.storage_id;
END;
