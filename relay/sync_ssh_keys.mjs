#!/usr/bin/env node

/**
 * SSH Key Sync Service
 * Uses PocketBase realtime subscriptions (SSE) to sync SSH keys in real-time
 * when they are created, updated, or deleted.
 */

import { writeFileSync, mkdirSync } from 'fs';
import { dirname } from 'path';
import PocketBase from 'pocketbase';
import { EventSource } from 'eventsource';

// Polyfill EventSource for Node.js
global.EventSource = EventSource;

const POCKETBASE_URL = process.env.POCKETBASE_URL || 'http://pocketbase:8090';
const SSH_KEYS_FILE = process.env.SSH_KEYS_FILE || '/ssh_keys/authorized_keys';
const ADMIN_EMAIL = process.env.POCKETBASE_SUPERUSER_EMAIL || 'admin@pocketcoder.local';
const ADMIN_PASSWORD = process.env.POCKETBASE_SUPERUSER_PASSWORD || 'admin';

const pb = new PocketBase(POCKETBASE_URL);

async function fetchAndWriteKeys() {
  try {
    console.log('🔄 [SSH Sync] Fetching SSH keys from PocketBase...');

    const response = await fetch(`${POCKETBASE_URL}/api/pocketcoder/ssh_keys`);

    if (!response.ok) {
      console.error(`❌ [SSH Sync] Failed to fetch keys: ${response.status} ${response.statusText}`);
      return false;
    }

    const keys = await response.text();

    if (keys.trim() === '') {
      console.log('📝 [SSH Sync] No active keys found, clearing authorized_keys');
    } else {
      const keyCount = keys.trim().split('\n').length;
      console.log(`📝 [SSH Sync] Found ${keyCount} active key(s)`);
    }

    // Ensure directory exists
    mkdirSync(dirname(SSH_KEYS_FILE), { recursive: true });

    // Write keys to file
    writeFileSync(SSH_KEYS_FILE, keys, { mode: 0o600 });

    console.log(`✅ [SSH Sync] Successfully updated ${SSH_KEYS_FILE}`);
    return true;
  } catch (error) {
    console.error(`❌ [SSH Sync] Error:`, error.message);
    return false;
  }
}

async function main() {
  console.log('🚀 [SSH Sync] Starting SSH key sync service with realtime updates...');
  console.log(`   PocketBase URL: ${POCKETBASE_URL}`);
  console.log(`   Keys file: ${SSH_KEYS_FILE}`);

  // Authenticate with PocketBase as admin (needed to see all SSH keys)
  try {
    await pb.collection('_superusers').authWithPassword(ADMIN_EMAIL, ADMIN_PASSWORD);
    console.log('✅ [SSH Sync] Authenticated with PocketBase as admin');
  } catch (error) {
    console.error('❌ [SSH Sync] Failed to authenticate:', error.message);
    console.log('📝 [SSH Sync] Falling back to polling mode (every 30 seconds)...');
    await fetchAndWriteKeys();
    setInterval(fetchAndWriteKeys, 30000);
    return;
  }

  // Initial sync
  await fetchAndWriteKeys();

  // Subscribe to realtime changes on ssh_keys collection
  console.log('👂 [SSH Sync] Subscribing to ssh_keys collection changes...');

  pb.collection('ssh_keys').subscribe('*', async (e) => {
    console.log(`🔔 [SSH Sync] Received ${e.action} event for record ${e.record.id}`);

    // Re-fetch and write all keys whenever any key changes
    await fetchAndWriteKeys();
  });

  console.log('✅ [SSH Sync] Realtime subscription active');

  // Keep the process alive
  process.on('SIGTERM', () => {
    console.log('👋 [SSH Sync] Shutting down...');
    try {
      pb.collection('ssh_keys').unsubscribe();
    } catch (e) {
      // Ignore errors during shutdown
    }
    process.exit(0);
  });
}

main().catch(error => {
  console.error('❌ [SSH Sync] Fatal error:', error);
  process.exit(1);
});
