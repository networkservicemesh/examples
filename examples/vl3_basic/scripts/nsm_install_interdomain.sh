#!/bin/bash

HUB=${HUB:-tiswanso}
TAG=${TAG:-vl3-inter-domain}

INSTALL_OP=${INSTALL_OP:-apply}

sdir=$(dirname ${0})
#echo "$sdir"

NSMDIR=${NSMDIR:-${sdir}/../../../../networkservicemesh}
#echo "$NSMDIR"


echo "------------Installing NSM monitoring-----------"
helm template ${NSMDIR}/deployments/helm/nsm-monitoring --namespace nsm-system --set monSvcType=NodePort --set org=${HUB},tag=${TAG} | kubectl ${INSTALL_OP} ${KCONF:+--kubeconfig $KCONF} -f -

kubednsip=$(kubectl get svc -n kube-system ${KCONF:+--kubeconfig $KCONF} | grep kube-dns | awk '{ print $3 }')

echo "------------Installing NSM-----------"
helm template ${NSMDIR}/deployments/helm/nsm --namespace nsm-system --set global.JaegerTracing=true --set org=${HUB},tag=${TAG} --set pullPolicy=Always --set admission-webhook.org=tiswanso --set admission-webhook.tag=vl3-inter-domain --set admission-webhook.pullPolicy=Always --set global.NSRegistrySvc=true --set global.NSMApiSvc=true --set global.NSMApiSvcPort=30501 --set global.NSMApiSvcAddr="0.0.0.0:30501" --set global.NSMApiSvcType=NodePort --set global.ExtraDnsServers=${kubednsip} | kubectl ${INSTALL_OP} ${KCONF:+--kubeconfig $KCONF} -f -

echo "------------Installing proxy NSM-----------"
helm template ${NSMDIR}/deployments/helm/proxy-nsmgr --namespace nsm-system --set global.JaegerTracing=true --set org=${HUB},tag=${TAG} --set pullPolicy=Always --set global.NSMApiSvc=true --set global.NSMApiSvcPort=30501 --set global.NSMApiSvcAddr="0.0.0.0:30501" | kubectl ${INSTALL_OP} ${KCONF:+--kubeconfig $KCONF} -f -

