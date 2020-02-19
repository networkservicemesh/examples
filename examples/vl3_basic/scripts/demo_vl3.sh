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
  echo "  --svcreg                   install NSM-dns service registry"
  echo "  --delete                   delete the installation"
  echo "  --nowait                   don't wait for user input prior to moving to next step"
  echo ""
}

NSMISTIODIR=${GOPATH}/src/github.com/nsm-istio
sdir=$(dirname ${0})
HELMDIR=${sdir}/../helm
MFSTDIR=${MFSTDIR:-${sdir}/../k8s}
CNNSNSR=foo.com

for i in "$@"; do
    case $i in
        -h|--help)
            usage
            exit
            ;;
        --kconf_clus1=?*)
            KCONF_CLUS1=${i#*=}
            echo "setting cluster 1=${KCONF_CLUS1}" 
            ;;
        --kconf_clus2=?*)
            KCONF_CLUS2=${i#*=}
            echo "setting cluster 2=${KCONF_CLUS2}" 
            ;;
        --cnnsNsrAddr=?*)
            CNNS_NSRADDR=${i#*=}
            ;;
        --cnnsNsrPort=?*)
            CNNS_NSRPORT=${i#*=}
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
        --svcreg)
            SVCREG=true
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

echo
p "# --------------------- NSM Installation + Inter-domain Setup ------------------------"

pe "# **** Install NSM in cluster 1"
pc "${DELETE:+INSTALL_OP=delete} KCONF=${KCONF_CLUS1} examples/vl3_basic/scripts/nsm_install_interdomain.sh"
echo
pe "# **** Install NSM in cluster 2"
pc "${DELETE:+INSTALL_OP=delete} KCONF=${KCONF_CLUS2} examples/vl3_basic/scripts/nsm_install_interdomain.sh"
echo
if [[ -z ${DELETE} ]]; then
    p "# **** Wait for NSM pods to be ready in cluster 1"
    kubectl wait --kubeconfig ${KCONF_CLUS1} --timeout=150s --for condition=Ready -l app=nsm-admission-webhook -n nsm-system pod
    kubectl wait --kubeconfig ${KCONF_CLUS1} --timeout=150s --for condition=Ready -l app=nsmgr-daemonset -n nsm-system pod
    kubectl wait --kubeconfig ${KCONF_CLUS1} --timeout=150s --for condition=Ready -l app=proxy-nsmgr-daemonset -n nsm-system pod
    kubectl wait --kubeconfig ${KCONF_CLUS1} --timeout=150s --for condition=Ready -l app=nsm-vpp-plane -n nsm-system pod

    echo
    p "# **** Show NSM pods in cluster 1"
    pc "kubectl get pods --kubeconfig ${KCONF_CLUS1} -n nsm-system -o wide"
    echo
    p "# **** Wait for NSM pods to be ready in cluster 2"
    kubectl wait --kubeconfig ${KCONF_CLUS2} --timeout=150s --for condition=Ready -l app=nsm-admission-webhook -n nsm-system pod
    kubectl wait --kubeconfig ${KCONF_CLUS2} --timeout=150s --for condition=Ready -l app=nsmgr-daemonset -n nsm-system pod
    kubectl wait --kubeconfig ${KCONF_CLUS2} --timeout=150s --for condition=Ready -l app=proxy-nsmgr-daemonset -n nsm-system pod
    kubectl wait --kubeconfig ${KCONF_CLUS2} --timeout=150s --for condition=Ready -l app=nsm-vpp-plane -n nsm-system pod

    echo
    p "# **** Show NSM pods in cluster 2"
    pc "kubectl get pods --kubeconfig ${KCONF_CLUS2} -n nsm-system -o wide"
    echo
fi

p "# --------------------- Virtual L3 Setup ------------------------"

pe "# **** Install vL3 in cluster 1"
pc "${DELETE:+INSTALL_OP=delete} REMOTE_IP=${clus2_IP} KCONF=${KCONF_CLUS1} PULLPOLICY=Always examples/vl3_basic/scripts/vl3_interdomain.sh --ipamOctet=22 ${CNNS_NSRADDR:+--cnnsNsrAddr=${CNNS_NSRADDR}} ${CNNS_NSRPORT:+--cnnsNsrPort=${CNNS_NSRPORT}}"
pc "kubectl get pods --kubeconfig ${KCONF_CLUS1} -o wide"
echo
pe "# **** Install vL3  in cluster 2"
pc "${DELETE:+INSTALL_OP=delete} REMOTE_IP=${clus1_IP} KCONF=${KCONF_CLUS2} PULLPOLICY=Always examples/vl3_basic/scripts/vl3_interdomain.sh --ipamOctet=33 ${CNNS_NSRADDR:+--cnnsNsrAddr=${CNNS_NSRADDR}} ${CNNS_NSRPORT:+--cnnsNsrPort=${CNNS_NSRPORT}}"
#pc "kubectl get pods --kubeconfig ${KCONF_CLUS2} -o wide"
echo
p "# **** Virtual L3 service definition (CRD) ***"
pe "cat examples/vl3_basic/k8s/vl3-service.yaml"
echo
p "# **** Cluster 1 vL3 NSEs"
pe "kubectl get pods --kubeconfig ${KCONF_CLUS1} -l networkservicemesh.io/app=vl3-nse-ucnf -o wide"
echo
p "# **** Cluster 2 vL3 NSEs"
pc "kubectl get pods --kubeconfig ${KCONF_CLUS2} -l networkservicemesh.io/app=vl3-nse-ucnf -o wide"
echo

