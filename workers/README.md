# workers/

Cloudflare Workers are the **only infrastructure PocketCoder runs
centrally**. Everything else (PocketBase, goose, mcp-gateway, the NixOS
box itself) belongs to one user's own deployment — see the root
`CLAUDE.md`'s "Deployment Model" section. A Worker only exists here when
a feature genuinely needs one stable, publicly-reachable endpoint shared
by every self-hosted deployment (an OAuth callback, a release/image
distribution point, anything requiring a secret no user's box should
hold).

**Deploys are manual.** Workers do **not** auto-deploy on `git push` —
a code change here isn't live until someone runs `npx wrangler deploy`
from the worker's own directory (see "Updating everything" below).
This has bitten a live debugging session before (a routing-regex fix
that was committed but not live) — always check "was it actually
deployed," not just "was it merged," when a Worker seems to be
misbehaving.

## Workers

| Worker | Purpose | Docs |
|---|---|---|
| `image-relay` | Publishes the release-distribution API every box (fresh or already-running) reads from — channel pointers, release manifests, and the raw NixOS boot image, all from one digest-addressed, attested pipeline. Backs `images.relay.pocketcoder.org` and `images.pocketcoder.org`. | [image-relay/README.md](image-relay/README.md) |
| `oauth-relay` | Holds centrally-registered OAuth app credentials (GitHub, Linode, ...) so a per-user VPS never has to hold a client secret; brokers the code exchange and hands the finished token to the user's own deployment. | — |

`push-relay` is not part of this repo — this directory only documents
the Workers that actually live here.

## Updating everything

Each Worker deploys independently; none of this needs to happen in a
particular order relative to the others.

**Any Worker in this repo (image-relay, oauth-relay):**
```sh
cd workers/<name>
npx wrangler deploy
```
Requires Cloudflare API credentials in the environment
(`CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ACCOUNT_ID`, or an authenticated
`wrangler login` session) — however you normally supply those locally.

**image-relay's upstream pipelines** (see
`image-relay/README.md` for the full picture) are separate from
deploying the Worker itself:
- Build a new NixOS candidate image:
  `deploy/nixos/scripts/trigger-ci-build.sh [--attest-branch]`
  (needs `GH_TOKEN` with `actions:write` on the repo; must be run from
  a checked-out `main` or `staging` branch).
- Promote the latest successful candidate to a channel:
  `deploy/nixos/scripts/promote-latest-candidate.sh <stable|beta|nightly>`
  (same `GH_TOKEN` requirement).
- Both just dispatch GitHub Actions workflows
  (`nixos-image.yml`, `release-promotion.yml`) — no wrangler/R2
  credentials needed locally for these two.
