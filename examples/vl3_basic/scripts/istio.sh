#!/bin/bash

# Inputs:
# KCONF = the K8S cluster to install Istio, Istio CNI and the Pod watcher.
# Also the cluster that is watched
# KCONF_KIND = the kubeconfig for the KIND cluster.  Needs to be modified from
# what KIND automatically creates.
# HELMDIR = (optional) directory with istio and istio-cni helm charts
#           default assumes to use istio and istio-cni src repos under $GOPATH/src/istio.io/...

HUB=${HUB:-docker.io/istio}
TAG=${TAG:-release-1.3}

INSTALL_OP=${INSTALL_OP:-apply}

HELMDIR=/Users/tiswanso/tmp/istio/istio-1.3.1/install/kubernetes/helm 
sdir=$GOPATH/src
#sdir=$(dirname ${0})
#echo "$sdir"

if [[ -z $HELMDIR ]]; then
    ISTIOCNIDIR=${ISTIOCNIDIR:-${sdir}/istio.io/cni}
    #echo "$ISTIOCNIDIR"
    ISTIOCNIHELM=${ISTIOCNIDIR}/deployments/kubernetes/install/helm/istio-cni

    ISTIODIR=${ISTIODIR:-${sdir}/istio.io/istio}
    #echo "$ISTIODIR"
    ISTIOHELM=${ISTIODIR}/install/kubernetes/helm/istio
else
    ISTIOCNIHELM=${HELMDIR}/istio-cni
    ISTIOHELM=${HELMDIR}/istio
fi

PODWATCHDIR=${PODWATCHDIR:-${sdir}/github.com/nsm-istio}

echo "------------Installing Istio CNI -----------"
helm template ${ISTIOCNIHELM} --name=istio-cni --namespace=kube-system --set logLevel=info --set excludeNamespaces={"istio-system,kube-system,nsm-system"} | kubectl ${INSTALL_OP} ${KCONF:+--kubeconfig $KCONF} -f -

echo "------------Installing Istio -----------"
if [ ${INSTALL_OP} == "delete" ]; then
    #helm template ${ISTIOHELM} --name istio --namespace istio-system --set proxy=proxy_debug --set istio_cni.enabled=true | kubectl ${INSTALL_OP} ${KCONF:+--kubeconfig $KCONF} -f -
    helm template ${ISTIOHELM} --name istio --namespace istio-system --set global.proxy.image=proxy_debug --set istio_cni.enabled=true | kubectl ${INSTALL_OP} ${KCONF:+--kubeconfig $KCONF} -f -
    helm template ${ISTIOHELM}-init --name istio-init --namespace istio-system | kubectl ${INSTALL_OP} ${KCONF:+--kubeconfig $KCONF} -f -
    kubectl label namespace default istio-injection="" --overwrite ${KCONF:+--kubeconfig $KCONF}
    kubectl delete namespace istio-system ${KCONF:+--kubeconfig $KCONF}
else
    kubectl create namespace istio-system ${KCONF:+--kubeconfig $KCONF}
    sleep 3s
    helm template ${ISTIOHELM}-init --name istio-init --namespace istio-system | kubectl ${INSTALL_OP} ${KCONF:+--kubeconfig $KCONF} -f -
    sleep 20s
    helm template ${ISTIOHELM} --name istio --namespace istio-system --set global.proxy.image=proxy_debug --set istio_cni.enabled=true | kubectl ${INSTALL_OP} ${KCONF:+--kubeconfig $KCONF} -f -
    #helm template ${ISTIOHELM} --name istio --namespace istio-system --set proxy=proxy_debug --set sidecarInjectorWebhook.enabled=false --set istio_cni.enabled=true | kubectl ${INSTALL_OP} ${KCONF:+--kubeconfig $KCONF} -f -
    #helm template ${ISTIOHELM} --name istio --namespace istio-system --set proxy=proxy_debug --set sidecarInjectorWebhook.enableNamespacesByDefault=true --set istio_cni.enabled=true | kubectl ${INSTALL_OP} ${KCONF:+--kubeconfig $KCONF} -f -
    #helm template ${ISTIOHELM} --name istio --namespace istio-system --set istio_cni.enabled=true | kubectl ${INSTALL_OP} ${KCONF:+--kubeconfig $KCONF} -f -
    kubectl label namespace default istio-injection=enabled --overwrite ${KCONF:+--kubeconfig $KCONF}
fi

echo "------------Installing pod watcher --------"
if [ ${INSTALL_OP} == "delete" ]; then
    ${PODWATCHDIR}/deployments/scripts/nsm_svc_reg_deploy.sh --svcregkubeconfig=${KCONF_KIND} --remotekubeconfig=${KCONF} --kubeconfig=${KCONF} --delete
else
    ${PODWATCHDIR}/deployments/scripts/nsm_svc_reg_deploy.sh --svcregkubeconfig=${KCONF_KIND} --remotekubeconfig=${KCONF} --kubeconfig=${KCONF}
fi

echo "------------setting up multicluster --------"

CLUSTER_NAME=$(kubectl config view --minify=true -o jsonpath='{.clusters[].name}' --kubeconfig=${KCONF_KIND} )
NAMESPACE=istio-system

if [ ${INSTALL_OP} == "delete" ]; then
    #ALREADY deleted with namespace kubectl delete secret ${CLUSTER_NAME} -n ${NAMESPACE}
    echo " ------ secret already deleted with namespace --------"
else
    kubectl create secret generic ${CLUSTER_NAME} --from-file=${KCONF_KIND} -n ${NAMESPACE} ${KCONF:+--kubeconfig $KCONF}
    kubectl label secret ${CLUSTER_NAME} istio/multiCluster=true -n ${NAMESPACE} ${KCONF:+--kubeconfig $KCONF}
fi

echo "------------Install NSM & NSC & NSE now --------"