if [[ -n ${HELLO} ]]; then
    INSTALL_OP=apply
    if [ "${DELETE}" == "true" ]; then
        INSTALL_OP=delete
    fi

    p "# **** Install helloworld in cluster 1 ****"
    pe "kubectl ${INSTALL_OP} --kubeconfig ${KCONF_CLUS1} -f ${MFSTDIR}/vl3-hello-kali.yaml"

    if [[ "$INSTALL_OP" != "delete" ]]; then
        sleep 10
        kubectl wait --kubeconfig ${KCONF_CLUS1} --timeout=150s --for condition=Ready -l app=helloworld pod
    fi

    p "# **** Install helloworld in cluster 2 ****"
    pe "kubectl ${INSTALL_OP} --kubeconfig ${KCONF_CLUS2} -f ${MFSTDIR}/vl3-hello-kali.yaml"

    if [[ "$INSTALL_OP" != "delete" ]]; then
        sleep 10
        kubectl wait --kubeconfig ${KCONF_CLUS2} --timeout=150s --for condition=Ready -l app=helloworld pod
    fi
fi

if [[ -n ${MYSQL} ]]; then
    INSTALL_OP=apply
    if [ "${DELETE}" == "true" ]; then
        INSTALL_OP=delete
    fi
    pe "# Install Mysql replica master as vL3 client in cluster 1"
    pe "helm template ${HELMDIR}/mysql-master -n vl3 | kubectl ${INSTALL_OP} --kubeconfig ${KCONF_CLUS1} -f -"
    if [[ "${DELETE}" != "true" ]]; then
        p "# **** NSM service mapping info **** "
        p "# NOTE: the vl3-mysql-master deployment has the annotation ns.networkservicemesh.io set to vl3-service"
        pe "kubectl get deployment vl3-mysql-master --kubeconfig ${KCONF_CLUS1} -o json | jq '.metadata.annotations'"
        echo

        p "# Wait for mysql master to come up"
        kubectl wait --kubeconfig ${KCONF_CLUS1} --timeout=300s --for condition=Ready -l app.kubernetes.io/name=mysql-master pod
        p "# Get mysql master vL3 IP"
        pe "kubectl get pods --kubeconfig ${KCONF_CLUS1} -l  app.kubernetes.io/name=mysql-master -o wide"

        echo
        masterPod=$(kubectl get pods --kubeconfig ${KCONF_CLUS1} -l  app.kubernetes.io/name=mysql-master -o jsonpath="{.items[0].metadata.name}")
        masterIP=$(kubectl exec -t ${masterPod} -c kali --kubeconfig ${KCONF_CLUS1} -- ip a show dev nsm0 | grep inet | awk '{ print $2 }' | cut -d '/' -f 1)
        echo
        pe "kubectl exec -t ${masterPod} -c kali --kubeconfig ${KCONF_CLUS1} -- ip a show dev nsm0"
        pc "# mysql master vL3 IP = ${masterIP}"
        echo
    else
        masterIP="1.1.1.1"
    fi
    if [[ "${DELETE}" != "true" ]]; then
        sleep 30
    fi
    pe "# **** Install Mysql replica slave as vL3 client in cluster 2"
    pe "helm template ${HELMDIR}/mysql-slave -n vl3 --set mysql.replicationMaster=${masterIP} | kubectl ${INSTALL_OP} --kubeconfig ${KCONF_CLUS2} -f -"
    echo
    if [[ "${DELETE}" != "true" ]]; then
        p "# **** NSM service mapping info **** "
        p "# NOTE: the vl3-mysql-slave deployment has the annotation ns.networkservicemesh.io set to vl3-service"
        pe "kubectl get deployment vl3-mysql-slave --kubeconfig ${KCONF_CLUS2} -o json | jq '.metadata.annotations'"
        echo
        p "# **** NOTE: the vl3-mysql-slave is finding mysql-master at the NSM vL3 addr ${masterIP}"
        pe "kubectl get pods --kubeconfig ${KCONF_CLUS2} -l app.kubernetes.io/name=mysql-slave -o json | jq '.items[0].spec.containers[0].env'"
        echo
        #  | select(.name==\"MYSQL_MASTER_SERVICE_HOST\")

        p "# Wait for mysql slave to come up"
        kubectl wait --kubeconfig ${KCONF_CLUS2} --timeout=300s --for condition=Ready -l app.kubernetes.io/name=mysql-slave pod
        pc "kubectl get pods --kubeconfig ${KCONF_CLUS2} -l app.kubernetes.io/name=mysql-slave -o wide"
        echo ""
    fi

fi

if [[ "${SVCREG}" == "true" ]]; then
    pe "# Install NSM Client App workload service registry for cluster 1"
    pc "KUBECONFIG=${KCONF_CLUS1} ${NSMISTIODIR}/deployments/scripts/nsm_svc_reg_deploy.sh --remotekubeconfig=${KCONF_CLUS1} --svcregkubeconfig=${KCONF_CLUS2} ${DELETE:+--delete}"

    pe "# Install NSM Client App workload service registry for cluster 2"
    pc "KUBECONFIG=${KCONF_CLUS2} ${NSMISTIODIR}/deployments/scripts/nsm_svc_reg_deploy.sh --remotekubeconfig=${KCONF_CLUS2} --svcregkubeconfig=${KCONF_CLUS1} ${DELETE:+--delete}"
fi

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

if [[ "${DELETE}" == "true" ]]; then
    kubectl delete ns nsm-system ${KCONF_CLUS1:+--kubeconfig $KCONF_CLUS1}
    kubectl delete ns nsm-system ${KCONF_CLUS2:+--kubeconfig $KCONF_CLUS2}
fi
