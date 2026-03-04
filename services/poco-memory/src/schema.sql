-- poco-memory SurrealDB schema
-- Idempotent — safe to run every boot

-- Full-text analyzer
DEFINE ANALYZER IF NOT EXISTS memory_analyzer TOKENIZERS blank, class, punct FILTERS snowball(english);

-- Memory table
DEFINE TABLE IF NOT EXISTS memory SCHEMAFULL;
DEFINE FIELD IF NOT EXISTS content ON memory TYPE string;
DEFINE FIELD IF NOT EXISTS tags ON memory TYPE array<string> DEFAULT [];
DEFINE FIELD IF NOT EXISTS embedding ON memory TYPE array<float> ASSERT array::len($value) = 384;
DEFINE FIELD IF NOT EXISTS created_at ON memory TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS retrieved_at ON memory TYPE datetime DEFAULT time::now();

-- Vector index (HNSW, cosine, 384 dims for AllMiniLML6V2)
DEFINE INDEX IF NOT EXISTS idx_memory_embedding ON memory FIELDS embedding HNSW DIMENSION 384 DIST COSINE TYPE F32;

-- Full-text index
DEFINE INDEX IF NOT EXISTS idx_memory_content ON memory FIELDS content SEARCH ANALYZER memory_analyzer BM25;

-- Relation table for memory_relate
DEFINE TABLE IF NOT EXISTS relates_to TYPE RELATION SCHEMAFULL;
DEFINE FIELD IF NOT EXISTS label ON relates_to TYPE option<string>;
