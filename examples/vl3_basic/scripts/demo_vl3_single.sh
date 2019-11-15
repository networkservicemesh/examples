#!/bin/bash

usage() {
  echo "usage: $0 [OPTIONS]"
  echo ""
  echo "  MANDATORY OPTIONS:"
  echo ""
  echo "  --kconf_clus1=<kubeconfig>           set the kubeconfig for the first cluster"
  echo ""
  echo "  Optional OPTIONS:"
  echo ""
  echo "  --mysql                    add mysql replication deployment to demo"
  echo "  --hello                    add helloworld replication deployment to demo"
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
        --delete)
            DELETE=true
            ;;
        --mysql)
            MYSQL=true
            ;;
        --nowait)
            NOWAIT=true
            ;;
        --hello)
            HELLO=true
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

if [[ -z ${KCONF_CLUS1} ]]; then
    echo "ERROR: One or more of kubeconfigs not set."
    usage
    exit 1
fi


########################
# include the magic
########################
DEMOMAGIC=${DEMOMAGIC:-${sdir}/demo-magic.sh}
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

if [[ -z ${DELETE} ]]; then
    p "# Wait for NSM pods to be ready in cluster 1"
    kubectl wait --kubeconfig ${KCONF_CLUS1} --timeout=150s --for condition=Ready -l app=nsmgr-daemonset -n nsm-system pod
    kubectl wait --kubeconfig ${KCONF_CLUS1} --timeout=150s --for condition=Ready -l app=proxy-nsmgr-daemonset -n nsm-system pod
fi

pe "# Install vL3 + helloworld clients in cluster 1"
pc "${DELETE:+INSTALL_OP=delete} KCONF=${KCONF_CLUS1} examples/vl3_basic/scripts/vl3_interdomain.sh ${HELLO:+--hello}"


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
        masterIP=$(kubectl exec -t ${masterPod} -c kali --kubeconfig ${KCONF_CLUS1} -- ip a show dev nsm0 | grep inet | awk '{ print $2 }' | cut -d '/' -f 1)
    else
        masterIP="1.1.1.1"
    fi
    pe "# Install Mysql replica slave as vL3 client in cluster 2"
    pc "helm template ${HELMDIR}/mysql-slave -n vl3 --set mysql.replicationMaster=${masterIP} | kubectl ${INSTALL_OP} --kubeconfig ${KCONF_CLUS1} -f -"
    if [[ "${DELETE}" != "true" ]]; then
        p "# Wait for mysql slave to come up"
        kubectl wait --kubeconfig ${KCONF_CLUS1} --timeout=150s --for condition=Ready -l app.kubernetes.io/name=mysql-slave pod
    fi

fi

if [[ -z ${DELETE} ]]; then
    # add / remove dummy svc to kind cluster due to Istio not updating listeners without this
    #kubectl create svc --kubeconfig ${SVCREGKUBECONFIG} clusterip foo --tcp=5678:8080 
    #kubectl delete svc --kubeconfig ${SVCREGKUBECONFIG} foo
    echo ""
else
    pe "#Cleanup service registry cluster"
    pc "kubectl delete svc helloworld --kubeconfig ${KCONF_CLUS1}"
fi

if [[ "${DELETE}" == "true" ]]; then
    kubectl delete ns nsm-system ${KCONF_CLUS1:+--kubeconfig $KCONF_CLUS1}
fi
