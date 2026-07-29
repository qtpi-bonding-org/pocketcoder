import os
import sys

import boto3
from botocore.exceptions import ClientError

account_id = os.environ["CLOUDFLARE_ACCOUNT_ID"]
access_key = os.environ["R2_ACCESS_KEY_ID"]
secret_key = os.environ["R2_SECRET_ACCESS_KEY"]

s3 = boto3.client(
    "s3",
    endpoint_url=f"https://{account_id}.r2.cloudflarestorage.com",
    aws_access_key_id=access_key,
    aws_secret_access_key=secret_key,
    region_name="auto",
)

try:
    resp = s3.list_objects_v2(Bucket="pocketcoder-images")
    print("OK: credentials work. Objects in pocketcoder-images:")
    for obj in resp.get("Contents", []):
        print(f"  {obj['Key']}  ({obj['Size']} bytes)")
    if "Contents" not in resp:
        print("  (bucket is empty)")
except ClientError as e:
    print(f"FAILED: {e}", file=sys.stderr)
    sys.exit(1)
