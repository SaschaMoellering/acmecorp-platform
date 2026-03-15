{{- define "analytics-service.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "analytics-service.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "analytics-service.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "analytics-service.labels" -}}
app.kubernetes.io/name: {{ include "analytics-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "analytics-service.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{ include "analytics-service.fullname" . }}
{{- else -}}
default
{{- end -}}
{{- end -}}
