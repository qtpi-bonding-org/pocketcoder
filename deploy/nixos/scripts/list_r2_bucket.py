import os
import sys

import boto3

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

bucket = sys.argv[1] if len(sys.argv) > 1 else "pocketcoder-images"

paginator = s3.get_paginator("list_objects_v2")
count = 0
for page in paginator.paginate(Bucket=bucket):
    for obj in page.get("Contents", []):
        print(f"{obj['LastModified'].isoformat()}\t{obj['Size']}\t{obj['Key']}")
        count += 1

print(f"# {count} object(s) in {bucket}", file=sys.stderr)
