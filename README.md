# Object Storage append-only backup playground

In this "playground" repository, I explore different methods to configure object storage services in [**append-only**](https://notes.sklein.xyz/Write%20Once%20Read%20Many/) or [Write Once Read Many](https://notes.sklein.xyz/Write%20Once%20Read%20Many/) (WORM) mode.

At the moment, only the Scaleway-based version is published:

- [./scaleway/](./scaleway/)

Next features I want to add to this repository:

- Publish a version for https://www.backblaze.com/ (with and without lock system)
- Add an option to configure the ["lock" system](https://www.scaleway.com/en/docs/object-storage/api-cli/object-lock/#aws-cli-object-lock-configuration) of Scaleway Object Storage
