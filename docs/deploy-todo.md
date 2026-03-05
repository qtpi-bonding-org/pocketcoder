# Deploy Button — Task List

Last updated: 2026-03-05

## Status Summary

| Mode | Status | Notes |
|------|--------|-------|
| **Elestio** | Code complete | Needs catalog listing (business task) |
| **Linode** | ~70% | NixOS config done, image pipeline + Flutter wiring remaining |
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

### Image pipeline — not started

- [ ] CI job: `nix build .#linode-image` on Linux runner (GitHub Actions)
- [ ] Publish `.img.gz` to GitHub Releases (tag-triggered)
- [ ] Verify image boots on Linode (manual test, one-time)

### Image upload flow — not started

- [ ] Cloudflare Worker relay (server-to-server image transfer, avoids 300MB mobile download)
- [ ] `LinodeAPIClient.uploadImage()` — upload `.img.gz` to Linode custom images API
- [ ] `LinodeAPIClient.checkImageExists()` — skip upload if image already cached in user's account
- [ ] Add `images:read_write` to OAuth scopes in `LinodeOAuthService`

### Wire NixOS into Flutter — not started

- [ ] `DeploymentConfig` — replace `cloudInitTemplateUrl` with NixOS image reference
- [ ] `deployment_service.dart` line 103 — change `image: 'linode/ubuntu22.04'` → `image: 'private/{nixosImageId}'`
- [ ] Update deploy polling to account for NixOS boot time (may differ from Ubuntu)

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
4. **CF Worker hosting** — where to deploy the image relay? (existing CF account or new)
