{{- define "billing-service.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "billing-service.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "billing-service.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "billing-service.labels" -}}
app.kubernetes.io/name: {{ include "billing-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "billing-service.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{ include "billing-service.name" . }}
{{- else -}}
default
{{- end -}}
{{- end -}}
