#!/bin/bash

usage() {
  echo "usage: $0 [OPTIONS]"
  echo ""
  echo "  MANDATORY OPTIONS:"
  echo ""
  echo "  --kconf_clus1=<kubeconfig>           set the kubeconfig for the first cluster"
  echo "  --kconf_clus2=<kubeconfig>           set the kubeconfig for the second cluster"
  echo ""
  echo "  Optional OPTIONS:"
  echo ""
  echo "  --namespace=<namespace>    set the namespace to watch for NSM clients"
  echo "  --mysql                    add mysql replication deployment to demo"
  echo "  --delete                   delete the installation"
  echo "  --nowait                   don't wait for user input prior to moving to next step"
  echo ""
}

NSMISTIODIR=${GOPATH}/src/github.com/nsm-istio
sdir=$(dirname ${0})
HELMDIR=${sdir}/../helm

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
        --namespace=?*)
            NAMESPACE=${i#*=}
            ;;
        --delete)
            DELETE=true
            ;;
        --mysql)
            MYSQL=true
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

if [[ -z ${KCONF_CLUS1} || -z ${KCONF_CLUS2} ]]; then
    echo "ERROR: One or more of kubeconfigs not set."
    usage
    exit 1
fi

clus1_IP=$(kubectl get node --kubeconfig ${KCONF_CLUS1} -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
clus2_IP=$(kubectl get node --kubeconfig ${KCONF_CLUS2} -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
if [[ "${clus1_IP}" == "" ]]; then
    clus1_IP=$(kubectl get node --kubeconfig ${KCONF_CLUS1} --selector='node-role.kubernetes.io/master' -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
fi
if [[ "${clus2_IP}" == "" ]]; then
    clus2_IP=$(kubectl get node --kubeconfig ${KCONF_CLUS2} --selector='node-role.kubernetes.io/master' -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
fi

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

if [[ -n ${MYSQL} ]]; then
    INSTALL_OP=apply
    if [ "${DELETE}" == "true" ]; then
        INSTALL_OP=delete
    fi
    pe "# Install Mysql replica master as vL3 client in cluster 1"
    pc "helm template ${HELMDIR}/mysql-master -n vl3 | kubectl ${INSTALL_OP} --kubeconfig ${KCONF_CLUS1} -f -"
    if [[ "${DELETE}" != "true" ]]; then
        p "# Wait for mysql master to come up"
        kubectl wait --kubeconfig ${KCONF_CLUS1} --timeout=150s --for condition=Ready -l app.kubernetes.io/name=mysql-master pod
        p "# Get mysql master vL3 IP"
        masterPod=$(kubectl get pods --kubeconfig ${KCONF_CLUS1} -l  app.kubernetes.io/name=mysql-master -o jsonpath="{.items[0].metadata.name}")
        masterIP=$(kubectl exec -t ${masterPod} -c kiali --kubeconfig ${KCONF_CLUS1} -- ip a show dev nsm0 | grep inet | awk '{ print $2 }' | cut -d '/' -f 1)
    else
        masterIP="1.1.1.1"
    fi
    pe "# Install Mysql replica slave as vL3 client in cluster 2"
    pc "helm template ${HELMDIR}/mysql-slave -n vl3 --set mysql.replicationMaster=${masterIP} | kubectl ${INSTALL_OP} --kubeconfig ${KCONF_CLUS2} -f -"
    if [[ "${DELETE}" != "true" ]]; then
        p "# Wait for mysql slave to come up"
        kubectl wait --kubeconfig ${KCONF_CLUS2} --timeout=150s --for condition=Ready -l app.kubernetes.io/name=mysql-slave pod
    fi

fi


pe "# Install NSM Client App workload service registry for cluster 1"
pc "KUBECONFIG=${KCONF_CLUS1} ${NSMISTIODIR}/deployments/scripts/nsm_svc_reg_deploy.sh --remotekubeconfig=${KCONF_CLUS1} --svcregkubeconfig=${KCONF_CLUS2} ${DELETE:+--delete}"

pe "# Install NSM Client App workload service registry for cluster 2"
pc "KUBECONFIG=${KCONF_CLUS2} ${NSMISTIODIR}/deployments/scripts/nsm_svc_reg_deploy.sh --remotekubeconfig=${KCONF_CLUS2} --svcregkubeconfig=${KCONF_CLUS1} ${DELETE:+--delete}"

if [[ -z ${DELETE} ]]; then
    # add / remove dummy svc to kind cluster due to Istio not updating listeners without this
    #kubectl create svc --kubeconfig ${SVCREGKUBECONFIG} clusterip foo --tcp=5678:8080 
    #kubectl delete svc --kubeconfig ${SVCREGKUBECONFIG} foo
    echo ""
else
    pe "#Cleanup service registry cluster"
    pc "kubectl delete svc helloworld --kubeconfig ${KCONF_CLUS1}"
    pc "kubectl delete svc helloworld --kubeconfig ${KCONF_CLUS2}"
fi
