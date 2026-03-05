# Deploy Button — Task List

Last updated: 2026-03-05

## Status Summary

| Mode | Status | Notes |
|------|--------|-------|
| **Elestio** | Code complete | Needs catalog listing (business task) |
| **Linode** | ~90% | Code complete, needs infra setup + e2e test |
| **Hetzner** | Not started | Lowest priority, same NixOS image works |

---

## Elestio (fully managed)

- [x] `elestio.yml` manifest
- [x] `scripts/elestio/` lifecycle hooks (postInstall, preBackup, postRestore)
- [ ] Contact Elestio for catalog listing + revenue share agreement
- [ ] Verify deploy flow end-to-end on Elestio platform

## Linode (one-tap OAuth)

### Server (NixOS) — done

- [x] `deploy/nixos/configuration.nix` — Docker, firewall, SSH, GRUB, LISH
- [x] `deploy/nixos/caddy.nix` — detect-public-ip + sslip.io Caddyfile
- [x] `deploy/nixos/bootstrap.nix` — first-boot: metadata → .env → clone → compose up
- [x] `deploy/nixos/flake.nix` — nixos-generators raw image build

### Flutter (deploy flow) — done

- [x] ConfigScreen, ProgressScreen, DetailsScreen UI
- [x] ConfigCubit + DeploymentCubit (polling, monitoring)
- [x] LinodeAPIClient (create/get/list instances, plans, regions)
- [x] LinodeOAuthService (PKCE flow, token refresh)
- [x] SecureStorage, CertificateManager, PasswordGenerator, ValidationService

### Image pipeline — code done, needs infra

- [x] CI workflow: `.github/workflows/nixos-image.yml` — `nix build`, gzip, upload to R2, GitHub Release on tag
- [x] Publish `.img.gz` to GitHub Releases (tag-triggered in workflow)
- [ ] Create R2 bucket `pocketcoder-images` (Wrangler dashboard or `wrangler r2 bucket create`)
- [ ] Trigger first build via `workflow_dispatch` to populate R2
- [ ] Verify image boots on Linode (manual test, one-time)

### Image upload flow — code done, needs deploy

- [x] CF Worker relay: `deploy/image-relay-worker/` — streams image from R2 to Linode Images API
- [x] `LinodeAPIClient.findImageByLabel()` — check if NixOS image exists in user's account
- [x] `LinodeAPIClient.triggerImageUpload()` — POST to CF Worker to initiate server-to-server transfer
- [x] `images:read_write` added to OAuth scopes in `LinodeOAuthService`
- [ ] Deploy CF Worker: `cd deploy/image-relay-worker && wrangler deploy`
- [ ] Bind R2 bucket to worker in CF dashboard (or verify wrangler.toml binding works)

### Wire NixOS into Flutter — done

- [x] `DeploymentConfig` — replaced `cloudInitTemplateUrl` with `imageRelayUrl` + `nixosImageLabel`
- [x] `DeploymentService.deploy()` — image check → upload via relay → poll → create instance with `private/*` image
- [x] `DeploymentConfig.toUserData()` — base64-encoded env file for NixOS bootstrap
- [x] `AppConfig` — `kImageRelayUrl` + `kNixosImageLabel` (env-configurable)
- [x] `DeploymentStatus.uploadingImage` + message mapper + cubit emit
- [x] All call sites updated (config_screen, injection, external_module)
- [x] All tests updated for new metadata format and image flow
- [x] Aeroform pushed (`4ec5786`), pocketcoder pubspec updated

### End-to-end verification — not started

- [ ] Build NixOS image in CI (trigger workflow_dispatch)
- [ ] CF Worker `POST /upload-image` streams image to Linode (curl test with real token)
- [ ] CF Worker `GET /image-status` returns existing image
- [ ] Flutter deploy flow creates instance with `private/xxxxx` image
- [ ] NixOS boots, bootstrap reads user-data, starts PocketCoder stack
- [ ] Caddy auto-provisions sslip.io TLS cert

### Docs

- [ ] Update `docs/deploy-tls-design.md` with finalized NixOS approach (remove Ubuntu Option C)

## Hetzner (power users) — not started

- [ ] `HetznerAPIClient` — create/get/list instances via Hetzner Cloud API
- [ ] Hetzner auth flow UI (API token paste, not OAuth)
- [ ] Hetzner cloud-init / user-data integration (same NixOS image, different API)
- [ ] Hetzner-specific validation (plans, regions)
- [ ] Self-host guide in docs (with disclosed referral link)

## Game Console Buttons (post-deploy management)

- [ ] Restart App — trigger `docker compose down && up` via PB socket proxy endpoint
- [ ] Restart Server — `POST /v4/linode/instances/{id}/reboot` from Flutter
- [ ] Backup / Restore — Linode snapshots API + PocketBase data export
- [ ] Instance list screen (manage multiple deployments)
- [ ] Credential rotation UI

## Open Questions

1. **IAP pricing** — $2.99? $4.99? Research comparable deploy-button IAPs
2. **Let's Encrypt rate limits** — monitor sslip.io shared limit (50 certs/week/domain)
3. **NixOS auto-updates** — enable unattended upgrades with rollback? (post-launch)
4. ~~**CF Worker hosting** — where to deploy the image relay?~~ Resolved: `deploy/image-relay-worker/`, same CF account
