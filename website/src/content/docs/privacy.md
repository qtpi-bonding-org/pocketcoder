---
title: Privacy
description: PocketCoder's hosted data flows and privacy inventory.
head: []
---

PocketCoder documents hosted data flows below. Legal prose outside generated sections is maintained manually.

<!-- BEGIN GENERATED DATA INVENTORY -->

### Hosted data inventory

| Record | Categories | Storage | Retention | Deletion |
|---|---|---|---|---|
| `hosted_push_request` | account_identifier, authentication_credential, conversation_identifier, device_identifier, notification_content, notification_metadata, service_metadata | `transient_worker_memory` | `request_lifetime` | discarded_after_delivery_or_error |
| `relay_binding` | account_identifier, activity_metadata, pseudonymous_identifier | `supabase.relay_bindings` | `until_user_unbinds_or_90_days_inactive` | delete_on_unbind_or_account_deletion |
| `push_quota` | account_identifier, operational_metadata | `supabase.push_quota` | `30_days` | purge_after_retention |
| `oauth_state` | provider_selection, pseudonymous_identifier | `redirect_query_and_worker_memory` | `request_lifetime` | discarded_after_callback |
| `oauth_exchange_record` | authorization_metadata, credential_metadata, oauth_credential, pseudonymous_identifier | `cloudflare_kv.exchange` | `60_seconds` | delete_on_claim_mismatch_or_expiration |
| `oauth_callback_request` | oauth_credential, provider_error, pseudonymous_identifier | `transient_worker_memory` | `request_lifetime` | discarded_after_callback |
| `oauth_provider_config` | provider_configuration | `Cloudflare_worker_secrets_and_code` | `until_configuration_rotation` | secret_rotation_or_worker_removal |
| `oauth_claim_request` | pseudonymous_identifier | `transient_worker_memory` | `request_lifetime` | discarded_after_request |
| `oauth_refresh_request` | oauth_credential, provider_selection | `transient_worker_memory` | `request_lifetime` | discarded_after_provider_response |
| `subscription_entitlement_check` | account_identifier, subscription_status | `cloudflare_cache` | `5_minutes` | cache_expiration |
| `image_release_object_request` | none | `cloudflare_r2` | `until_release_or_artifact_purge` | release_pipeline_controlled_deletion |
| `customer_owned_pocketbase_boundary` | customer_defined | `customer_owned_pocketbase` | `customer_configured` | customer_controlled |

Declared personal-data categories: `account_identifier`, `activity_metadata`, `authentication_credential`, `authorization_metadata`, `conversation_identifier`, `credential_metadata`, `customer_defined`, `device_identifier`, `notification_content`, `notification_metadata`, `oauth_credential`, `operational_metadata`, `provider_configuration`, `provider_error`, `provider_selection`, `pseudonymous_identifier`, `service_metadata`, `subscription_status`.

<!-- END GENERATED DATA INVENTORY -->

<!-- BEGIN GENERATED DATA DESTINATIONS -->

### Subprocessors and data destinations

| Provider | Services | Role | Contract data |
|---|---|---|---|
| `cloudflare` | Workers, KV, R2 | hosting_and_edge_storage | `oauth_state`, `oauth_exchange_record`, `image_release_object_request` |
| `supabase` | Postgres | push_binding_storage_and_quota | `relay_binding`, `push_quota` |
| `firebase` | FCM | push_delivery | `hosted_push_request` |
| `revenuecat` | subscription_entitlement_api | expected_subscription_verification | `subscription_entitlement_check` |
| `github` | OAuth | oauth_provider | `oauth_state`, `oauth_exchange_record`, `oauth_refresh_request` |
| `linode` | OAuth | oauth_provider | `oauth_state`, `oauth_exchange_record`, `oauth_refresh_request` |

<!-- END GENERATED DATA DESTINATIONS -->
