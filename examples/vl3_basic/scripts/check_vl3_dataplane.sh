#!/bin/bash

NSMNAMESPACE=${NSMNAMESPACE:-nsm-system}
VL3NAMESPACE=${VL3NAMESPACE:-default}

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
  echo "  --nowait                   don't wait for user input prior to moving to next step"
  echo ""
}

function gatherdata_vppctl_pod {
    local kconf=$1; shift
    local pod=$1; shift
    local ns=$1; shift
    local vppctl_cmd=$@

    echo "---------------------------------------------------------------------"
    echo "kubectl exec -t ${pod} --kubeconfig ${kconf} -n ${ns} -- bash -c \"vppctl ${vppctl_cmd}\""
    kubectl exec -t ${pod} --kubeconfig ${kconf} -n ${ns} -- bash -c "vppctl ${vppctl_cmd}"
    echo
}

function gatherdata_vpp_forwarder {
    local kconf=$1

    local nsmdp_pods=$(kubectl get pods --kubeconfig ${kconf} -n ${NSMNAMESPACE} -o=name | grep nsm-vpp-forwarder | sed 's@.*/@@')

    for dp in $nsmdp_pods; do
        echo "****"
        echo "**** Gathering data for NSM forwarder ${dp}"
        echo "****"
        gatherdata_vppctl_pod ${kconf} ${dp} ${NSMNAMESPACE} "sh int"
        gatherdata_vppctl_pod ${kconf} ${dp} ${NSMNAMESPACE} "sh int addr"
        gatherdata_vppctl_pod ${kconf} ${dp} ${NSMNAMESPACE} "sh mode"
        gatherdata_vppctl_pod ${kconf} ${dp} ${NSMNAMESPACE} "sh vxlan tunnel"
        gatherdata_vppctl_pod ${kconf} ${dp} ${NSMNAMESPACE} "sh ip fib"
    done
}

function gatherdata_vl3_nse {
    local kconf=$1

    local nse_pods=$(kubectl get pods --kubeconfig ${kconf} -n ${VL3NAMESPACE} -o=name | grep vl3-nse | sed 's@.*/@@')

    for nse in $nse_pods; do
        echo "****"
        echo "**** Gathering data for vL3 NSE ${nse}"
        echo "****"
        gatherdata_vppctl_pod ${kconf} ${nse} ${VL3NAMESPACE} "sh int addr"
        gatherdata_vppctl_pod ${kconf} ${nse} ${VL3NAMESPACE} "sh ip fib"
    done
}

function gatherdata_kali {
    local kconf=$1
    local pod=$2
    local cont=kali
    if [[ $# > 2 ]]; then
        cont=$3
    fi
    echo "------pod data for ${pod} in ${kconf} (gathered using ${cont} container)---------"
    echo "**** nsm0 interface info:"
    kubectl exec -t ${pod} -c ${cont} --kubeconfig ${kconf} -- ip a show dev nsm0
    echo 
    echo "**** Route info:"
    kubectl exec -t ${pod} -c ${cont} --kubeconfig ${kconf} -- ip route
    echo
}

function gatherdata_hello {
    local kconf=$1

    hellopods=$(kubectl get pods --kubeconfig ${kconf} -o=name | grep helloworld | sed 's@.*/@@')
    for hellopod in $hellopods; do
        echo "---------------------------------------------------------------------"
        echo "------Helloworld pod data for ${hellopod} in ${kconf}---------"
        gatherdata_kali ${kconf} ${hellopod} helloworld
    done
}

function gatherdata_mysql {
    local kconf=$1

    mysqlpods=$(kubectl get pods --kubeconfig ${kconf} -o=name | grep mysql | sed 's@.*/@@')
    for pod in $mysqlpods; do
        echo "---------------------------------------------------------------------"
        echo "------Mysql pod data for ${pod} in ${kconf}---------"
        gatherdata_kali ${kconf} ${pod}
    done
}


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

echo "------------- Gathering info from NSM VPP dataplane instances from cluster 1 (${KCONF_CLUS1})------------"
gatherdata_vpp_forwarder ${KCONF_CLUS1}
echo "-------------------------"
echo
echo "------------- Gathering info from NSM VPP dataplane instances from cluster 2 (${KCONF_CLUS2})------------"
gatherdata_vpp_forwarder ${KCONF_CLUS2}
echo "-------------------------"
echo
echo "------------- Gathering info from vL3 NSE instances from cluster 1 (${KCONF_CLUS1})------------"
gatherdata_vl3_nse ${KCONF_CLUS1}
echo "-------------------------"
echo
echo "------------- Gathering info from vL3 NSE instances from cluster 2 (${KCONF_CLUS2})------------"
gatherdata_vl3_nse ${KCONF_CLUS2}
echo "-------------------------"
echo
gatherdata_hello ${KCONF_CLUS1}
gatherdata_hello ${KCONF_CLUS2}

gatherdata_mysql ${KCONF_CLUS1}
gatherdata_mysql ${KCONF_CLUS2}
