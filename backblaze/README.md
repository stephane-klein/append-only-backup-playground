# append-only Backblaze Object Storage configuration

This `/backblaze/` directory contains a [`terraform.tf`](./terraform.tf) file that configures a [Backblaze Cloud Storage](https://www.backblaze.com/cloud-storage) (Object Storage) Bucket
in [**append-only**](https://notes.sklein.xyz/Write%20Once%20Read%20Many/) or [Write Once Read Many](https://notes.sklein.xyz/Write%20Once%20Read%20Many/) mode.

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
        "VersionId": "4_z26fdb6d866eadb8893550512_f41277cd907da261b_d20250328_m160310_c003_v0312028_t0058_u01743177790552",
        "LastModified": "2025-03-28T16:03:10.552000+00:00",
        "Size": 10
    },
    {
        "VersionId": "4_z26fdb6d866eadb8893550512_f408b518c54bf6010_d20250328_m160249_c003_v0312027_t0047_u01743177769547",
        "LastModified": "2025-03-28T16:02:49.547000+00:00",
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
