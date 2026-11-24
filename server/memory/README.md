# Pocket Memory

The code here is a vendored copy of
<https://github.com/qtpi-bonding/pocket-memory>; see `VENDORED`. Change it there,
then run `tooling/scripts/sync_pocket_memory.sh`. This README is PocketCoder's own.

Pocket Memory is PocketCoder's lightweight, local-first MCP memory service. It
stores mutable agent-authored observations and interpretations in SQLite, links
them through an ordinary many-to-many join, and retrieves them with FTS5 plus a
local multilingual embedding model. It does not call a generative LLM or decide
what is true.

The service is licensed under `AGPL-3.0-or-later`, like the PocketCoder
repository. The separately distributed `intfloat/multilingual-e5-small` model
is MIT-licensed and must ship with its upstream license and model provenance.

## Architecture

The crate deliberately uses conventional thin layers:

```text
MCP/HTTP -> service/use cases -> explicit SQLite repositories
                       |-> llama.cpp embedder worker
                       `-> FTS/vector candidate fusion and ranking
```

`schema.sql` is the complete schema for this unreleased backend. There is no
historical migration chain. Startup initializes an empty database or rejects a
database carrying another schema identifier.

## Agent MCP surface

Pocket Memory exposes eight tools to coding agents:

- `memory_create_observation`
- `memory_create_interpretation`
- `memory_link`
- `memory_unlink`
- `memory_get_observation`
- `memory_get_interpretation`
- `memory_list`
- `memory_search`

Every interpretation must remain linked to at least one observation. All links
are equal rows in the `interpretation_observations` many-to-many table; there is
no separate or privileged basis relationship. Interpretation creation accepts
either an existing observation or a new observation body, in which case both
records and their link are committed atomically. Additional existing
observations may be linked in the same transaction.

Body updates and record deletion remain internal service/repository primitives
for a future user-owned memory-management interface. They are deliberately not
exposed as agent MCP tools.

## Model contract

- Upstream: `intfloat/multilingual-e5-small`
- Format: PocketCoder-produced Q8_0 GGUF
- Runtime: in-process llama.cpp CPU encoder
- Context: 512 tokens
- Pooling: mean
- Output: 384 dimensions, L2-normalized
- Query prefix: `query: `
- Stored-document prefix: `passage: `

The release artifact must be generated from pinned upstream and converter
revisions, validated against the upstream F32 model, checksum-pinned, and
bundled so production startup needs no network access.

For development, `docker compose build pocket-memory` downloads the immutable
MIT Q8_0 artifact from `janusz-bit/multilingual-e5-small-gguf` commit
`57c0a8f1481a66ca991375e4f87311c9e4bd0cc5` and verifies SHA-256
`3a98dd889ee152d923991c60df2fad21e39f7441a5ee302a0a050d5137993b60`.
`tests/model_compat.rs` verifies that the configured artifact loads through the
actual adapter and produces finite, normalized multilingual embeddings, and
`tests/model_reference.rs` compares them with upstream. Release
CI requires explicit model URL and checksum values so production can switch to
PocketCoder's independently reproduced artifact without runtime changes.

### Model delivery

The container build downloads the pinned GGUF, verifies its SHA-256, and copies
the model plus its MIT license and provenance into the final image. The deployed
service does not download the model at startup and does not need network access
to start or perform semantic retrieval. The current Q8_0 GGUF is approximately
126 MiB on disk.

### Measured memory footprint

Idle is the memory held while the service waits for work; it is not zero, because
the model stays loaded. The peak grows with the length of the text embedded, up to
the 512-token limit, and is not released afterwards.

Container memory measured on 2026-11-24, arm64 Debian Bookworm, release build,
bundled Q8_0 model, CPU only:

| State | Container memory |
| --- | ---: |
| Ready, before the first embedding | approximately 265 MiB |
| After a short note | approximately 270 MiB |
| After a note that fills the 512-token limit | approximately 760 MiB |

About 130 MiB of the total is file-backed model data that the operating system
can reclaim under pressure. Measurements on other architectures may differ.

Allow at least 1 GiB for the service. At 512 MiB it was killed while importing
long notes. These are service-level sizing numbers, not a whole-stack PocketCoder
memory requirement.

## Acknowledgements and provenance

[mcp-local-memory](https://github.com/Beledarian/mcp-local-memory) (MIT) was
consulted as design prior art, especially its independent FTS/vector candidate
retrieval and explicit FTS fallback. Pocket Memory does not copy its source and
does not adopt its graph, archivist, task, reinforcement, or extension models.
Its MIT license therefore remains a reference to the consulted project rather
than a license applied to Pocket Memory's original AGPL source.

Bundled Rust dependencies and native/model artifacts retain their respective
licenses. Release packaging must include the generated dependency license report
and the model's upstream license/provenance files.
