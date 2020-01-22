#!/bin/bash

# Description:  Install NSM and vL3 in 2 k8s clusters. (Assumes just 2 k8s clusters)
#               Use helloworld container as NSC for vL3 connectivity check.
#               - Find nsm0 interface in each NSC and performs curl from one helloworld
#                 NSC to other's nsm0 intf IP.
#
# env:
#   KUBECONFDIR -- dir with 2 kubeconfig files, default = /etc/kubeconfigs
#   VL3_IMGTAG -- image tag for vL3 NSE container
#

KUBECONFDIR=${KUBECONFDIR:-/etc/kubeconfigs}

kubeconfs=$(ls ${KUBECONFDIR})

for kconf in ${kubeconfs}; do
    echo "Cluster = ${kconf}"
    #sed -i 's/127.0.0.1:.*/127.0.0.1:6443/g' ${KUBECONFDIR}/${kconf}
    #echo "---------------"
    #cat ${KUBECONFDIR}/${kconf}
    #echo "---------------"
    kubectl get nodes --kubeconfig ${KUBECONFDIR}/${kconf}
    if [[ -z ${KCONF1} ]]; then
        KCONF1=${KUBECONFDIR}/${kconf}
        echo "Cluster 1 is ${KUBECONFDIR}/${kconf}"
    elif [[ -z ${KCONF2} ]]; then
        KCONF2=${KUBECONFDIR}/${kconf}
        echo "Cluster 2 is ${KUBECONFDIR}/${kconf}"
    fi
    pushd /go/src/github.com/networkservicemesh/examples
    KCONF=${KUBECONFDIR}/${kconf} examples/vl3_basic/scripts/nsm_install_interdomain.sh
    popd
done

echo "# **** Wait for NSM pods to be ready in each cluster"
for kconf in ${KCONF1} ${KCONF2}; do
    echo "# **** Waiting on cluster ${kconf}"
    kubectl wait --kubeconfig ${kconf} --timeout=150s --for condition=Ready -l app=nsm-admission-webhook -n nsm-system pod
    kubectl wait --kubeconfig ${kconf} --timeout=150s --for condition=Ready -l app=nsmgr-daemonset -n nsm-system pod
    kubectl wait --kubeconfig ${kconf} --timeout=150s --for condition=Ready -l app=proxy-nsmgr-daemonset -n nsm-system pod
    kubectl wait --kubeconfig ${kconf} --timeout=150s --for condition=Ready -l app=nsm-vpp-plane -n nsm-system pod
    echo "# **** NSM Pods in cluster ${kconf}"
    kubectl get pods --kubeconfig ${kconf} -n nsm-system -o wide
done

pushd /go/src/github.com/networkservicemesh/examples
clus1_IP=$(kubectl get node --kubeconfig ${KCONF1} --selector='node-role.kubernetes.io/master' -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

clus2_IP=$(kubectl get node --kubeconfig ${KCONF2} --selector='node-role.kubernetes.io/master' -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

echo "# **** Install vL3 in cluster 1 (point at cluster2's IP=${clus2_IP})"
REMOTE_IP=${clus2_IP} KCONF=${KCONF1} TAG=${VL3_IMGTAG} examples/vl3_basic/scripts/vl3_interdomain.sh --ipamOctet=22

kubectl describe deployment vl3-nse-ucnf --kubeconfig ${KCONF1}
kubectl get pods --kubeconfig ${KCONF1}
#kubectl get pods -n nsm-system --kubeconfig ${KCONF1}

echo "# **** Install vL3 in cluster 2 (point at cluster1's IP=${clus1_IP})"
REMOTE_IP=${clus1_IP} KCONF=${KCONF2} TAG=${VL3_IMGTAG} examples/vl3_basic/scripts/vl3_interdomain.sh --ipamOctet=33

kubectl describe deployment vl3-nse-ucnf --kubeconfig ${KCONF2}
kubectl get pods --kubeconfig ${KCONF2}
#kubectl get pods -n nsm-system --kubeconfig ${KCONF2}

echo "# **** Install helloworld on cluster 1"
kubectl apply --kubeconfig ${KCONF1} -f examples/vl3_basic/k8s/vl3-hello.yaml

sleep 60

echo "# **** Install helloworld on cluster 2"
kubectl apply --kubeconfig ${KCONF2} -f examples/vl3_basic/k8s/vl3-hello.yaml

echo "# **** wait on helloworld pods to come up"
kubectl wait --kubeconfig ${KCONF1} --timeout=600s --for condition=Ready -l app=helloworld pod
kubectl wait --kubeconfig ${KCONF2} --timeout=600s --for condition=Ready -l app=helloworld pod

K1_PODNM=$(kubectl get pods --kubeconfig ${KCONF1} -l "app=helloworld" -o jsonpath="{.items[0].metadata.name}")
K2_PODNM=$(kubectl get pods --kubeconfig ${KCONF2} -l "app=helloworld" -o jsonpath="{.items[0].metadata.name}")

K1_PODIP=$(kubectl exec -t $K1_PODNM -c helloworld --kubeconfig ${KCONF1} -- ip a show dev nsm0 | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}')

K2_PODIP=$(kubectl exec -t $K2_PODNM -c helloworld --kubeconfig ${KCONF2} -- ip a show dev nsm0 | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}')

echo "# **** Cluster 1 pod ${K1_PODNM} nsm0 IP = ${K1_PODIP}"
echo "# **** Cluster 2 pod ${K2_PODNM} nsm0 IP = ${K2_PODIP}"

echo "# **** Check helloworld response from remote's nsm0 interface -- curl http://${K2_PODIP}:5000/hello" 
cmdout=$(kubectl exec -t $K1_PODNM -c helloworld --kubeconfig ${KCONF1} curl http://${K2_PODIP}:5000/hello)
echo $cmdout

# cmd return 0 for success, 1 failure
echo $cmdout | grep ${K2_PODNM}
