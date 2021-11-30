# Hydra test: migrating from a local cache to an S3-backed cache

This test creates a Hydra with a local Nix store, then starts Minio and
reconfigures Hydra to upload to it. It then issues more builds and
verifies the closure of those builds are uploaded to the new cache.

The intended purpose of this repository is to offer one-time validation of
the behavior.

## Usage

```
nix-build ./hydra-minio.nix
```
