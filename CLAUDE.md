# PocketCoder

## Model Generation Pipeline

After changing PB collections/schema, run this sequence:

1. `docker compose build pocketbase opencode` — rebuild containers
2. `docker compose up -d pocketbase opencode` — start with new code
3. `scripts/export_schema.sh` — exports PB schema to `client/packages/pocketcoder_flutter/assets/pb_schema.json`
4. `cd client/packages/pocketcoder_flutter && python3 scripts/generate_models.py` — generates Dart models in `lib/domain/models/`
5. `dart run build_runner build --delete-conflicting-outputs` — generates freezed + json_serializable code (run from `client/packages/pocketcoder_flutter`)
