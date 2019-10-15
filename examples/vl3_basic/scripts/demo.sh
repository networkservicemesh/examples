#!/bin/bash

usage() {
  echo "usage: $0 [OPTIONS]"
  echo ""
  echo "  MANDATORY OPTIONS:"
  echo ""
  echo "  --svcregkubeconfig=<kubeconfig>      set the kubeconfig for the cluster to use for the svcReg"
  echo "  --kconf_clus1=<kubeconfig>           set the kubeconfig for the first cluster"
  echo "  --kconf_clus2=<kubeconfig>           set the kubeconfig for the second cluster"
  echo ""
  echo "  Optional OPTIONS:"
  echo ""
  echo "  --istiohelmdir=<dir>       the directory for the Istio helm charts"
  echo "                             default=$GOPATH/src/istio.io/istio/install/kubernetes/helm"
  echo "  --namespace=<namespace>    set the namespace to watch for NSM clients"
  echo "  --delete                   delete the installation"
  echo "  --nowait                   don't wait for user input prior to moving to next step"
  echo ""
}

ISTIOHELMDIR=${GOPATH}/src/istio.io/istio/install/kubernetes/helm
NSMISTIODIR=${GOPATH}/src/github.com/nsm-istio

for i in "$@"; do
    case $i in
        -h|--help)
            usage
            exit
            ;;
        --kconf_clus1=?*)
            KCONF_CLUS1=${i#*=}
            echo "setting KCONF_CLUS1=${KCONF_CLUS1}" 
            ;;
        --kconf_clus2=?*)
            KCONF_CLUS2=${i#*=}
            echo "setting KCONF_CLUS2=${KCONF_CLUS2}" 
            ;;
        --svcregkubeconfig=?*)
            SVCREGKUBECONFIG=${i#*=}
            echo "setting SVCREGKUBECONFIG=${SVCREGKUBECONFIG}" 
            ;;
        --istiohelmdir=?*)
            ISTIOHELMDIR=${i#*=}
            ;;
        --namespace=?*)
            NAMESPACE=${i#*=}
            ;;
        --delete)
            DELETE=true
            ;;
        --nowait)
            NOWAIT=true
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

if [[ -z ${KCONF_CLUS1} || -z ${KCONF_CLUS2} || -z ${SVCREGKUBECONFIG} ]]; then
    echo "ERROR: One of kubeconfigs or service registry kubeconfig not set."
    usage
    exit 1
fi

clus1_IP=$(kubectl get node --kubeconfig ${KCONF_CLUS1} --selector='node-role.kubernetes.io/master' -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
clus2_IP=$(kubectl get node --kubeconfig ${KCONF_CLUS2} --selector='node-role.kubernetes.io/master' -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')


########################
# include the magic
########################
DEMOMAGIC=${DEMOMAGIC:-/Users/tiswanso/src/demo-magic/demo-magic.sh}
. ${DEMOMAGIC} -d ${NOWAIT:+-n}

# hide the evidence
clear

function pc {
    pe "$@"
    #pe "clear"
    echo "----DONE---- $@"
    if [[ -z ${NOWAIT} ]]; then
        wait
    fi
    clear
}


pe "# Install Istio in cluster 1"
pc "${DELETE:+INSTALL_OP=delete} HELMDIR=${ISTIOHELMDIR} KCONF=${KCONF_CLUS1} KCONF_KIND=${SVCREGKUBECONFIG} examples/vl3_basic/scripts/istio.sh"

pe "# Install Istio in cluster 2"
pc "${DELETE:+INSTALL_OP=delete} HELMDIR=${ISTIOHELMDIR} KCONF=${KCONF_CLUS2} KCONF_KIND=${SVCREGKUBECONFIG} examples/vl3_basic/scripts/istio.sh"


pe "# Install NSM in cluster 1"
pc "${DELETE:+INSTALL_OP=delete} KCONF=${KCONF_CLUS1} examples/vl3_basic/scripts/nsm_install_interdomain.sh"

pe "# Install NSM in cluster 2"
pc "${DELETE:+INSTALL_OP=delete} KCONF=${KCONF_CLUS2} examples/vl3_basic/scripts/nsm_install_interdomain.sh"

if [[ -z ${DELETE} ]]; then
    p "# Wait for NSM pods to be ready in cluster 1"
    kubectl wait --kubeconfig ${KCONF_CLUS1} --timeout=150s --for condition=Ready -l app=nsmgr-daemonset -n nsm-system pod
    kubectl wait --kubeconfig ${KCONF_CLUS1} --timeout=150s --for condition=Ready -l app=proxy-nsmgr-daemonset -n nsm-system pod

    p "# Wait for NSM pods to be ready in cluster 2"
    kubectl wait --kubeconfig ${KCONF_CLUS2} --timeout=150s --for condition=Ready -l app=nsmgr-daemonset -n nsm-system pod
    kubectl wait --kubeconfig ${KCONF_CLUS2} --timeout=150s --for condition=Ready -l app=proxy-nsmgr-daemonset -n nsm-system pod
fi
    
pe "# Install vL3 + helloworld clients in cluster 1"
pc "${DELETE:+INSTALL_OP=delete} REMOTE_IP=${clus2_IP} KCONF=${KCONF_CLUS1} examples/vl3_basic/scripts/vl3_interdomain.sh"

pe "# Install vL3 + helloworld clients in cluster 2"
pc "${DELETE:+INSTALL_OP=delete} REMOTE_IP=${clus1_IP} KCONF=${KCONF_CLUS2} examples/vl3_basic/scripts/vl3_interdomain.sh"


pe "# Install NSM Client App workload service registry for cluster 1"
pc "KUBECONFIG=${KCONF_CLUS1} ${NSMISTIODIR}/deployments/scripts/nsm_svc_reg_deploy.sh --remotekubeconfig=${KCONF_CLUS1} --svcregkubeconfig=${SVCREGKUBECONFIG} ${DELETE:+--delete}"

pe "# Install NSM Client App workload service registry for cluster 2"
pc "KUBECONFIG=${KCONF_CLUS2} ${NSMISTIODIR}/deployments/scripts/nsm_svc_reg_deploy.sh --remotekubeconfig=${KCONF_CLUS2} --svcregkubeconfig=${SVCREGKUBECONFIG} ${DELETE:+--delete}"

if [[ -z ${DELETE} ]]; then
    # add / remove dummy svc to kind cluster due to Istio not updating listeners without this
    kubectl create svc --kubeconfig ${SVCREGKUBECONFIG} clusterip foo --tcp=5678:8080 
    kubectl delete svc --kubeconfig ${SVCREGKUBECONFIG} foo
else
    pe "Cleanup service registry cluster"
    pc "kubectl delete svc helloworld --kubeconfig ${SVCREGKUBECONFIG}"
fi
