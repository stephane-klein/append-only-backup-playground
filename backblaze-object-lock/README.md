# append-only Backblaze Object Storage configuration with Object Lock Governance

This `/backblaze/` directory contains a [`terraform.tf`](./terraform.tf) file that configures a [Backblaze Cloud Storage](https://www.backblaze.com/cloud-storage) (Object Storage) Bucket
in [**append-only**](https://notes.sklein.xyz/Write%20Once%20Read%20Many/) also called [Write Once Read Many](https://notes.sklein.xyz/Write%20Once%20Read%20Many/) mode.

This playground goes further in backup security by using the Object Lock feature in Governance mode ([link to official documentation](https://www.backblaze.com/docs/cloud-storage-object-lock)).  
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

Create BackBlaze resources with *terraform*:

```sh
$ terraform apply
```

This *terraform* configuration creates the following resources:

- an Object Storage *bucket* named `sklein-backup-bucket-write-once-read-many`
- an *admin* *api_key* that has all rights on the bucket `sklein-backup-bucket-write-once-read-many`
- a *WORM* (Write Once Read Many) *api_key* named `sklein_backup_bucket_write_once_read_many_api_key` that does not have the right to delete *objects* (files) in the bucket `sklein-backup-bucket-write-once-read-many`

The `terraform output` command allows you to retrieve the `api_key_id` and `app_key` values of the *admin* and *WORM* *api_key*:

```sh
$ terraform output -json
{
  "sklein_backup_bucket_admin_api_app_key": {
    "sensitive": true,
    "type": "string",
    "value": "..."
  },
  "sklein_backup_bucket_admin_api_key_id": {
    "sensitive": false,
    "type": "string",
    "value": "0036d686ab83552000000000a"
  },
  "sklein_backup_bucket_write_once_read_many_api_app_key": {
    "sensitive": true,
    "type": "string",
    "value": "..."
  },
  "sklein_backup_bucket_write_once_read_many_api_key_id": {
    "sensitive": false,
    "type": "string",
    "value": "0036d686ab835520000000005"
  }
}
```

Now, let's play a bit with the two scripts `./scripts/aws-admin.sh` and `./scripts/aws-worm.sh`.

I start by manipulating the bucket with the administrator **api_key**

First, I list the contents of the bucket, which is empty for now:

```sh
$ ./scripts/aws-admin.sh s3 ls --recursive
2025-03-25 17:22:22 sklein-backup-bucket-write-once-read-many
...
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
$ echo "Content 1 file 1" | ./scripts/aws-admin.sh s3 cp - s3://sklein-backup-bucket-write-once-read-many/file1.txt
$ echo "Content 1 file 2" | ./scripts/aws-admin.sh s3 cp - s3://sklein-backup-bucket-write-once-read-many/file2.txt
$ ./scripts/aws-admin.sh s3 ls sklein-backup-bucket-write-once-read-many --recursive
2025-03-25 18:29:32         10 file1.txt
2025-03-25 18:29:34         10 file2.txt
$ ./scripts/aws-admin.sh s3 cp s3://sklein-backup-bucket-write-once-read-many/file1.txt -
Content 1
```

I overwrite the content of file `file1.txt`:

```
$ echo "Content 2 file 1" | ./scripts/aws-admin.sh s3 cp - s3://sklein-backup-bucket-write-once-read-many/file1.txt
$ ./scripts/aws-admin.sh s3 cp s3://sklein-backup-bucket-write-once-read-many/file1.txt -
Content 2 file 1
```

I check that a new version of the file has been created, the content of the original file is not deleted:

```
$ ./scripts/aws-admin.sh s3api list-object-versions --bucket sklein-backup-bucket-write-once-read-many --prefix file1.txt --query "Versions[].{VersionId:VersionId,LastModified:LastModified,Size:Size}"
[
    {
        "VersionId": "4_z969df6b8d67aeb0893550512_f412d55ae709190f6_d20250329_m075426_c003_v0312027_t0031_u01743234866700",
        "LastModified": "2025-03-29T07:54:26.700000+00:00",
        "Size": 17
    },
    {
        "VersionId": "4_z969df6b8d67aeb0893550512_f4194f077c43003f7_d20250329_m075339_c003_v0312025_t0004_u01743234819061",
        "LastModified": "2025-03-29T07:53:39.061000+00:00",
        "Size": 17
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
❯ ./scripts/aws-admin.sh s3api delete-object --bucket sklein-backup-bucket-write-once-read-many --key file1.txt --version-id "4_z969df6b8d67aeb0893550512_f412d55ae709190f6_d20250329_m075426_c003_v0312027_t0031_u01743234866700"

An error occurred (AccessDenied) when calling the DeleteObject operation: Access Denied
```

Now, I will use the script `./scripts/aws-worm.sh` which uses the *WORM* *api_key* `sklein_backup_bucket_write_once_read_many_api_key`,
which does not have the authorization to delete files.

Warning, this *WORM* *api_key* is not authorized to display the list of buckets:

```sh
$ ./scripts/aws-worm.sh s3 ls
An error occurred (AccessDenied) when calling the ListBuckets operation: not entitled
```

This error is normal.

First, I check that this *api_key* can list files and create files:

```
$ ./scripts/aws-worm.sh s3 ls sklein-backup-bucket-write-once-read-many --recursive
2025-03-25 18:29:32         10 file2.txt
$ echo "Content 1 file 3" | ./scripts/aws-admin.sh s3 cp - s3://sklein-backup-bucket-write-once-read-many/file3.txt
$ ./scripts/aws-worm.sh s3 ls sklein-backup-bucket-write-once-read-many --recursive
2025-03-25 18:29:32         10 file2.txt
2025-03-25 19:15:36         17 file3.txt
```

I overwrite the content of file 3 and check that a new version of the file is created:


```sh
$ echo "Content 2 file 3" | ./scripts/aws-admin.sh s3 cp - s3://sklein-backup-bucket-write-once-read-many/file3.txt
$ ./scripts/aws-worm.sh s3api list-object-versions --bucket sklein-backup-bucket-write-once-read-many --prefix file3.txt --query "Versions[].{VersionId:VersionId,LastModified:LastModified,Size:Size}"
[
    {
        "VersionId": "4_z26fdb6d866eadb8893550512_f4022fb636cc7a2c2_d20250328_m170234_c003_v0312027_t0056_u01743181354630",
        "LastModified": "2025-03-28T17:02:34.630000+00:00",
        "Size": 17
    },
    {
        "VersionId": "4_z26fdb6d866eadb8893550512_f408c3e8ea63cea71_d20250328_m170227_c003_v0312015_t0025_u01743181347914",
        "LastModified": "2025-03-28T17:02:34.630000+00:00",
        "Size": 17
    }
]
```

Although the `deleteFiles` capability is not assigned to the WORM `api_key`, this key can still delete a file:

```
$ ./scripts/aws-worm.sh s3 rm s3://sklein-backup-bucket-write-once-read-many/file3.txt
delete: s3://sklein-backup-bucket-write-once-read-many/file3.txt
```

I have no idea at the moment why this operation is not denied.

This may seem problematic for the intended goal, which is WORM, but I notice that this *WORM* *api_key* cannot delete versions:

```sh
$ ./scripts/aws-worm.sh s3api delete-object --bucket sklein-backup-bucket-write-once-read-many --key file3.txt --version-id "4_z26fdb6d866eadb8893550512_f4022fb636cc7a2c2_d20250328_m170234_c003_v0312027_t0056_u01743181354630"
An error occurred (AccessDenied) when calling the DeleteObject operation: not entitled
```

This is good news, a malicious user with the *WORM* *api_key* will not be able to delete the backups.

However, version deletion works with the *admin* *api_key*, which is normal:

```sh
$ ./scripts/aws-admin.sh s3api delete-object --bucket sklein-backup-bucket-write-once-read-many --key file3.txt --version-id "4_z26fdb6d866eadb8893550512_f4022fb636cc7a2c2_d20250328_m170234_c003_v0312027_t0056_u01743181354630"
{
    "VersionId": "4_z26fdb6d866eadb8893550512_f4022fb636cc7a2c2_d20250328_m170234_c003_v0312027_t0056_u01743181354630"
}
```

```sh
$ ./scripts/aws-admin.sh s3api list-object-versions --bucket sklein-backup-bucket-write-once-read-many --prefix file3.txt --query "Versions[].{VersionId:VersionId,LastModified:LastModified,Size:Size}"
null
[
    {
        "VersionId": "4_z26fdb6d866eadb8893550512_f408c3e8ea63cea71_d20250328_m170227_c003_v0312015_t0025_u01743181347914",
        "LastModified": "2025-03-28T17:02:34.630000+00:00",
        "Size": 17
    }
]
```

## Teardown

```sh
$ ./scripts/disable-object-lock-governance.sh
Removing lock for: file1.txt
Removing lock for: file2.txt
The retention date has been set to tomorrow 2025-03-30T00:00:00.000Z, which is the shortest duration accepted by Scaleway Object Storage.
You will be able to delete this bucket only in 24h.
```
```sh
$ ./scripts/destroy-bucket-objects.sh
...
```
24 hours later, execute:

```sh
$ terraform destroy
```
