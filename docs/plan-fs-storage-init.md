# Plan: Auto-Configure fs_storage on Deployment

> Status: **Draft** -- implement after chart v0.3.0 is validated.

## Problem

When deploying Odoo with S3 filestore, a `fs.storage` record must exist in the
database for attachments to route to object storage. Today this requires manual
configuration through the Odoo UI after every fresh install.

## OCA Module Stack (Odoo 18.0)

The OCA `storage` repository contains two independent ecosystems.
The **modern** one (fsspec-based) is what we use:

| Module | Model | Purpose |
|--------|-------|---------|
| `fs_storage` | `fs.storage` | Storage backend registry, fsspec-based |
| `fs_attachment` | extends `ir.attachment` | Routes attachments to `fs.storage` backends |
| `fs_attachment_s3` | extends `fs.storage` | S3-specific: signed URLs, x-sendfile |

`base_attachment_object_storage` **does not exist** in 18.0 --
`fs_attachment` is its replacement.

### Supported protocols

Protocols are provided by the fsspec ecosystem. Install the pip package
and the protocol appears in the `fs.storage` selection field automatically.

| Protocol | Package | Use case |
|----------|---------|----------|
| `s3` | `fsspec[s3]` | S3-compatible (MinIO, AWS, Ceph, etc.) |
| `gcs` | `fsspec[gcs]` | Google Cloud Storage |
| `az` | `fsspec[abfs]` | Azure Blob Storage |
| `sftp` | `fsspec[sftp]` | SFTP |
| `ftp` | built-in | FTP |
| `file` | built-in | Local filesystem |

## Data Model

### `fs.storage` fields

| Field | Type | Example / Default |
|-------|------|-------------------|
| `name` | Char | `"S3 Filestore"` |
| `code` | Char, unique | `"s3prod"` |
| `protocol` | Selection | `"s3"` |
| `options` | Text (JSON) | `{"endpoint_url": "...", "key": "...", "secret": "..."}` |
| `directory_path` | Char | `"odoo-filestore"` (bucket name) |
| `eval_options_from_env` | Boolean | `True` -- resolves `$VAR` in options from env |
| `use_as_default_for_attachments` | Boolean | Only one record can be `True` (DB constraint) |
| `optimizes_directory_path` | Boolean | Hash-based subdirectories |
| `use_filename_obfuscation` | Boolean | Hide original filenames |
| `autovacuum_gc` | Boolean | Auto-remove orphaned files |
| `force_db_for_default_attachment_rules` | Text (JSON) | `{"image/": 51200, "application/javascript": 0, "text/css": 0}` |

S3-specific fields (from `fs_attachment_s3`):

| Field | Type | Default |
|-------|------|---------|
| `s3_uses_signed_url_for_x_sendfile` | Boolean | `False` |
| `s3_signed_url_expiration` | Integer | `30` (seconds) |

### Attachment routing priority

1. **Field-level** -- `ir.model.fields.storage_id` for a specific field
2. **Model-level** -- `ir.model.storage_id` for a specific model
3. **Default** -- `fs.storage` with `use_as_default_for_attachments=True`
4. **Fallback** -- standard Odoo filestore (database or local disk)

## Design

### Helm values: `backend.storageInit`

Namespaced by protocol so additional storage types (SFTP, GCS, etc.) can be
added without restructuring:

```yaml
backend:
  storageInit:
    enabled: false

    s3:
      enabled: true
      code: "s3prod"
      name: "S3 Filestore"
      directoryPath: ""             # Empty = reuse S3 bucket from minio/externalS3 values
      useAsDefault: true
      optimizeDirectoryPath: true
      filenameObfuscation: false
      autovacuumGc: true
      forceDbRules: '{"image/": 51200, "application/javascript": 0, "text/css": 0}'
      signedUrls: false
      signedUrlExpiration: 30

    # Future storage backends:
    # sftp:
    #   enabled: false
    #   code: "sftpbackup"
    #   protocol: "sftp"
    #   options: '{"host": "...", "username": "..."}'
    #   directoryPath: "/uploads"
```

S3 credentials and endpoint come from the existing `externalS3.*` / `minio.*`
values via environment variables -- no duplication.

### Init Job: `templates/job-storage-init.yaml`

A **post-install, post-upgrade** Helm hook Job that runs an idempotent
`odoo shell` script:

```
helm install/upgrade
  --> pre-upgrade Job: module upgrade (-u)       [hook-weight 0]
  --> Deployment rolls out new pods
  --> post-install/post-upgrade Job: storage init [hook-weight 5]
```

### Why odoo shell (not XML data)?

