#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/../"

export AWS_ACCESS_KEY_ID=${SCW_ACCESS_KEY}
export AWS_SECRET_ACCESS_KEY=${SCW_SECRET_KEY}
export AWS_ENDPOINT_URL=https://s3.fr-par.scw.cloud
export AWS_DEFAULT_REGION=fr-par

aws --no-cli-pager $@
