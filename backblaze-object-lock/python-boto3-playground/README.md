```sh
$ mise install
$ pip install -r requirments.txt
```

```sh
$ ./playground1.py
Traceback (most recent call last):
  File "/home/stephane/git/github.com/stephane-klein/append-only-backup-playground/backblaze-object-lock/python-boto3-playground/./playground1.py", line 22, in <module>
    s3_client.put_object(
    ~~~~~~~~~~~~~~~~~~~~^
        Body="Foobar",
        ^^^^^^^^^^^^^^
        Bucket="sklein-backup-bucket-write-once-read-many",
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
        Key="test_boto3_admin.txt"
        ^^^^^^^^^^^^^^^^^^^^^^^^^^
    )
    ^
  File "/home/stephane/git/github.com/stephane-klein/append-only-backup-playground/backblaze-object-lock/python-boto3-playground/.venv/lib/python3.13/site-packages/botocore/client.py", line 570, in _api_call
    return self._make_api_call(operation_name, kwargs)
           ~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^
  File "/home/stephane/git/github.com/stephane-klein/append-only-backup-playground/backblaze-object-lock/python-boto3-playground/.venv/lib/python3.13/site-packages/botocore/context.py", line 124, in wrapper
    return func(*args, **kwargs)
  File "/home/stephane/git/github.com/stephane-klein/append-only-backup-playground/backblaze-object-lock/python-boto3-playground/.venv/lib/python3.13/site-packages/botocore/client.py", line 1031, in _make_api_call
    raise error_class(parsed_response, operation_name)
botocore.exceptions.ClientError: An error occurred (InvalidArgument) when calling the PutObject operation: Unsupported header 'x-amz-sdk-checksum-algorithm' received for this API call.
```
