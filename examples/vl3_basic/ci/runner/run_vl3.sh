#!/bin/bash

kubeconfs=$(ls /etc/kubeconfigs)

for kconf in ${kubeconfs}; do
    echo "Cluster = ${kconf}"
    #sed -i 's/127.0.0.1:.*/127.0.0.1:6443/g' /etc/kubeconfigs/${kconf}
    #echo "---------------"
    #cat /etc/kubeconfigs/${kconf}
    #echo "---------------"
    kubectl get nodes --kubeconfig /etc/kubeconfigs/${kconf}
    if [[ -z ${KCONF1} ]]; then
        KCONF1=/etc/kubeconfigs/${kconf}
        echo "Cluster 1 is /etc/kubeconfigs/${kconf}"
    elif [[ -z ${KCONF2} ]]; then
        KCONF2=/etc/kubeconfigs/${kconf}
        echo "Cluster 2 is /etc/kubeconfigs/${kconf}"
    fi
    pushd /go/src/github.com/networkservicemesh/examples
    KCONF=/etc/kubeconfigs/${kconf} examples/vl3_basic/scripts/nsm_install_interdomain.sh
    popd
done

pushd /go/src/github.com/networkservicemesh/examples
clus1_IP=$(kubectl get node --kubeconfig ${KCONF1} --selector='node-role.kubernetes.io/master' -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

clus2_IP=$(kubectl get node --kubeconfig ${KCONF2} --selector='node-role.kubernetes.io/master' -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

echo "# **** Install vL3 in cluster 1 (point at cluster2's IP=${clus2_IP})"
REMOTE_IP=${clus2_IP} KCONF=${KCONF1} examples/vl3_basic/scripts/vl3_interdomain.sh --ipamOctet=22

kubectl get pods --kubeconfig ${KCONF1}
kubectl get pods -n nsm-system --kubeconfig ${KCONF1} 

echo "# **** Install vL3 in cluster 2 (point at cluster1's IP=${clus1_IP})"
REMOTE_IP=${clus1_IP} KCONF=${KCONF2} examples/vl3_basic/scripts/vl3_interdomain.sh --ipamOctet=33

kubectl get pods --kubeconfig ${KCONF1}
kubectl get pods -n nsm-system --kubeconfig ${KCONF1} 

echo "# **** Install helloworld on cluster 1"
kubectl apply --kubeconfig ${KCONF1} -f examples/vl3_basic/k8s/vl3-hello.yaml

sleep 60

echo "# **** Install helloworld on cluster 2"
kubectl apply --kubeconfig ${KCONF2} -f examples/vl3_basic/k8s/vl3-hello.yaml

echo "# **** wait on helloworld pods to come up (kali container pull takes a long time)"
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
