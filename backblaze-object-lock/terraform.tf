terraform {
    required_providers {
        b2 = {
            source = "Backblaze/b2"
            version = "0.10.0" # See last version on this url https://github.com/Backblaze/terraform-provider-b2 
        }
    }
}

provider "b2" {
    endpoint = "production"
}

resource "b2_bucket" "sklein_backup_bucket_write_once_read_many" {
    bucket_name = "sklein-backup-bucket-write-once-read-many"
    bucket_type = "allPrivate"
    file_lock_configuration {
        is_file_lock_enabled = true
        default_retention {
            mode = "governance"
            period {
                duration = 1
                unit     = "days"
            }
        }
    }
}

resource "b2_application_key" "sklein_backup_bucket_admin_api_key" {
    key_name = "sklein-backup-bucket-admin-api-key"
    capabilities = [ # See complete list: https://www.backblaze.com/docs/cloud-storage-application-key-capabilities
        "listBuckets",
        "listAllBucketNames",
        "readBuckets",
        "writeBuckets",
        "readBucketRetentions",
        "writeBucketRetentions",
        "readBucketEncryption",
        "writeBucketEncryption",
        "listFiles",
        "readFiles",
        "writeFiles",
        "deleteFiles",
        "readFileLegalHolds",
        "writeFileLegalHolds",
        "readFileRetentions",
        "writeFileRetentions",
        "bypassGovernance"
    ]
    bucket_id = b2_bucket.sklein_backup_bucket_write_once_read_many.id
}

output "sklein_backup_bucket_admin_api_key_id" {
    value = b2_application_key.sklein_backup_bucket_admin_api_key.application_key_id
}

output "sklein_backup_bucket_admin_api_app_key" {
    value = b2_application_key.sklein_backup_bucket_admin_api_key.application_key
    sensitive = true
}

resource "b2_application_key" "sklein_backup_bucket_write_once_read_many_api_key" {
    key_name = "sklein-backup-bucket-write-once-read-many-api-key"
    capabilities = [ # deleteFiles is intentionally not included in this list
        "listBuckets",
        "readFiles",
        "writeFiles",
        "listFiles"
    ]
    bucket_id = b2_bucket.sklein_backup_bucket_write_once_read_many.id
}

output "sklein_backup_bucket_write_once_read_many_api_key_id" {
    value = b2_application_key.sklein_backup_bucket_write_once_read_many_api_key.application_key_id
}

output "sklein_backup_bucket_write_once_read_many_api_app_key" {
    value = b2_application_key.sklein_backup_bucket_write_once_read_many_api_key.application_key
    sensitive = true
}
