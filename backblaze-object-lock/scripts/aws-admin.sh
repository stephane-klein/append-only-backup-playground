#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/../"

export AWS_ACCESS_KEY_ID=$(terraform output -json | jq ".sklein_backup_bucket_admin_api_key_id.value" -r)
export AWS_SECRET_ACCESS_KEY=$(terraform output -json | jq ".sklein_backup_bucket_admin_api_app_key.value" -r)
export AWS_ENDPOINT_URL=https://s3.eu-central-003.backblazeb2.com
export AWS_DEFAULT_REGION=eu-central-003

aws --no-cli-pager $@
