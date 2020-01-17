---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vl3-nse-ucnf
  namespace: {{ .Release.Namespace }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      networkservicemesh.io/app: "vl3-nse-ucnf"
      networkservicemesh.io/impl: {{ .Values.nsm.serviceName | quote }}
  template:
    metadata:
      labels:
        networkservicemesh.io/app: "vl3-nse-ucnf"
        networkservicemesh.io/impl: {{ .Values.nsm.serviceName | quote }}
      annotations:
        sidecar.istio.io/inject: "false"
    spec:
      containers:
        - name: vl3-nse
          image: {{ .Values.registry }}/{{ .Values.org }}/vl3_ucnf-vl3-nse:{{ .Values.tag }}
          imagePullPolicy: {{ .Values.pullPolicy }}
          env:
            - name: ADVERTISE_NSE_NAME
              value: {{ .Values.nsm.serviceName | quote }}
            - name: ADVERTISE_NSE_LABELS
              value: "app=vl3-nse-ucnf"
            - name: TRACER_ENABLED
              value: "true"
            - name: JAEGER_SERVICE_HOST
              value: jaeger.nsm-system
            - name: JAEGER_SERVICE_PORT_JAEGER
              value: "6831"
            - name: JAEGER_AGENT_HOST
              value: jaeger.nsm-system
            - name: JAEGER_AGENT_PORT
              value: "6831"
            - name: NSREGISTRY_ADDR
              value: "nsmgr.nsm-system"
            - name: NSREGISTRY_PORT
              value: "5000"
            - name: NSE_POD_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
{{- if .Values.ipam.uniqueOctet }}
            - name: NSE_IPAM_UNIQUE_OCTET
              value: {{ .Values.ipam.uniqueOctet | quote }}
{{- end }}
            - name: NSM_REMOTE_NS_IP_LIST
              valueFrom:
                configMapKeyRef:
                  name: nsm-vl3
                  key: remote.ip_list
          securityContext:
            capabilities:
              add:
                - NET_ADMIN
            privileged: true
          resources:
            limits:
              networkservicemesh.io/socket: 1
          volumeMounts:
            - mountPath: /etc/universal-cnf/config.yaml
              subPath: config.yaml
              name: universal-cnf-config-volume
      volumes:
        - name: universal-cnf-config-volume
          configMap:
            name: universal-cnf-vl3
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: universal-cnf-vl3
data:
  config.yaml: |
    endpoints:
    - name: {{ .Values.nsm.serviceName | quote }}
      labels:
        app: "vl3-nse-ucnf"
      ipam:
        prefixpool: {{ .Values.ipam.prefixPool | quote }}
        routes: []
      ifname: "endpoint0"
