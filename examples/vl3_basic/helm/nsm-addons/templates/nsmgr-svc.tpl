{{- if or .Values.global.NSRegistrySvc .Values.global.NSMApiSvc }}
apiVersion: v1
kind: Service
metadata:
  name: nsmgr
  namespace: {{ .Release.Namespace }}
  labels:
    app: nsmgr
spec:
  ports:
    - name: registry
      port: 5000
{{- if eq .Values.service.nsmgr.type "NodePort" }}
      nodePort: {{ .Values.service.nsmgr.registryPort | default "39500" }}
{{- end }}
    - name: api
      port: 5001
{{- if eq .Values.service.nsmgr.type "NodePort" }}
      nodePort: {{ .Values.service.nsmgr.apiPort | default "39501" }}
{{- end }}
  type: {{ .Values.service.nsmgr.type | default "ClusterIP" }}
  selector:
    app: nsmgr-daemonset
{{- end }}
