#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/../"

export AWS_ACCESS_KEY_ID=$(terraform output -json | jq ".sklein_backup_bucket_admin_api_key_id.value" -r)
export AWS_SECRET_ACCESS_KEY=$(terraform output -json | jq ".sklein_backup_bucket_admin_api_app_key.value" -r)
export AWS_ENDPOINT_URL=https://s3.eu-central-003.backblazeb2.com
export AWS_DEFAULT_REGION=eu-central-003

aws s3api --no-cli-pager list-object-versions --bucket sklein-backup-bucket-write-once-read-many | jq -r '.Versions[]? | .Key + " " + .VersionId' | while read key version; do
    aws s3api put-object-legal-hold \
        --bucket sklein-backup-bucket-write-once-read-many \
        --key "$key" \
        --version-id "$version" \
        --legal-hold Status=OFF
done

aws --no-cli-pager s3api list-objects-v2 --bucket sklein-backup-bucket-write-once-read-many  --query "Contents[].{Key:Key}" --output text | while read object_key; do
    echo "Removing lock for: $object_key"

    aws s3api put-object-retention \
        --bucket sklein-backup-bucket-write-once-read-many \
        --key "$object_key" \
        --retention "{\"Mode\":\"GOVERNANCE\", \"RetainUntilDate\": \"$(date -u -d 'tomorrow' '+%Y-%m-%dT00:00:00.000Z')\"}" \
        --bypass-governance-retention

    aws --no-cli-pager s3api put-object-legal-hold \
        --bucket sklein-backup-bucket-write-once-read-many \
        --key "$object_key" \
        --legal-hold Status=OFF
done

cat <<EOF
The retention date has been set to tomorrow $(date -u -d 'tomorrow' '+%Y-%m-%dT00:00:00.000Z'), which is the shortest duration accepted by Scaleway Object Storage.
You will be able to delete this bucket only in 24h.
EOF
