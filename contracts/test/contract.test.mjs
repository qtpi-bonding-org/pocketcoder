import test from 'node:test';
import assert from 'node:assert/strict';
import { redactForLog, validateRecord } from '../generated/validators.js';

test('valid hosted push request', () => {
  assert.deepEqual(validateRecord('hosted_push_request', { relay_secret: 's', token: 'fcm-token', user_id: 'u1', service: 'fcm', title: 'Hi' }).service, 'fcm');
});

test('missing required push fields fails', () => {
  assert.throws(() => validateRecord('hosted_push_request', { relay_secret: 's', user_id: 'u1', service: 'fcm' }), /token is required/);
});

test('invalid push service fails', () => {
  assert.throws(() => validateRecord('hosted_push_request', { relay_secret: 's', token: 't', user_id: 'u1', service: 'ntfy' }), /invalid value/);
});

test('OAuth exchange records declare expiration by contract', () => {
  assert.equal(validateRecord('oauth_exchange_record', { exchange_code: 'e', code_challenge: 'c', access_token: 'a', expires_in: 60 }).expires_in, 60);
});

test('OAuth claim and refresh payloads validate', () => {
  assert.doesNotThrow(() => validateRecord('oauth_claim_request', { exchange_code: 'e', code_verifier: 'v' }));
  assert.doesNotThrow(() => validateRecord('oauth_refresh_request', { provider: 'github', refresh_token: 'r' }));
});

test('secret values are redacted from logs', () => {
  const redacted = redactForLog('oauth_refresh_request', { provider: 'github', refresh_token: 'secret' });
  assert.equal(redacted.refresh_token, '[REDACTED]');
});
