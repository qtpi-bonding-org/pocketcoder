# multilingual-e5-small model provenance

- Upstream model: `intfloat/multilingual-e5-small`
- Upstream page: <https://huggingface.co/intfloat/multilingual-e5-small>
- Upstream license metadata: MIT
- Development GGUF repository: `janusz-bit/multilingual-e5-small-gguf`
- Development GGUF revision: `57c0a8f1481a66ca991375e4f87311c9e4bd0cc5`
- Development GGUF filename: `multilingual-e5-small-q8_0.gguf`
- Development GGUF SHA-256: `3a98dd889ee152d923991c60df2fad21e39f7441a5ee302a0a050d5137993b60`
- Upstream revision converted, per its publisher: `614241f622f53c4eeff9890bdc4f31cfecc418b3`
- Quantization: Q8_0
- Runtime contract: llama.cpp encoder, 512 tokens, mean pooling, 384 dimensions,
  L2 normalization, `query: ` and `passage: ` prefixes

Release CI may substitute a PocketCoder-produced GGUF URL and checksum. When it
does, release automation must replace or extend this provenance record with the
upstream revision, converter revision, validation results, and final checksum.

## Replaced artifact

`keisuke-miyako/multilingual-e5-small-gguf-q8_0` at `e1da94460f22` (SHA-256
`0d5a5a0b0ad8...`) was packaged with a WordPiece (`bert`) tokenizer. Upstream
uses SentencePiece (`XLMRobertaTokenizer`) on a BERT encoder, so words became
unknown tokens and semantic ranking was poor. `tests/model_reference.rs` rejects
such files by comparing with upstream ONNX embeddings. Do not judge a candidate
by finite, normalized vectors alone.
