# Odoo Helm Chart

![Version: 0.3.0](https://img.shields.io/badge/Version-0.3.0-informational?style=flat-square)
![AppVersion: 18.0](https://img.shields.io/badge/AppVersion-18.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

Production-ready Helm chart for [Odoo 18.0](https://www.odoo.com/) with PostgreSQL, S3-compatible object storage, optional web frontend, and optional nginx reverse proxy.

**Source:** <https://github.com/sergio-bershadsky/helm>
**Maintainer:** Sergey Bershadsky (sergio@djangoheads.com)

---

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Docker Image](#docker-image)
- [Quick Start](#quick-start)
- [Values Reference](#values-reference)
  - [Global / ServiceAccount](#global--serviceaccount)
  - [PostgreSQL (Bitnami Subchart)](#postgresql-bitnami-subchart)
  - [External Database](#external-database)
  - [MinIO (Bitnami Subchart)](#minio-bitnami-subchart)
  - [External S3](#external-s3)
  - [Session Database](#session-database)
  - [Backend (Odoo)](#backend-odoo)
  - [Auto-Upgrade](#auto-upgrade)
  - [Frontend](#frontend)
  - [Nginx](#nginx)
  - [Ingress](#ingress)
- [Usage Scenarios](#usage-scenarios)
- [Auto-Upgrade](#auto-upgrade-1)

---

## Overview

This chart deploys a full Odoo 18.0 stack consisting of:

- **Backend** -- Odoo application server (HTTP on port 8069, WebSocket on port 8072)
- **PostgreSQL** -- via the Bitnami subchart, or bring your own external database
- **MinIO** -- S3-compatible object storage for the Odoo filestore, via the Bitnami subchart, or bring your own external S3
- **Session database** -- PostgreSQL-backed HTTP session store (uses the same DB by default, or a dedicated URI)
- **Frontend** (optional) -- generic container for a custom web frontend (e.g. Next.js)
- **Nginx** (optional) -- reverse proxy with CORS, gzip, maintenance page, and domain-based routing
- **Ingress** (optional) -- standard Kubernetes Ingress resource

The chart is provider-agnostic. Every external dependency (database, S3, session store) can be supplied either through the bundled subcharts or through `existingSecret` references to pre-provisioned Kubernetes secrets.

## Prerequisites

| Requirement  | Minimum Version |
|--------------|-----------------|
| Kubernetes   | >= 1.26         |
| Helm         | >= 3.12         |

## Docker Image

The recommended image is:

```
ghcr.io/sergio-bershadsky/odoo:18.0-<version>
```

Built from the [`sergio-bershadsky/docker-odoo`](https://github.com/sergio-bershadsky/docker-odoo) repository, this custom image ships with the `session_db` module and the S3 filestore addon pre-installed so that session persistence and S3 storage work out of the box.

Set the image in your values:

```yaml
backend:
  image:
    repository: ghcr.io/sergio-bershadsky/odoo
    tag: "18.0-latest"
```

## Quick Start

```bash
helm dependency update charts/odoo

helm install my-odoo charts/odoo \
  --set postgresql.auth.password=changeme \
  --set minio.auth.rootPassword=changeme
```

This brings up Odoo with the bundled PostgreSQL and MinIO subcharts using default settings.

> **Note:** On first boot against an empty database, Odoo requires `--init base`. You can pass this via `backend.env` or exec into the pod.

---

## Values Reference

### Global / ServiceAccount

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `global.imagePullSecrets` | list | `[]` | Docker registry pull secrets |
| `nameOverride` | string | `""` | Override the chart name |
| `fullnameOverride` | string | `""` | Override the full release name |
| `serviceAccount.create` | bool | `true` | Create a ServiceAccount |
| `serviceAccount.name` | string | `""` | ServiceAccount name (generated from fullname if empty) |
| `serviceAccount.annotations` | object | `{}` | Annotations for the ServiceAccount |

### PostgreSQL (Bitnami Subchart)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `postgresql.enabled` | bool | `true` | Deploy the Bitnami PostgreSQL subchart |
| `postgresql.auth.username` | string | `"odoo"` | Database user |
| `postgresql.auth.password` | string | `""` | **REQUIRED.** Database password (pass via `--set` or `existingSecret`) |
| `postgresql.auth.database` | string | `"postgres"` | Database name |
| `postgresql.auth.existingSecret` | string | `""` | Name of an existing Secret containing the password |
| `postgresql.primary.persistence.enabled` | bool | `true` | Enable persistent storage |
| `postgresql.primary.persistence.size` | string | `"8Gi"` | PVC size |

### External Database

Used when `postgresql.enabled=false`.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `externalDatabase.host` | string | `""` | **REQUIRED** when subchart is disabled. Database hostname |
| `externalDatabase.port` | int | `5432` | Database port |
| `externalDatabase.user` | string | `"odoo"` | Database user |
| `externalDatabase.database` | string | `"postgres"` | Database name |
| `externalDatabase.password` | string | `""` | Database password (inline, dev only) |
| `externalDatabase.existingSecret` | string | `""` | Kubernetes Secret name |
| `externalDatabase.existingSecretPasswordKey` | string | `"password"` | Key within the Secret |

### MinIO (Bitnami Subchart)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `minio.enabled` | bool | `true` | Deploy the Bitnami MinIO subchart |
| `minio.auth.rootUser` | string | `"minioadmin"` | MinIO root user |
| `minio.auth.rootPassword` | string | `""` | **REQUIRED.** MinIO root password |
| `minio.auth.existingSecret` | string | `""` | Name of an existing Secret |
| `minio.persistence.enabled` | bool | `true` | Enable persistent storage |
| `minio.persistence.size` | string | `"10Gi"` | PVC size |
| `minio.provisioning.enabled` | bool | `true` | Auto-create buckets on startup |
| `minio.provisioning.buckets` | list | `[{name: odoo-filestore}]` | Buckets to provision |

### External S3

Used when `minio.enabled=false`.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `externalS3.enabled` | bool | `false` | Enable external S3 configuration |
| `externalS3.endpoint` | string | `""` | S3 endpoint URL (e.g. `https://s3.amazonaws.com`) |
| `externalS3.bucket` | string | `"odoo-filestore"` | Bucket name |
| `externalS3.region` | string | `""` | AWS region (sets `AWS_DEFAULT_REGION`) |
| `externalS3.accessKey` | string | `""` | Access key (inline, dev only) |
| `externalS3.secretKey` | string | `""` | Secret key (inline, dev only) |
| `externalS3.existingSecret` | string | `""` | Kubernetes Secret name |
| `externalS3.existingSecretAccessKeyKey` | string | `"access-key"` | Key for access key within the Secret |
| `externalS3.existingSecretSecretKeyKey` | string | `"secret-key"` | Key for secret key within the Secret |

### Session Database

By default the session store URI is built automatically from the database connection parameters. Override with an explicit URI or an existing Secret.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `sessionDb.uri` | string | `""` | Full PostgreSQL URI override (`postgres://user:pass@host/db`) |
| `sessionDb.existingSecret` | string | `""` | Kubernetes Secret name containing the URI |
| `sessionDb.existingSecretKey` | string | `"session-db-uri"` | Key within the Secret |

### Backend (Odoo)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `backend.replicaCount` | int | `1` | Number of Odoo replicas |
| `backend.image.repository` | string | `"odoo"` | Container image repository |
| `backend.image.tag` | string | `"18.0"` | Container image tag |
| `backend.image.pullPolicy` | string | `"IfNotPresent"` | Image pull policy |
| `backend.odoo.logLevel` | string | `"error"` | Odoo log level |
| `backend.odoo.addonsPath` | string | `"/mnt/extra-addons"` | Path to extra addons |
| `backend.odoo.proxyMode` | bool | `true` | Enable `--proxy-mode` |
| `backend.odoo.serverWideModules` | string | `"base,web,session_db"` | Modules loaded via `--load` |
| `backend.env` | list | `[]` | Additional environment variables |
| `backend.service.type` | string | `"ClusterIP"` | Service type |
| `backend.service.ports.http` | int | `8069` | HTTP port |
| `backend.service.ports.websocket` | int | `8072` | WebSocket (gevent) port |
| `backend.startupProbe.enabled` | bool | `true` | Enable startup probe |
| `backend.startupProbe.path` | string | `"/web/health"` | Health check path |
| `backend.startupProbe.initialDelaySeconds` | int | `10` | Delay before first check |
| `backend.startupProbe.periodSeconds` | int | `10` | Check interval |
| `backend.startupProbe.timeoutSeconds` | int | `5` | Check timeout |
| `backend.startupProbe.failureThreshold` | int | `30` | Failures before unhealthy (5 min budget) |
| `backend.livenessProbe.enabled` | bool | `true` | Enable liveness probe |
| `backend.livenessProbe.path` | string | `"/web/health"` | Health check path |
| `backend.livenessProbe.periodSeconds` | int | `30` | Check interval |
| `backend.livenessProbe.timeoutSeconds` | int | `5` | Check timeout |
| `backend.livenessProbe.failureThreshold` | int | `6` | Failures before restart |
| `backend.readinessProbe.enabled` | bool | `true` | Enable readiness probe |
| `backend.readinessProbe.path` | string | `"/web/health"` | Health check path |
| `backend.readinessProbe.periodSeconds` | int | `10` | Check interval |
| `backend.readinessProbe.timeoutSeconds` | int | `5` | Check timeout |
| `backend.readinessProbe.failureThreshold` | int | `3` | Failures before not-ready |
| `backend.resources.requests.cpu` | string | `"250m"` | CPU request |
| `backend.resources.requests.memory` | string | `"512Mi"` | Memory request |
| `backend.resources.limits.cpu` | string | `"1"` | CPU limit |
| `backend.resources.limits.memory` | string | `"1536Mi"` | Memory limit |
| `backend.podSecurityContext` | object | See values.yaml | Pod-level security context (`fsGroup: 101`, seccomp RuntimeDefault) |
| `backend.containerSecurityContext` | object | See values.yaml | Container security context (non-root UID 101, drop ALL caps) |
| `backend.updateStrategy.type` | string | `"RollingUpdate"` | Deployment update strategy |
| `backend.initContainers.waitForDb.enabled` | bool | `true` | Wait for PostgreSQL before starting Odoo |
| `backend.pdb.enabled` | bool | `true` | Create a PodDisruptionBudget |
| `backend.pdb.minAvailable` | int | `1` | Minimum available pods |
| `backend.nodeSelector` | object | `{}` | Node selector |
| `backend.tolerations` | list | `[]` | Tolerations |
| `backend.affinity` | object | `{}` | Affinity rules |

### Auto-Upgrade

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `backend.autoUpgrade.enabled` | bool | `false` | Enable the pre-upgrade Job |
| `backend.autoUpgrade.modules` | list | `[]` | Modules to upgrade (empty = all) |
| `backend.autoUpgrade.updateModuleList` | bool | `true` | Run `update_list` before upgrading |
| `backend.autoUpgrade.hookDeletePolicy` | string | `"hook-succeeded"` | Helm hook delete policy |
| `backend.autoUpgrade.resources.requests.cpu` | string | `"500m"` | CPU request for upgrade Job |
| `backend.autoUpgrade.resources.requests.memory` | string | `"1Gi"` | Memory request for upgrade Job |
| `backend.autoUpgrade.resources.limits.cpu` | string | `"2"` | CPU limit for upgrade Job |
| `backend.autoUpgrade.resources.limits.memory` | string | `"3Gi"` | Memory limit for upgrade Job |
| `backend.autoUpgrade.backoffLimit` | int | `0` | Job retry count (0 = no retries) |
| `backend.autoUpgrade.activeDeadlineSeconds` | int | `3600` | Job timeout in seconds (1 hour) |

### Frontend

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `frontend.enabled` | bool | `false` | Deploy the frontend |
| `frontend.replicaCount` | int | `1` | Number of replicas |
| `frontend.image.repository` | string | `""` | Container image repository |
| `frontend.image.tag` | string | `""` | Container image tag |
| `frontend.image.pullPolicy` | string | `"IfNotPresent"` | Image pull policy |
| `frontend.command` | list | `[]` | Override container command |
| `frontend.args` | list | `[]` | Override container args |
| `frontend.env` | list | `[]` | Additional environment variables |
| `frontend.service.type` | string | `"ClusterIP"` | Service type |
| `frontend.service.port` | int | `3000` | Service port |
| `frontend.service.sessionAffinity.enabled` | bool | `false` | Enable session affinity |
| `frontend.service.sessionAffinity.timeoutSeconds` | int | `10800` | Session affinity timeout |
| `frontend.startupProbe.enabled` | bool | `true` | Enable startup probe |
| `frontend.livenessProbe.enabled` | bool | `true` | Enable liveness probe |
| `frontend.readinessProbe.enabled` | bool | `true` | Enable readiness probe |
| `frontend.resources.requests.cpu` | string | `"100m"` | CPU request |
| `frontend.resources.requests.memory` | string | `"128Mi"` | Memory request |
| `frontend.resources.limits.cpu` | string | `"500m"` | CPU limit |
| `frontend.resources.limits.memory` | string | `"512Mi"` | Memory limit |
| `frontend.podSecurityContext` | object | See values.yaml | Pod-level security context (fsGroup 1000) |
| `frontend.containerSecurityContext` | object | See values.yaml | Container security context (non-root UID 1000) |
| `frontend.updateStrategy.type` | string | `"RollingUpdate"` | Deployment update strategy |
| `frontend.pdb.enabled` | bool | `false` | Create a PodDisruptionBudget |
| `frontend.pdb.minAvailable` | int | `1` | Minimum available pods |
| `frontend.nodeSelector` | object | `{}` | Node selector |
| `frontend.tolerations` | list | `[]` | Tolerations |
| `frontend.affinity` | object | `{}` | Affinity rules |

### Nginx

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `nginx.enabled` | bool | `false` | Deploy the nginx reverse proxy |
| `nginx.image.repository` | string | `"nginx"` | Container image |
| `nginx.image.tag` | string | `"1.27-alpine"` | Image tag |
| `nginx.replicaCount` | int | `1` | Number of replicas |
| `nginx.service.type` | string | `"ClusterIP"` | Service type |
| `nginx.service.port` | int | `80` | Service port |
| `nginx.timeouts.proxy_read` | string | `"720s"` | Proxy read timeout |
| `nginx.timeouts.proxy_connect` | string | `"720s"` | Proxy connect timeout |
| `nginx.timeouts.proxy_send` | string | `"720s"` | Proxy send timeout |
| `nginx.clientMaxBodySize` | string | `"200m"` | Maximum request body size |
| `nginx.cookieSecure` | bool | `true` | Set Secure flag on cookies |
| `nginx.cors.enabled` | bool | `false` | Enable CORS headers |
| `nginx.cors.origins` | list | `[]` | Allowed CORS origins |
| `nginx.maintenancePage.enabled` | bool | `false` | Serve a maintenance page |
| `nginx.maintenancePage.content` | string | `""` | Inline HTML content |
| `nginx.gzip.enabled` | bool | `true` | Enable gzip compression |
| `nginx.domains.public.host` | string | `""` | Public-facing domain |
| `nginx.domains.backoffice.enabled` | bool | `false` | Enable backoffice domain routing |
| `nginx.domains.backoffice.host` | string | `""` | Backoffice domain |
| `nginx.resources.requests.cpu` | string | `"50m"` | CPU request |
| `nginx.resources.requests.memory` | string | `"32Mi"` | Memory request |
| `nginx.resources.limits.cpu` | string | `"200m"` | CPU limit |
| `nginx.resources.limits.memory` | string | `"128Mi"` | Memory limit |
| `nginx.containerSecurityContext` | object | See values.yaml | Container security context |
| `nginx.nodeSelector` | object | `{}` | Node selector |
| `nginx.tolerations` | list | `[]` | Tolerations |
| `nginx.affinity` | object | `{}` | Affinity rules |

### Ingress

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `ingress.enabled` | bool | `false` | Create an Ingress resource |
| `ingress.className` | string | `""` | Ingress class name |
| `ingress.annotations` | object | `{}` | Ingress annotations |
| `ingress.hosts` | list | `[]` | Host rules |
| `ingress.tls` | list | `[]` | TLS configuration |

---

## Usage Scenarios

### Quick Start (default subcharts)

Deploy with the bundled PostgreSQL and MinIO:

```bash
helm install my-odoo charts/odoo \
  --set postgresql.auth.password=changeme \
  --set minio.auth.rootPassword=changeme
```

### External Database + External S3

Point Odoo at existing infrastructure:

```bash
helm install my-odoo charts/odoo \
  --set postgresql.enabled=false \
  --set externalDatabase.host=my-db.example.com \
  --set externalDatabase.password=dbpass \
  --set minio.enabled=false \
  --set externalS3.enabled=true \
  --set externalS3.endpoint=https://s3.amazonaws.com \
  --set externalS3.accessKey=AKIA... \
  --set externalS3.secretKey=secret
```

### Production with existingSecrets

For production, store credentials in pre-provisioned Kubernetes Secrets and reference them by name. No plaintext passwords appear in Helm values.

```bash
helm install my-odoo charts/odoo \
  --set postgresql.enabled=false \
  --set externalDatabase.host=prod-db \
  --set externalDatabase.existingSecret=my-db-secret \
  --set minio.enabled=false \
  --set externalS3.enabled=true \
  --set externalS3.endpoint=https://s3.amazonaws.com \
  --set externalS3.existingSecret=my-s3-secret \
  --set sessionDb.existingSecret=my-session-secret
```

### Local Development

Minimal resource footprint for local testing:

```bash
helm install odoo charts/odoo \
  --set postgresql.auth.password=dev \
  --set minio.auth.rootPassword=dev \
  --set backend.resources.limits.memory=512Mi
```

---

## Auto-Upgrade

When `backend.autoUpgrade.enabled` is set to `true`, the chart creates a Kubernetes **Job** that runs as a Helm `pre-upgrade` hook. This Job executes before the backend Deployment rolls out new pods, ensuring the database schema is up to date.

### What it does

1. **Waits for PostgreSQL** (if `backend.initContainers.waitForDb.enabled` is true).
2. **Runs `update_list`** (if `backend.autoUpgrade.updateModuleList` is true) -- executes `env['ir.module.module'].update_list()` via `odoo shell` so that newly added modules are registered in the database.
3. **Runs `odoo -u <modules> --stop-after-init`** to perform the actual module upgrade.

### Module selection

- When `backend.autoUpgrade.modules` is **empty** (the default), the Job runs `-u all`, upgrading every installed module.
- When `backend.autoUpgrade.modules` is a list (e.g. `[sale, account]`), the Job runs `-u sale,account`, upgrading only the specified modules.

### Configuration

The Job uses the **same container image and credentials** as the backend Deployment. Resource limits are set separately under `backend.autoUpgrade.resources` because upgrades are typically more CPU/memory-intensive than normal operation.

- `hookDeletePolicy` controls when Helm deletes the completed Job. The default `hook-succeeded` removes it only after success, leaving failed Jobs for debugging.
- `backoffLimit: 0` means the Job will not retry on failure.
- `activeDeadlineSeconds: 3600` provides a one-hour safety timeout.

### Enabling auto-upgrade

```bash
helm upgrade my-odoo charts/odoo \
  --set backend.autoUpgrade.enabled=true
```

To upgrade specific modules only:

```bash
helm upgrade my-odoo charts/odoo \
  --set backend.autoUpgrade.enabled=true \
  --set 'backend.autoUpgrade.modules={sale,account,stock}'
```

---

## License

See the [repository](https://github.com/sergio-bershadsky/helm) for license details.
