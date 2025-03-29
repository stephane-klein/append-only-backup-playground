#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/../"

export AWS_ACCESS_KEY_ID=${SCW_ACCESS_KEY}
export AWS_SECRET_ACCESS_KEY=${SCW_SECRET_KEY}
export AWS_ENDPOINT_URL=https://s3.fr-par.scw.cloud
export AWS_DEFAULT_REGION=fr-par

aws s3api --no-cli-pager list-object-versions --bucket sklein-backup-bucket-write-once-read-many | jq -r '.Versions[]? | .Key + " " + .VersionId' | while read key version; do
  aws s3api --no-cli-pager delete-object --bucket sklein-backup-bucket-write-once-read-many --key "$key" --version-id "$version"
done
