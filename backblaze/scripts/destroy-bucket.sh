#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/../"

export AWS_ACCESS_KEY_ID=$(terraform output -json | jq ".sklein_backup_bucket_admin_api_key_id.value" -r)
export AWS_SECRET_ACCESS_KEY=$(terraform output -json | jq ".sklein_backup_bucket_admin_api_app_key.value" -r)
export AWS_ENDPOINT_URL=https://s3.eu-central-003.backblazeb2.com
export AWS_DEFAULT_REGION=eu-central-003

# I have to use this technique because Backblaze doesn't support yet
# destroying non-empty buckets with Terraform: https://github.com/Backblaze/terraform-provider-b2/issues/22

aws s3api --no-cli-pager list-object-versions --bucket sklein-backup-bucket-write-once-read-many | jq -r '.Versions[]? | .Key + " " + .VersionId' | while read key version; do
  aws s3api --no-cli-pager delete-object --bucket sklein-backup-bucket-write-once-read-many --key "$key" --version-id "$version"
done
