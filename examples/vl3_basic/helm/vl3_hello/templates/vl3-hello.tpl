apiVersion: apps/v1
kind: Deployment
metadata:
  name: helloworld-{{ .Values.nsm.serviceName }}
  labels:
    version: v1
  annotations:
    ns.networkservicemesh.io: {{ .Values.nsm.serviceName }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: helloworld-{{ .Values.nsm.serviceName }}
      version: v1
  template:
    metadata:
      labels:
        app: helloworld-{{ .Values.nsm.serviceName }}
        version: v1
    spec:
      containers:
      - name: helloworld
        image: docker.io/istio/examples-helloworld-v1
        resources:
          requests:
            cpu: "100m"
        imagePullPolicy: IfNotPresent #Always
        ports:
        - containerPort: 5000