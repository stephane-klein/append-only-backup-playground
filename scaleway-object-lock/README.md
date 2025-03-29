# append-only Scaleway Object Storage configuration with Object Lock Governance

This `/scaleway-object-lock/` directory contains a [`terraform.tf`](./terraform.tf) file that configures a [Scaleway Object Storage](https://www.scaleway.com/fr/object-storage/) Bucket
in [**append-only**](https://notes.sklein.xyz/Write%20Once%20Read%20Many/), also called [Write Once Read Many](https://notes.sklein.xyz/Write%20Once%20Read%20Many/) mode.

This playground goes further in backup security by using the Object Lock feature in Governance mode ([link to official documentation](https://www.scaleway.com/en/docs/object-storage/api-cli/object-lock/)).  
To go even further in security, you can use `Compliance` mode instead of `Governance`. But be careful, in `Compliance` mode, it will be impossible to delete files before exceeding the retention period.

First step to prepare the playground, meaning setting up secrets and installing necessary tools with [Mise](https://mise.jdx.dev/).

```
$ cp .secret.skel .secret
```

Fill `SCW_SECRET_KEY` in `.secret` file.

```sh
$ source .envrc
$ mise install
$ terraform init
```

Create Scaleway resources with *terraform*:

```sh
$ terraform apply
```

This *terraform* configuration creates the following resources:

- an Object Storage **bucket** named `sklein-backup-bucket-write-once-read-many`
- an **api_key** named `sklein_backup_bucket_write_once_read_many_api_key` that does not have the right to delete *objects* (files) in the bucket `sklein-backup-bucket-write-once-read-many`

The `terraform output` command allows you to retrieve the `access_key` and `secret_key` values of the **api_key** `sklein_backup_bucket_write_once_read_many_api_key`:

```sh
$ terraform output -json
{
  "sklein_backup_bucket_write_once_read_many_api_access_key": {
    "sensitive": false,
    "type": "string",
    "value": "SCWKMEG7WVEAS9HVBA7Q"
  },
  "sklein_backup_bucket_write_once_read_many_api_secret_key": {
    "sensitive": true,
    "type": "string",
    "value": "..."
  }
}
```

Now, let's play a bit with the two scripts `./scripts/aws-admin.sh` and `./scripts/aws-worm.sh` (WORM means Write Once Read Many).

I start by manipulating the bucket with the administrator **api_key**, the one used by **terraform**.  
I do this with the script `./scripts/aws-admin.sh` which takes care of configuring the environment variables to use the admin **api_key**.

I start by listing the contents of the bucket, which is empty for now:

```sh
$ ./scripts/aws-admin.sh s3 ls --recursive
2025-03-25 17:22:22 sklein-backup-bucket-write-once-read-many
$ ./scripts/aws-admin.sh s3 ls sklein-backup-bucket-write-once-read-many --recursive
```

I verify that *Object Lock* is configured in `GOVERNANCE` mode:

```sh
$ ./scripts/aws-admin.sh s3api get-object-lock-configuration --bucket sklein-backup-bucket-write-once-read-many
{
    "ObjectLockConfiguration": {
        "ObjectLockEnabled": "Enabled",
        "Rule": {
            "DefaultRetention": {
                "Mode": "GOVERNANCE",
                "Days": 1
            }
        }
    }
}
```

I create two files:

```sh
$ echo "Content 1" | ./scripts/aws-admin.sh s3 cp - s3://sklein-backup-bucket-write-once-read-many/file1.txt
$ echo "Content 1 file 2" | ./scripts/aws-admin.sh s3 cp - s3://sklein-backup-bucket-write-once-read-many/file2.txt
$ ./scripts/aws-admin.sh s3 ls sklein-backup-bucket-write-once-read-many --recursive
2025-03-25 18:29:32         10 file1.txt
2025-03-25 18:29:34         10 file2.txt
$ ./scripts/aws-admin.sh s3 cp s3://sklein-backup-bucket-write-once-read-many/file1.txt -
Content 1
```

I overwrite the content of file `file1.txt`:

```
$ echo "Content 2" | ./scripts/aws-admin.sh s3 cp - s3://sklein-backup-bucket-write-once-read-many/file1.txt
$ ./scripts/aws-admin.sh s3 cp s3://sklein-backup-bucket-write-once-read-many/file1.txt -
Content 2
```

I check that a new version of the file has been created, the content of the original file is not deleted:

```
$ ./scripts/aws-admin.sh s3api list-object-versions --bucket sklein-backup-bucket-write-once-read-many --prefix file1.txt --query "Versions[].{VersionId:VersionId,LastModified:LastModified,Size:Size}"
[
    {
        "VersionId": "1742924048454278",
        "LastModified": "2025-03-25T17:34:08+00:00",
        "Size": 10
    },
    {
        "VersionId": "1742924031480404",
        "LastModified": "2025-03-25T17:33:51+00:00",
        "Size": 10
    }
]
```

Since I'm using the *admin* *api_key*, I can delete files in the *bucket*:

```
$ ./scripts/aws-admin.sh s3 rm s3://sklein-backup-bucket-write-once-read-many/file1.txt
$ ./scripts/aws-admin.sh s3 ls sklein-backup-bucket-write-once-read-many --recursive
2025-03-25 18:29:32         10 file2.txt
```

However, since *Object lock* is configured in `GOVERNANCE` mode, even the *admin* *api_key* cannot delete a version of the `file1.txt` file:

```sh
$ ./scripts/aws-admin.sh s3api delete-object --bucket sklein-backup-bucket-write-once-read-many --key file1.txt --version-id "1742924048454278"

An error occurred (AccessDenied) when calling the DeleteObject operation: Access Denied because object protected by object lock.
```

Now, I will use the script `./scripts/aws-worm.sh` which uses the *api_key* `sklein_backup_bucket_write_once_read_many_api_key`, which does not have the authorization to delete files.

First, I check that this *api_key* can list files and create files:

```
$ ./scripts/aws-worm.sh s3 ls sklein-backup-bucket-write-once-read-many --recursive
2025-03-25 18:29:32         10 file2.txt
$ echo "Content 1 file 3" | ./scripts/aws-admin.sh s3 cp - s3://sklein-backup-bucket-write-once-read-many/file3.txt
$ ./scripts/aws-worm.sh s3 ls sklein-backup-bucket-write-once-read-many --recursive
2025-03-25 18:29:32         10 file2.txt
2025-03-25 19:15:36         17 file3.txt
```

I check that this *api_key* cannot delete files:

```
$ ./scripts/aws-worm.sh s3 rm s3://sklein-backup-bucket-write-once-read-many/file3.txt
delete failed: s3://sklein-backup-bucket-write-once-read-many/file3.txt An error occurred (AccessDenied) when calling the DeleteObject operation: Access Denied
```

I overwrite the content of file 3 and check that a new version of the file is created:


```sh
$ echo "Content 2 file 3" | ./scripts/aws-admin.sh s3 cp - s3://sklein-backup-bucket-write-once-read-many/file3.txt
$ ./scripts/aws-worm.sh s3api list-object-versions --bucket sklein-backup-bucket-write-once-read-many --prefix file3.txt --query "Versions[].{VersionId:VersionId,LastModified:LastModified,Size:Size}"

[
    {
        "VersionId": "1742932558902222",
        "LastModified": "2025-03-25T19:55:58+00:00",
        "Size": 17
    },
    {
        "VersionId": "1742932551299428",
        "LastModified": "2025-03-25T19:55:51+00:00",
        "Size": 17
    }
]
```

## Important tip

In the bucket policy configuration, it's important not to forget this part:

```
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
```

This declaration allows your user account and terraform to access and modify the created resources.
For example, without this configuration, you would not be able to access the bucket from the Scaleway Web Console.

## Teardown

```sh
$ ./scripts/disable-object-lock-governance.sh
Removing lock for: file1.txt
Removing lock for: file2.txt
The retention date has been set to tomorrow 2025-03-30T00:00:00.000Z, which is the shortest duration accepted by Scaleway Object Storage.
You will be able to delete this bucket only in 24h.
```

24 hours later, execute:

```
$ terraform destroy
```
