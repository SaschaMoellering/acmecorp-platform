{{- define "notification-service.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "notification-service.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "notification-service.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "notification-service.labels" -}}
app.kubernetes.io/name: {{ include "notification-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "notification-service.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{ include "notification-service.fullname" . }}
{{- else -}}
default
{{- end -}}
{{- end -}}
