{{/*
Expand the name of the chart.
*/}}
{{- define "odoo.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "odoo.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Chart label value.
*/}}
{{- define "odoo.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels (no component — add component-specific selector labels separately).
*/}}
{{- define "odoo.labels" -}}
helm.sh/chart: {{ include "odoo.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/name: {{ include "odoo.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Backend selector labels.
*/}}
{{- define "odoo.backend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "odoo.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: backend
{{- end -}}

{{/*
Frontend selector labels.
*/}}
{{- define "odoo.frontend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "odoo.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: frontend
{{- end -}}

{{/*
Nginx selector labels.
*/}}
{{- define "odoo.nginx.selectorLabels" -}}
app.kubernetes.io/name: {{ include "odoo.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: nginx
{{- end -}}

{{/*
Service account name.
*/}}
{{- define "odoo.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "odoo.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/* ---- Database helpers ---- */}}

{{/*
PostgreSQL host — subchart or external.
*/}}
{{- define "odoo.dbHost" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else -}}
{{- required "externalDatabase.host is required when postgresql.enabled=false" .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{/*
PostgreSQL port.
*/}}
{{- define "odoo.dbPort" -}}
{{- if .Values.postgresql.enabled -}}
{{- print "5432" -}}
{{- else -}}
{{- .Values.externalDatabase.port | default 5432 -}}
{{- end -}}
{{- end -}}

{{/*
PostgreSQL user.
*/}}
{{- define "odoo.dbUser" -}}
{{- if .Values.postgresql.enabled -}}
{{- .Values.postgresql.auth.username | default "odoo" -}}
{{- else -}}
{{- .Values.externalDatabase.user | default "odoo" -}}
{{- end -}}
{{- end -}}

{{/*
PostgreSQL database name.
*/}}
{{- define "odoo.dbName" -}}
{{- if .Values.postgresql.enabled -}}
{{- .Values.postgresql.auth.database | default "postgres" -}}
{{- else -}}
{{- .Values.externalDatabase.database | default "postgres" -}}
{{- end -}}
{{- end -}}

{{/*
Database secret name — external existingSecret, postgresql existingSecret, or chart-managed.
*/}}
{{- define "odoo.dbSecretName" -}}
{{- if and (not .Values.postgresql.enabled) .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecret -}}
{{- else if and .Values.postgresql.enabled .Values.postgresql.auth.existingSecret -}}
{{- .Values.postgresql.auth.existingSecret -}}
{{- else -}}
{{- include "odoo.fullname" . -}}
{{- end -}}
{{- end -}}

{{/*
Database secret password key.
*/}}
{{- define "odoo.dbSecretPasswordKey" -}}
{{- if and (not .Values.postgresql.enabled) .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecretPasswordKey | default "password" -}}
{{- else if and .Values.postgresql.enabled .Values.postgresql.auth.existingSecret -}}
{{- .Values.postgresql.auth.existingSecretPasswordKey | default "password" -}}
{{- else -}}
{{- print "db-password" -}}
{{- end -}}
{{- end -}}

{{/*
Resolve database password for chart-managed secret.
*/}}
{{- define "odoo.resolveDbPassword" -}}
{{- if .Values.postgresql.enabled -}}
{{- required "postgresql.auth.password is required" .Values.postgresql.auth.password -}}
{{- else -}}
{{- required "externalDatabase.password is required when postgresql.enabled=false and no existingSecret" .Values.externalDatabase.password -}}
{{- end -}}
{{- end -}}

{{/* ---- S3 helpers ---- */}}

{{/*
S3 endpoint — subchart MinIO or external.
*/}}
{{- define "odoo.s3Endpoint" -}}
{{- if .Values.minio.enabled -}}
{{- printf "http://%s-minio:9000" .Release.Name -}}
{{- else if .Values.externalS3.enabled -}}
{{- required "externalS3.endpoint is required when externalS3.enabled=true" .Values.externalS3.endpoint -}}
{{- end -}}
{{- end -}}

{{/*
S3 secret name — external existingSecret, minio existingSecret, or chart-managed.
*/}}
{{- define "odoo.s3SecretName" -}}
{{- if and .Values.externalS3.enabled .Values.externalS3.existingSecret -}}
{{- .Values.externalS3.existingSecret -}}
{{- else if and .Values.minio.enabled .Values.minio.auth.existingSecret -}}
{{- .Values.minio.auth.existingSecret -}}
{{- else -}}
{{- include "odoo.fullname" . -}}
{{- end -}}
{{- end -}}

{{/*
S3 access key secret key name.
*/}}
{{- define "odoo.s3SecretAccessKeyKey" -}}
{{- if and .Values.externalS3.enabled .Values.externalS3.existingSecret -}}
{{- .Values.externalS3.existingSecretAccessKeyKey | default "access-key" -}}
{{- else if and .Values.minio.enabled .Values.minio.auth.existingSecret -}}
{{- .Values.minio.auth.existingSecretRootUserKey | default "root-user" -}}
{{- else -}}
{{- print "s3-access-key" -}}
{{- end -}}
{{- end -}}

{{/*
S3 secret key secret key name.
*/}}
{{- define "odoo.s3SecretSecretKeyKey" -}}
{{- if and .Values.externalS3.enabled .Values.externalS3.existingSecret -}}
{{- .Values.externalS3.existingSecretSecretKeyKey | default "secret-key" -}}
{{- else if and .Values.minio.enabled .Values.minio.auth.existingSecret -}}
{{- .Values.minio.auth.existingSecretRootPasswordKey | default "root-password" -}}
{{- else -}}
{{- print "s3-secret-key" -}}
{{- end -}}
{{- end -}}

{{/*
Resolve S3 access key for chart-managed secret.
*/}}
{{- define "odoo.resolveS3AccessKey" -}}
{{- if .Values.minio.enabled -}}
{{- .Values.minio.auth.rootUser | default "minioadmin" -}}
{{- else if .Values.externalS3.enabled -}}
{{- required "externalS3.accessKey is required when no existingSecret" .Values.externalS3.accessKey -}}
{{- end -}}
{{- end -}}

{{/*
Resolve S3 secret key for chart-managed secret.
*/}}
{{- define "odoo.resolveS3SecretKey" -}}
{{- if .Values.minio.enabled -}}
{{- required "minio.auth.rootPassword is required" .Values.minio.auth.rootPassword -}}
{{- else if .Values.externalS3.enabled -}}
{{- required "externalS3.secretKey is required when no existingSecret" .Values.externalS3.secretKey -}}
{{- end -}}
{{- end -}}

{{/* ---- Session DB helpers ---- */}}

{{/*
Session DB secret name — external existingSecret or chart-managed.
*/}}
{{- define "odoo.sessionDbSecretName" -}}
{{- if .Values.sessionDb.existingSecret -}}
{{- .Values.sessionDb.existingSecret -}}
{{- else -}}
{{- include "odoo.fullname" . -}}
{{- end -}}
{{- end -}}

{{/*
Session DB secret key.
*/}}
{{- define "odoo.sessionDbSecretKey" -}}
{{- if .Values.sessionDb.existingSecret -}}
{{- .Values.sessionDb.existingSecretKey | default "session-db-uri" -}}
{{- else -}}
{{- print "session-db-uri" -}}
{{- end -}}
{{- end -}}

{{/*
Session DB URI — explicit override or built from DB parts.
*/}}
{{- define "odoo.sessionDbUri" -}}
{{- if .Values.sessionDb.uri -}}
{{- .Values.sessionDb.uri -}}
{{- else -}}
{{- printf "postgres://%s:%s@%s:%s/%s" (include "odoo.dbUser" .) (include "odoo.resolveDbPassword" .) (include "odoo.dbHost" .) (include "odoo.dbPort" .) (include "odoo.dbName" .) -}}
{{- end -}}
{{- end -}}

{{/* ---- Service name helpers ---- */}}

{{/*
Backend service name.
*/}}
{{- define "odoo.backend.serviceName" -}}
{{- printf "%s-backend" (include "odoo.fullname" .) -}}
{{- end -}}

{{/*
Frontend service name.
*/}}
{{- define "odoo.frontend.serviceName" -}}
{{- printf "%s-frontend" (include "odoo.fullname" .) -}}
{{- end -}}

{{/*
Nginx service name.
*/}}
{{- define "odoo.nginx.serviceName" -}}
{{- printf "%s-nginx" (include "odoo.fullname" .) -}}
{{- end -}}

{{/*
Auto-upgrade module list — "all" when empty, comma-joined otherwise.
*/}}
{{- define "odoo.upgradeModules" -}}
{{- if .Values.backend.autoUpgrade.modules -}}
{{- join "," .Values.backend.autoUpgrade.modules -}}
{{- else -}}
all
{{- end -}}
{{- end -}}

{{/*
Resolve ingress service name from path spec.
*/}}
{{- define "odoo.ingress.serviceName" -}}
{{- if eq .service "backend" -}}
{{- printf "%s-backend" .fullname -}}
{{- else if eq .service "frontend" -}}
{{- printf "%s-frontend" .fullname -}}
{{- else -}}
{{- .service -}}
{{- end -}}
{{- end -}}
