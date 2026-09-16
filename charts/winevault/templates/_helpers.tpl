{{- define "winevault.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "winevault.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s" $name -}}
{{- end -}}
{{- end -}}

{{- define "winevault.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "winevault.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "winevault.databaseSecretName" -}}
{{- if .Values.database.existingSecret -}}
{{- .Values.database.existingSecret -}}
{{- else if .Values.database.secretName -}}
{{- .Values.database.secretName -}}
{{- else -}}
{{- printf "%s-db" (include "winevault.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* An existing application database Secret means the bundled database is not needed. */}}
{{- define "winevault.postgresEnabled" -}}
{{- if and .Values.postgres.enabled (not .Values.database.existingSecret) -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}
