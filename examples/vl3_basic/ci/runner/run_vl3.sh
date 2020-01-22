#!/bin/bash

kubeconfs=$(ls /etc/kubeconfigs)

for kconf in ${kubeconfs}; do
    echo "Cluster = ${kconf}"
    sed -i 's/127.0.0.1:.*/127.0.0.1:6443/g' ${kconf}
    echo "---------------"
    cat ${kconf}
    echo "---------------"
    kubectl get nodes --kubeconfig ${kconf}
done

