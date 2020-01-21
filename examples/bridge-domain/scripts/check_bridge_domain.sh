#!/bin/bash

kubectl wait -n default --timeout=150s --for condition=Ready --all pods

targetIp="10.60.1.1"

#  Ping all the things!
EXIT_VAL=0
for nsc in $(kubectl get pods -n default -o=name | grep simple-client | sed 's@.*/@@'); do
    echo "===== >>>>> PROCESSING ${nsc}  <<<<< ==========="
    for i in {1..10}; do
        EXIT_VAL=0
        echo Try ${i}

        if kubectl exec -n default -it "${nsc}" -- ping -c 1 "${targetIp}" ; then
            echo "NSC ${nsc} with IP ${ip} pinging TargetIP: ${targetIp} successful"
            PingSuccess="true"
        else
            echo "NSC ${nsc} with IP ${ip} pinging TargetIP: ${targetIp} unsuccessful"
            EXIT_VAL=1
        fi

        if [ ${PingSuccess} ]; then
            break
        fi
    done
    if [ -z ${PingSuccess} ]; then
        EXIT_VAL=1
        echo "+++++++==ERROR==ERROR=============================================================================+++++"
        echo "NSC ${nsc} failed ping to a vpn-gateway NetworkService"
        kubectl get pod -n default "${nsc}" -o wide
        echo "POD ${nsc} Network dump -------------------------------"
        kubectl exec -n default -ti "${nsc}" -- ip addr
        echo "+++++++==ERROR==ERROR=============================================================================+++++"
    fi
    
    echo "All check OK. NSC ${nsc} behaving as expected."

    unset PingSuccess
done
exit ${EXIT_VAL}
