{{- define "catalog-service.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "catalog-service.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "catalog-service.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "catalog-service.labels" -}}
app.kubernetes.io/name: {{ include "catalog-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "catalog-service.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{ include "catalog-service.fullname" . }}
{{- else -}}
default
{{- end -}}
{{- end -}}
