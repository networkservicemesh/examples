apiVersion: v1
kind: Service
metadata:
  name: helloworld-{{ .Values.nsm.serviceName }}
  labels:
    app: helloworld-{{ .Values.nsm.serviceName }}
    nsm/role: client
spec:
  ports:
  - port: 5000
    name: http
  selector:
    app: helloworld-{{ .Values.nsm.serviceName }}
