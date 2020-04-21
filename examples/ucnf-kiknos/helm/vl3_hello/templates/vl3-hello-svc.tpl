apiVersion: v1
kind: Service
metadata:
  name: helloworld-{{ .Values.nsm.app }}
  labels:
    app: {{ .Values.nsm.app }}
    nsm/role: client
spec:
  ports:
  - port: 5000
    name: http
  selector:
    app: {{ .Values.nsm.app | quote }}
