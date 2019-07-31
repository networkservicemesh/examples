#!/bin/bash

kubectl wait -n default --timeout=150s --for condition=Ready --all pods

#  Ping all the things!
EXIT_VAL=0
for nsc in $(kubectl get pods -o=name | grep simple-client | sed 's@.*/@@'); do
    echo "===== >>>>> PROCESSING ${nsc}  <<<<< ==========="
    for i in {1..10}; do
        echo Try ${i}
        for ip in $(kubectl exec -it "${nsc}" -- ip addr| grep inet | awk '{print $2}'); do
            if [[ "${ip}" == 10.60.3.* ]];then
                lastSegment=$(echo "${ip}" | cut -d . -f 4 | cut -d / -f 1)
                nextOp=$((lastSegment + 1))
                targetIp="10.60.2.${nextOp}"
                endpointName="vpn-gateway-nse"
            fi

            if [ -n "${targetIp}" ]; then
                if kubectl exec -it "${nsc}" -- ping -A -c 10 "${targetIp}" ; then
                    echo "NSC ${nsc} with IP ${ip} pinging ${endpointName} TargetIP: ${targetIp} successful"
                    PingSuccess="true"
                else
                    echo "NSC ${nsc} with IP ${ip} pinging ${endpointName} TargetIP: ${targetIp} unsuccessful"
                    EXIT_VAL=1
                fi

                unset targetIp
                unset endpointName
            fi
        done
        if [ ${PingSuccess} ]; then
            break
        fi
        sleep 2
    done
    if [ -z ${PingSuccess} ]; then
        EXIT_VAL=1
        echo "+++++++==ERROR==ERROR=============================================================================+++++"
        echo "NSC ${nsc} failed ping to a vpn-gateway NetworkService"
        kubectl get pod "${nsc}" -o wide
        echo "POD ${nsc} Network dump -------------------------------"
        kubectl exec -ti "${nsc}" -- ip addr
        echo "+++++++==ERROR==ERROR=============================================================================+++++"
    fi

    echo "All check OK. NSC ${nsc} behaving as expected."

    unset PingSuccess
done
exit ${EXIT_VAL}
