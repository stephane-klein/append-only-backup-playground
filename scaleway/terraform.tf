terraform {
    required_providers {
        scaleway = {
            source = "scaleway/scaleway"
            version = "2.51.0" # See last version on this url https://github.com/scaleway/terraform-provider-scaleway/releases
        }
    }
}

variable "append_only_backup_playground_project_id" {
    type    = string
    default = "52cde9ea-6ddd-4ca0-8339-241a62a43f39"
}

variable "append_only_backup_playground_app_id" {
    type    = string
    default = "8bcbcf3b-8023-4966-8601-4d42410e14ca"
}

variable "stephane_klein_user_id" {
    type    = string
    default = "7cad760e-3bb9-4f20-9c1b-638b9395d1e2"
}

provider "scaleway" {
    zone   = "fr-par-1"
    region = "fr-par"
}

resource "scaleway_iam_application" "sklein_backup_bucket_write_once_read_many_app" {
    name = "sklein_backup_bucket_write_once_read_many_app"
}

resource "scaleway_iam_policy" "sklein_backup_bucket_write_once_read_many_app_policy" {
    name = "sklein_backup_bucket_write_once_read_many_app_policy"
    application_id = scaleway_iam_application.sklein_backup_bucket_write_once_read_many_app.id
    rule {
        project_ids = [var.append_only_backup_playground_project_id]
        permission_set_names = [
            "ObjectStorageBucketsRead",
            "ObjectStorageObjectsRead"
        ]
    }
}

resource "scaleway_iam_api_key" "sklein_backup_bucket_write_once_read_many_api_key" {
    application_id     = scaleway_iam_application.sklein_backup_bucket_write_once_read_many_app.id
    default_project_id = var.append_only_backup_playground_project_id
}

output "sklein_backup_bucket_write_once_read_many_api_access_key" {
    value = scaleway_iam_api_key.sklein_backup_bucket_write_once_read_many_api_key.access_key
}

output "sklein_backup_bucket_write_once_read_many_api_secret_key" {
    value = scaleway_iam_api_key.sklein_backup_bucket_write_once_read_many_api_key.secret_key
    sensitive = true
}

resource "scaleway_object_bucket" "sklein_backup_bucket_write_once_read_many" {
    name = "sklein-backup-bucket-write-once-read-many"
    project_id  = var.append_only_backup_playground_project_id
    versioning {
        enabled = true
    }
    force_destroy = true 
}

resource "scaleway_object_bucket_acl" "sklein_backup_bucket_write_once_read_many_acl" {
    bucket = scaleway_object_bucket.sklein_backup_bucket_write_once_read_many.id
    acl = "private"
}

# See the list of actions in the documentation https://www.scaleway.com/en/docs/object-storage/api-cli/bucket-policy/#action
resource "scaleway_object_bucket_policy" "sklein_backup_bucket_write_once_read_many_policy" {
    bucket = scaleway_object_bucket.sklein_backup_bucket_write_once_read_many.id
    policy = jsonencode(
        {
            Version = "2023-04-17",
            Statement = [
                {
                    Sid    = "Delegate full access to append-only-backup-playground application",
                    Effect = "Allow",
                    Principal = {
                        SCW: [
                            "application_id:${var.append_only_backup_playground_app_id}",
                            "user_id:${var.stephane_klein_user_id}"

                        ]
                    },
                    Action = [
                        "s3:*",
                    ]
                    Resource = [
                        "${scaleway_object_bucket.sklein_backup_bucket_write_once_read_many.name}",
                        "${scaleway_object_bucket.sklein_backup_bucket_write_once_read_many.name}/*"
                    ]
                },
                {
                    Sid    = "Delegate read and write access to sklein_backup_bucket_write_once_read_many_app application",
                    Effect = "Allow",
                    Principal = {
                        SCW = ["application_id:${scaleway_iam_application.sklein_backup_bucket_write_once_read_many_app.id}"]
                    },
                    Action = [
                        "s3:ListBucket",
                        "s3:ListBucketMultipartUploads",
                        "s3:ListBucketVersions",

                        "s3:GetObject",
                        "s3:GetBucketAcl",
                        "s3:GetBucketCORS",
                        "s3:GetBucketLocation",
                        "s3:GetBucketObjectLockConfiguration",
                        "s3:GetBucketTagging",
                        "s3:GetBucketVersioning",
                        "s3:GetBucketWebsite",
                        "s3:GetLifecycleConfiguration",

                        "s3:AbortMultipartUpload",
                        "s3:GetObject",
                        "s3:GetObjectAcl",
                        "s3:GetObjectLegalHold",
                        "s3:GetObjectRetention",
                        "s3:GetObjectTagging",
                        "s3:GetObjectVersion",
                        "s3:GetObjectVersionTagging",
                        "s3:ListMultipartUploadParts",
                        "s3:PutObject"

                    ]
                    Resource = [
                        "${scaleway_object_bucket.sklein_backup_bucket_write_once_read_many.name}",
                        "${scaleway_object_bucket.sklein_backup_bucket_write_once_read_many.name}/*"
                    ]
                }
            ]
        }
    )
}
