#!/bin/bash

#
# Prereqs:
#  > kubectl apply -f examples/vl3_basic/k8s/vl3-nse-ucnf.yaml
#  > kubectl apply -f examples/vl3_basic/k8s/vl3-hello.yaml
#
# This validates the helloworld NSCs can communicate over the virtual L3 domain
# setup by the virtual-l3 NSEs.
#
#  - for each helloworld NSC
#     - it discovers the NSM interface IPs in the pod (from 10.60.0.0/16)
#     - for each IP found: issue curl http://<vL3 IP>:5000/hello from within all NSCs
#

#kubectl wait -n default --timeout=150s --for=condition=Ready --all pods
kubectl wait -n default ${KCONF:+--kubeconfig $KCONF} --timeout=150s --for condition=Ready -l networkservicemesh.io/app=vl3-nse-ucnf pod
kubectl wait -n default ${KCONF:+--kubeconfig $KCONF} --timeout=150s --for condition=Ready -l app=helloworld pod

nscs=$(kubectl get pods ${KCONF:+--kubeconfig $KCONF} -o=name | grep helloworld | sed 's@.*/@@')
for nsc in $nscs; do
    echo "===== >>>>> PROCESSING ${nsc}  <<<<< ==========="
    for ip in $(kubectl exec -it "${nsc}" ${KCONF:+--kubeconfig $KCONF} -- ip addr| grep inet | awk '{print $2}'); do
        if [[ "${ip}" == 172.31.*.* ]];then
            ip=$(echo "${ip}" | cut -d / -f 1)
            hello_ips+=(${ip})
        fi
    done
done
for nsc in $nscs; do
    echo "===== >>>>> Checking from ${nsc}  <<<<< ==========="
    for ip in "${hello_ips[@]}"; do
        echo "checking ${ip}"
        result=$(kubectl exec ${KCONF:+--kubeconfig $KCONF} $nsc curl http://${ip}:5000/hello)
        if [[ "${result}" =~ "Hello version:" ]]; then
            echo "Looks good"
        else
            echo "Failed"
        fi
    done
done
echo "All check OK. vL3 NSEs behaving as expected."
exit 0
