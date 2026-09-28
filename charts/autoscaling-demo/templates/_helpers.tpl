{{- define "demo.name" -}}
{{- printf "%s-demo" .Release.Name | trunc 50 | trimSuffix "-" -}}
{{- end -}}
{{- define "demo.labels" -}}
app.kubernetes.io/name: autoscaling-demo
app.kubernetes.io/instance: {{ .Release.Name | quote }}
{{- end -}}
