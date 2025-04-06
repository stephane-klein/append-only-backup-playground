#!/usr/bin/env python3
import boto3
import os

session = boto3.session.Session(
    aws_access_key_id=os.environ.get("S3_ADMIN_ACCESS_KEY_ID"),
    aws_secret_access_key=os.environ.get("S3_ADMIN_SECRET_ACCESS_KEY"),
    region_name=os.environ.get("S3_ADMIN_DEFAULT_REGION")
)

s3_client = session.client(
    "s3",
    endpoint_url=os.environ.get("S3_ADMIN_ENDPOINT_URL"),
    config=boto3.session.Config(
        s3={
            "addressing_style": "path",
            "request_checksum_calculation": "when_supported"
        }
    )
)

# s3_client.put_object(
#     Body="Foobar",
#     Bucket="sklein-backup-bucket-write-once-read-many",
#     Key="test_boto3_admin.txt"
# )
s3_client.upload_file(
    Filename="README.md",
    Bucket="sklein-backup-bucket-write-once-read-many",
    Key="test_boto3_admin.txt"
)
