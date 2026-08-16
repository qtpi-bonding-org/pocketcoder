// GENERATED FILE. Do not edit; run npm run contracts:generate.

export interface HostedPushRequest {
  relay_secret: string;
  user_id: string;
  token: string;
  service: string;
  title?: string;
  message?: string;
  type?: string;
  chat?: string;
}

export interface RelayBinding {
  secret_hash: string;
  user_id: string;
  bound_at: string;
}

export interface PushQuota {
  user_id: string;
  day: string;
  count: number;
}

export interface OauthState {
  provider: string;
  code_challenge: string;
  state: string;
}

export interface OauthExchangeRecord {
  exchange_code: string;
  code_challenge: string;
  access_token: string;
  refresh_token?: string;
  expires_in?: number | null;
  scope?: string | null;
}

export interface OauthCallbackRequest {
  code: string;
  state: string;
  error?: string;
}

export interface OauthClaimRequest {
  exchange_code: string;
  code_verifier: string;
}

export interface OauthRefreshRequest {
  provider: string;
  refresh_token: string;
}

export interface SubscriptionEntitlementCheck {
  user_id: string;
  is_premium: boolean;
}

export interface ImageReleaseObjectRequest {
  object_path: string;
  content_type: string;
}
