#!/usr/bin/env python3
"""Prunes superseded release objects from the image-relay R2 bucket.

Keeps two things, unioned:
  1. Everything currently referenced by any live channel pointer
     (v1/channels/{stable,beta,nightly,nightly-testing}.json), regardless
     of age -- this is the correctness guarantee, a box updating to
     whatever a channel currently points at must never 404.
  2. Everything uploaded within RETENTION_DAYS, regardless of whether it's
     referenced -- rollback/crash-recovery headroom for a box that's
     already running an older, no-longer-promoted release, plus a buffer
     for candidate builds that haven't been promoted (yet, or ever).

Only ever touches keys under PRUNE_PREFIXES. channels/, attestations/
channels/, and revocations/ are never candidates for deletion -- those are
the pointers themselves and their audit trail, not superseded content.

Usage:
  prune_r2_releases.py            # dry run, prints what would be deleted
  prune_r2_releases.py --execute  # actually deletes
"""
import datetime
import json
import os
import sys
import urllib.error
import urllib.request

BUCKET = "pocketcoder-images"
RELAY_BASE = "https://images.relay.pocketcoder.org/v1"
CHANNELS = ("stable", "beta", "nightly", "nightly-testing")
RETENTION_DAYS = 90

# Objects under these prefixes are candidates for pruning if they're
# neither live-referenced nor within the retention window.
PRUNE_PREFIXES = ("releases/", "attestations/releases/", "documents/", "artifacts/")

# Never candidates for deletion, regardless of age or references: the
# channel pointers themselves, their promotion attestation history, and
# the revocations list.
NEVER_PRUNE_PREFIXES = ("channels/", "attestations/channels/", "revocations/")


def sha256s_referenced(node):
    """Walks an arbitrary JSON structure, collecting every value found
    under a "sha256" key. Generic on purpose -- correct as long as every
    content-addressed reference in the release-manifest schema uses that
    key name, without needing to know each field's specific path."""
    found = set()

    def walk(n):
        if isinstance(n, dict):
            v = n.get("sha256")
            if isinstance(v, str):
                found.add(v)
            for value in n.values():
                walk(value)
        elif isinstance(n, list):
            for item in n:
                walk(item)

    walk(node)
    return found


def compute_prune_plan(listing, live_keep_hashes, retention_days, now):
    """listing: iterable of (last_modified: datetime, size: int, key: str).
    Returns (keep_keys, delete_keys), both lists of key strings.

    Pure function, no network/boto3 -- this is what unit tests exercise.
    """
    keep = []
    delete = []
    cutoff = now - datetime.timedelta(days=retention_days)

    for last_modified, _size, key in listing:
        if key.startswith(NEVER_PRUNE_PREFIXES):
            keep.append(key)
            continue
        if not key.startswith(PRUNE_PREFIXES):
            # Unknown prefix -- leave it alone rather than guess.
            keep.append(key)
            continue

        basename = key.rsplit("/", 1)[-1]
        content_hash = basename.split(".", 1)[0]

        if content_hash in live_keep_hashes:
            keep.append(key)
            continue
        if last_modified >= cutoff:
            keep.append(key)
            continue
        delete.append(key)

    return keep, delete


def _fetch_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": "pocketcoder-r2-prune-script"})
    with urllib.request.urlopen(req) as r:
        return json.load(r)


def fetch_live_keep_hashes(channels=CHANNELS, relay_base=RELAY_BASE):
    """Fetches each channel pointer (skipping any that 404, i.e. never
    promoted) and every release manifest it points at, returning the full
    set of sha256 hashes those manifests reference -- including the
    release digests themselves."""
    keep_hashes = set()
    for channel in channels:
        try:
            pointer = _fetch_json(f"{relay_base}/channels/{channel}.json")
        except urllib.error.HTTPError as e:
            if e.code == 404:
                continue
            raise
        digest = pointer.get("manifest", {}).get("sha256")
        if not digest:
            continue
        keep_hashes.add(digest)
        manifest = _fetch_json(f"{relay_base}/releases/{digest}.json")
        keep_hashes |= sha256s_referenced(manifest)
    return keep_hashes


def list_bucket(s3, bucket=BUCKET):
    paginator = s3.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=bucket):
        for obj in page.get("Contents", []):
            yield obj["LastModified"], obj["Size"], obj["Key"]


def delete_keys(s3, keys, bucket=BUCKET):
    for i in range(0, len(keys), 1000):
        batch = keys[i : i + 1000]
        resp = s3.delete_objects(
            Bucket=bucket,
            Delete={"Objects": [{"Key": k} for k in batch], "Quiet": False},
        )
        for deleted in resp.get("Deleted", []):
            print(f"deleted\t{deleted['Key']}")
        for err in resp.get("Errors", []):
            print(f"FAILED\t{err['Key']}\t{err.get('Message', '')}", file=sys.stderr)


def main():
    import boto3

    live_keep_hashes = fetch_live_keep_hashes()
    print(f"# {len(live_keep_hashes)} live-referenced sha256 hashes", file=sys.stderr)

    s3 = boto3.client(
        "s3",
        endpoint_url=f"https://{os.environ['CLOUDFLARE_ACCOUNT_ID']}.r2.cloudflarestorage.com",
        aws_access_key_id=os.environ["R2_ACCESS_KEY_ID"],
        aws_secret_access_key=os.environ["R2_SECRET_ACCESS_KEY"],
        region_name="auto",
    )

    now = datetime.datetime.now(datetime.timezone.utc)
    _keep, to_delete = compute_prune_plan(
        list_bucket(s3), live_keep_hashes, RETENTION_DAYS, now
    )

    print(f"# {len(to_delete)} object(s) to delete", file=sys.stderr)

    if "--execute" not in sys.argv:
        print("# DRY RUN -- keys that would be deleted:", file=sys.stderr)
        for k in to_delete:
            print(k)
        return

    delete_keys(s3, to_delete)
    print(f"# done: {len(to_delete)} object(s) targeted", file=sys.stderr)


if __name__ == "__main__":
    main()
