{{- define "acmecorp-platform.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "acmecorp-platform.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "acmecorp-platform.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "acmecorp-platform.labels" -}}
app.kubernetes.io/name: {{ include "acmecorp-platform.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "acmecorp-platform.chart" . }}
{{- end -}}

{{- define "acmecorp-platform.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version -}}
{{- end -}}

{{- define "acmecorp-platform.namespace.app" -}}
{{- default .Release.Namespace .Values.global.namespaces.app -}}
{{- end -}}

{{- define "acmecorp-platform.namespace.data" -}}
{{- default "data" .Values.global.namespaces.data -}}
{{- end -}}

{{- define "acmecorp-platform.namespace.observability" -}}
{{- default "observability" .Values.global.namespaces.observability -}}
{{- end -}}

{{- define "acmecorp-platform.namespace.externalSecrets" -}}
{{- default "external-secrets" .Values.global.namespaces.externalSecrets -}}
{{- end -}}

{{- define "acmecorp-platform.tmpVolume" -}}
- name: tmp
  emptyDir: {}
{{- end -}}

{{- define "acmecorp-platform.tmpVolumeMount" -}}
- name: tmp
  mountPath: /tmp
{{- end -}}
