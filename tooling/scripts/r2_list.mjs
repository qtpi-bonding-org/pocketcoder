#!/usr/bin/env node
// Lists objects in an R2 bucket via R2's S3-compatible API, signed with
// AWS SigV4 by hand using only Node's built-in crypto/https -- no aws-cli,
// no boto3, no npm install. Reads R2_ENDPOINT, AWS_ACCESS_KEY_ID,
// AWS_SECRET_ACCESS_KEY from the environment (injected by the
// secrets-daemon via `sops exec-env` -- never read from a file here).
//
// Usage: node r2_list.mjs <bucket> [prefix] [--recursive]
//
// Without --recursive, uses delimiter=/ so nested "folders" (artifacts/,
// channels/, etc.) collapse to a single CommonPrefixes entry each,
// matching the Cloudflare dashboard's default root view.

import { createHmac, createHash } from 'node:crypto';
import { request } from 'node:https';
import { URL } from 'node:url';

const [, , bucket, ...rest] = process.argv;
if (!bucket) {
  console.error('usage: node r2_list.mjs <bucket> [prefix] [--recursive]');
  process.exit(64);
}
const recursive = rest.includes('--recursive');
const prefix = rest.find((a) => a !== '--recursive') ?? '';

const endpoint = process.env.R2_ENDPOINT;
const accessKeyId = process.env.AWS_ACCESS_KEY_ID;
const secretAccessKey = process.env.AWS_SECRET_ACCESS_KEY;
const region = 'auto';
const service = 's3';

if (!endpoint || !accessKeyId || !secretAccessKey) {
  console.error('R2_ENDPOINT, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY must be set');
  process.exit(64);
}

function hmac(key, data) {
  return createHmac('sha256', key).update(data, 'utf8').digest();
}
function sha256hex(data) {
  return createHash('sha256').update(data, 'utf8').digest('hex');
}

function signedGet(pathAndQuery) {
  const url = new URL(endpoint);
  const host = url.hostname;
  const now = new Date();
  const amzDate = now.toISOString().replace(/[:-]|\.\d{3}/g, '');
  const dateStamp = amzDate.slice(0, 8);

  const [canonicalPath, rawQuery = ''] = pathAndQuery.split('?');
  const canonicalQuery = rawQuery
    .split('&')
    .filter(Boolean)
    .map((kv) => kv.split('='))
    .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
    .map(([k, v]) => `${k}=${v ?? ''}`)
    .join('&');

  const payloadHash = sha256hex('');
  const canonicalHeaders = `host:${host}\nx-amz-content-sha256:${payloadHash}\nx-amz-date:${amzDate}\n`;
  const signedHeaders = 'host;x-amz-content-sha256;x-amz-date';
  const canonicalRequest = [
    'GET',
    canonicalPath,
    canonicalQuery,
    canonicalHeaders,
    signedHeaders,
    payloadHash,
  ].join('\n');

  const credentialScope = `${dateStamp}/${region}/${service}/aws4_request`;
  const stringToSign = [
    'AWS4-HMAC-SHA256',
    amzDate,
    credentialScope,
    sha256hex(canonicalRequest),
  ].join('\n');

  const kDate = hmac(`AWS4${secretAccessKey}`, dateStamp);
  const kRegion = hmac(kDate, region);
  const kService = hmac(kRegion, service);
  const kSigning = hmac(kService, 'aws4_request');
  const signature = createHmac('sha256', kSigning).update(stringToSign, 'utf8').digest('hex');

  const authorization = `AWS4-HMAC-SHA256 Credential=${accessKeyId}/${credentialScope}, SignedHeaders=${signedHeaders}, Signature=${signature}`;

  return new Promise((resolve, reject) => {
    const req = request(
      {
        hostname: host,
        path: canonicalPath + (canonicalQuery ? `?${canonicalQuery}` : ''),
        method: 'GET',
        headers: {
          host,
          'x-amz-content-sha256': payloadHash,
          'x-amz-date': amzDate,
          authorization,
        },
      },
      (res) => {
        let body = '';
        res.on('data', (chunk) => (body += chunk));
        res.on('end', () => {
          if (res.statusCode !== 200) {
            reject(new Error(`R2 list failed: HTTP ${res.statusCode}\n${body}`));
          } else {
            resolve(body);
          }
        });
      },
    );
    req.on('error', reject);
    req.end();
  });
}

function extractAll(xml, tag) {
  const re = new RegExp(`<${tag}>([\\s\\S]*?)</${tag}>`, 'g');
  const out = [];
  let m;
  while ((m = re.exec(xml))) out.push(m[1]);
  return out;
}

async function listAll() {
  let continuationToken = '';
  const keys = [];
  const prefixes = new Set();
  do {
    const params = new URLSearchParams({ 'list-type': '2', 'max-keys': '1000' });
    if (prefix) params.set('prefix', prefix);
    if (!recursive) params.set('delimiter', '/');
    if (continuationToken) params.set('continuation-token', continuationToken);

    const xml = await signedGet(`/${bucket}?${params.toString()}`);

    for (const contentsBlock of extractAll(xml, 'Contents')) {
      const [key] = extractAll(contentsBlock, 'Key');
      const [size] = extractAll(contentsBlock, 'Size');
      const [modified] = extractAll(contentsBlock, 'LastModified');
      keys.push({ key, size, modified });
    }
    for (const p of extractAll(xml, 'Prefix')) {
      if (p !== prefix) prefixes.add(p);
    }
    const [isTruncated] = extractAll(xml, 'IsTruncated');
    const [nextToken] = extractAll(xml, 'NextContinuationToken');
    continuationToken = isTruncated === 'true' ? nextToken : '';
  } while (continuationToken);

  for (const p of [...prefixes].sort()) {
    console.log(`DIR  ${p}`);
  }
  for (const { key, size, modified } of keys) {
    console.log(`OBJ  ${size}\t${modified}\t${key}`);
  }
  console.error(`\n${keys.length} object(s), ${prefixes.size} folder(s)`);
}

listAll().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