| Approach | Drawback |
|----------|----------|
| XML `noupdate="1"` | Cannot update on re-deploy |
| XML `noupdate="0"` | Resets user customizations every upgrade |
| Server environment | Overrides fields but does not create records |
| **odoo shell** | Idempotent upsert, env-var credentials, no files on disk |

### Script logic

```python
import json, os

Storage = env["fs.storage"]
code = os.environ["FS_STORAGE_CODE"]

options = json.dumps({
    "endpoint_url": os.environ["AWS_ENDPOINT_URL"],
    "key": os.environ["AWS_ACCESS_KEY_ID"],
    "secret": os.environ["AWS_SECRET_ACCESS_KEY"],
})

vals = {
    "name": os.environ.get("FS_STORAGE_NAME", "S3 Filestore"),
    "code": code,
    "protocol": "s3",
    "options": options,
    "directory_path": os.environ.get("FS_STORAGE_DIRECTORY", "odoo-filestore"),
    "use_as_default_for_attachments": os.environ.get("FS_STORAGE_DEFAULT", "1") == "1",
    "optimizes_directory_path": os.environ.get("FS_STORAGE_OPTIMIZE_DIR", "1") == "1",
    "autovacuum_gc": os.environ.get("FS_STORAGE_AUTOVACUUM", "1") == "1",
}

force_db = os.environ.get("FS_STORAGE_FORCE_DB_RULES")
if force_db:
    vals["force_db_for_default_attachment_rules"] = force_db

existing = Storage.search([("code", "=", code)], limit=1)
if existing:
    existing.write(vals)
    print(f"Updated fs.storage '{code}'")
else:
    Storage.create(vals)
    print(f"Created fs.storage '{code}'")

env.cr.commit()
```

### Job template pattern

Same structure as `job-upgrade.yaml`:

- Same image as backend
- DB + S3 credentials from the same secrets
- `wait-for-db` init container
- Inherits `imagePullSecrets`, `podSecurityContext`, `nodeSelector`, `tolerations`, `affinity`
- Own resource limits (lighter than upgrade job)
- Configurable `hookDeletePolicy`

Additional env vars: `FS_STORAGE_CODE`, `FS_STORAGE_NAME`, `FS_STORAGE_DIRECTORY`,
`FS_STORAGE_DEFAULT`, `FS_STORAGE_OPTIMIZE_DIR`, `FS_STORAGE_AUTOVACUUM`,
`FS_STORAGE_FORCE_DB_RULES`.

## Dockerfile changes

Update `sergio-bershadsky/docker` -- `odoo/18.0/Dockerfile`:

```dockerfile
RUN pip3 install --no-cache-dir \
    odoo-addon-session_db \
    odoo-addon-fs_storage \
    odoo-addon-fs_attachment \
    odoo-addon-fs_attachment_s3 \
    "fsspec[s3]"
```

`base_attachment_object_storage` is removed (does not exist in 18.0).

## Files to create/modify

| File | Action |
|------|--------|
| `charts/odoo/templates/job-storage-init.yaml` | Create |
| `charts/odoo/values.yaml` | Add `backend.storageInit` |
| `charts/odoo/values.schema.json` | Add `storageInit` schema |
| `charts/odoo/templates/_helpers.tpl` | Add storage helpers |
| `charts/odoo/templates/NOTES.txt` | Add storage init info |
| `.github/workflows/lint-test.yaml` | Add template test |
| `charts/odoo/README.md` | Document storage init |

## Implementation sequence

1. Add `backend.storageInit` to `values.yaml`
2. Add helpers to `_helpers.tpl`
3. Create `templates/job-storage-init.yaml`
4. Update `values.schema.json`
5. Update `NOTES.txt` and `README.md`
6. Add CI template tests
7. Validate with `helm lint` + `helm template`
8. Bump chart version

## Open questions

1. **PyPI availability** -- Are `odoo-addon-fs_storage`, `odoo-addon-fs_attachment`,
   `odoo-addon-fs_attachment_s3` published on PyPI for 18.0? If not, install from git.
2. **First boot** -- On `helm install` with an empty DB, `fs_storage` module must be
   initialized (`--init`). Should the upgrade job handle first-install init, or does the
   user run `--init base` separately?
3. **Model-level routing** -- Support `ir.model.storage_id` per model (e.g. route only
   `product.image` to S3), or is `use_as_default_for_attachments` sufficient for v1?
4. **Multiple backends** -- Only one default is allowed. Supporting multiple backends
   (e.g. S3 for attachments, SFTP for backups) requires model-level routing config.
