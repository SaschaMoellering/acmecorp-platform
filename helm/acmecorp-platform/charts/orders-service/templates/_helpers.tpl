{{- define "orders-service.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "orders-service.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "orders-service.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "orders-service.labels" -}}
app.kubernetes.io/name: {{ include "orders-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "orders-service.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{ include "orders-service.fullname" . }}
{{- else -}}
default
{{- end -}}
{{- end -}}
