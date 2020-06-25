#!/bin/bash
COMMAND_ROOT=$(dirname "${BASH_SOURCE}")
print_usage() {
  echo "$(basename "$0")
Usage: $(basename "$0") [options...]
Options:
  --nsm-hub=STRING          Hub for NSM images
                            (default=\"tiswanso\", environment variable: NSM_HUB) 
  --nsm-tag=STRING          Tag for NSM images
                            (default=\"vl3_api_rebase\", environment variable: NSM_TAG)
  --spire-disabled          Disable spire
" >&2
}

NSM_HUB="${NSM_HUB:-"tiswanso"}"
NSM_TAG="${NSM_TAG:-"vl3_api_rebase"}"
INSTALL_OP=${INSTALL_OP:-apply}

for i in "$@"
do
case $i in
    --nsm-hub=*)
    NSM_HUB="${i#*=}"
    ;;
    --nsm-tag=*)
    NSM_TAG="${i#*=}"
    ;;
    --spire-disabled)
    SPIRE_DISABLED="true"
    ;;
    -h|--help)
      print_usage
      exit 0
    ;;
    *)
      print_usage
      exit 1
    ;;
esac
done

sdir=$(dirname ${0})
#echo "$sdir"

NSMDIR=${NSMDIR:-${sdir}/../../../../networkservicemesh}
VL3DIR=${VL3DIR:-${sdir}/..}
#echo "$NSMDIR"

echo "------------- Create nsm-system namespace ----------"
if [[ "${INSTALL_OP}" != "delete" ]]; then
  kubectl create ns nsm-system ${KCONF:+--kubeconfig $KCONF}
fi
echo "------------Installing NSM monitoring-----------"
#helm template ${NSMDIR}/deployments/helm/nsm-monitoring --namespace nsm-system --set monSvcType=NodePort --set org=${NSM_HUB},tag=${NSM_TAG} | kubectl ${INSTALL_OP} ${KCONF:+--kubeconfig $KCONF} -f -

helm template ${NSMDIR}/deployments/helm/crossconnect-monitor --namespace nsm-system --set insecure="true" --set global.JaegerTracing="true" | kubectl ${INSTALL_OP} ${KCONF:+--kubeconfig $KCONF} -f -
helm template ${NSMDIR}/deployments/helm/jaeger --namespace nsm-system --set insecure="true" --set global.JaegerTracing="true" --set monSvcType=NodePort | kubectl ${INSTALL_OP} ${KCONF:+--kubeconfig $KCONF} -f -
helm template ${NSMDIR}/deployments/helm/skydive --namespace nsm-system --set insecure="true" --set global.JaegerTracing="true" | kubectl ${INSTALL_OP} ${KCONF:+--kubeconfig $KCONF} -f -


#kubednsip=$(kubectl get svc -n kube-system ${KCONF:+--kubeconfig $KCONF} | grep kube-dns | awk '{ print $3 }')
#kinddnsip=$(kubectl get svc ${KCONF:+--kubeconfig $KCONF} | grep kind-dns | awk '{ print $3 }')

echo "------------Installing NSM-----------"
helm template ${NSMDIR}/deployments/helm/nsm --namespace nsm-system --set org=${NSM_HUB},tag=${NSM_TAG} --set pullPolicy=Always --set insecure="true" --set global.JaegerTracing="true" ${SPIRE_DISABLED:+--set spire.enabled=false} | kubectl ${INSTALL_OP} ${KCONF:+--kubeconfig $KCONF} -f -

echo "------------Installing NSM-addons -----------"
helm template ${VL3DIR}/helm/nsm-addons --namespace nsm-system --set global.NSRegistrySvc=true  | kubectl ${INSTALL_OP} ${KCONF:+--kubeconfig $KCONF} -f -

#helm template ${NSMDIR}/deployments/helm/nsm --namespace nsm-system --set global.JaegerTracing=true --set org=${NSM_HUB},tag=${NSM_TAG} --set pullPolicy=Always --set admission-webhook.org=tiswanso --set admission-webhook.tag=vl3-inter-domain2 --set admission-webhook.pullPolicy=Always --set admission-webhook.dnsServer=${kubednsip} ${kinddnsip:+--set "admission-webhook.dnsAltZones[0].zone=example.org" --set "admission-webhook.dnsAltZones[0].server=${kinddnsip}"} --set global.NSRegistrySvc=true --set global.NSMApiSvc=true --set global.NSMApiSvcPort=30501 --set global.NSMApiSvcAddr="0.0.0.0:30501" --set global.NSMApiSvcType=NodePort --set global.ExtraDnsServers="${kubednsip} ${kinddnsip}" --set global.OverrideNsmCoreDns="true" | kubectl ${INSTALL_OP} ${KCONF:+--kubeconfig $KCONF} -f -
#helm template ${NSMDIR}/deployments/helm/nsm --namespace nsm-system --set global.JaegerTracing=true --set org=${NSM_HUB},tag=${NSM_TAG} --set pullPolicy=Always --set admission-webhook.org=tiswanso --set admission-webhook.tag=vl3-inter-domain2 --set admission-webhook.pullPolicy=Always --set global.NSRegistrySvc=true --set global.NSMApiSvc=true --set global.NSMApiSvcPort=30501 --set global.NSMApiSvcAddr="0.0.0.0:30501" --set global.NSMApiSvcType=NodePort --set global.ExtraDnsServers="${kubednsip} ${kinddnsip}" --set global.OverrideDnsServers="${kubednsip} ${kinddnsip}" | kubectl ${INSTALL_OP} ${KCONF:+--kubeconfig $KCONF} -f -

echo "------------Installing proxy NSM-----------"
helm template ${NSMDIR}/deployments/helm/proxy-nsmgr --namespace nsm-system --set org=${NSM_HUB},tag=${NSM_TAG} --set pullPolicy=Always --set insecure="true" --set global.JaegerTracing="true" ${REMOTE_NSR_PORT:+ --set remoteNsrPort=${REMOTE_NSR_PORT}} | kubectl ${INSTALL_OP} ${KCONF:+--kubeconfig $KCONF} -f -

#helm template ${NSMDIR}/deployments/helm/proxy-nsmgr --namespace nsm-system --set global.JaegerTracing=true --set org=${NSM_HUB},tag=${NSM_TAG} --set pullPolicy=Always --set global.NSMApiSvc=true --set global.NSMApiSvcPort=30501 --set global.NSMApiSvcAddr="0.0.0.0:30501" | kubectl ${INSTALL_OP} ${KCONF:+--kubeconfig $KCONF} -f -

#if [[ "${INSTALL_OP}" == "delete" ]]; then
#  echo "------------- Delete nsm-system ns ----------------"
#  kubectl delete ns nsm-system ${KCONF:+--kubeconfig $KCONF}
#fi
