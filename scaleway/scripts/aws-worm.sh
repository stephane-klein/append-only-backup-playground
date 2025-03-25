#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/../"

export AWS_ACCESS_KEY_ID=$(terraform output -json | jq ".sklein_backup_bucket_write_once_read_many_api_access_key.value" -r)
export AWS_SECRET_ACCESS_KEY=$(terraform output -json | jq ".sklein_backup_bucket_write_once_read_many_api_secret_key.value" -r)
export AWS_ENDPOINT_URL=https://s3.fr-par.scw.cloud
export AWS_DEFAULT_REGION=fr-par

aws $@
