#!/bin/bash

kubectl wait -n default --timeout=150s --for condition=Ready --all pods

#  Ping all the things!
EXIT_VAL=0
for nsc in $(kubectl get pods -o=name | grep -E "ucnf-client" | sed 's@.*/@@'); do
    echo "===== >>>>> PROCESSING ${nsc}  <<<<< ==========="
    for i in {1..10}; do
        EXIT_VAL=0
        echo Try ${i}
        for ip in $(kubectl exec -it "${nsc}" -- vppctl show int addr | grep L3 | awk '{print $2}'); do
            if [[ "${ip}" == 10.60.1.* ]];then
                lastSegment=$(echo "${ip}" | cut -d . -f 4 | cut -d / -f 1)
                nextOp=$((lastSegment + 1))
                targetIp="10.60.1.${nextOp}"
                endpointName="ucnf-endpoint"
            fi

            if [ -n "${targetIp}" ]; then
                # Prime the pump, its normal to get a packet loss due to arp
                kubectl exec -it "${nsc}" -- vppctl ping "${targetIp}" repeat 10 > /dev/null 2>&1            
                OUTPUT=$(kubectl exec -it "${nsc}" -- vppctl ping "${targetIp}" repeat 3)
                echo "${OUTPUT}"
                RESULT=$(echo "${OUTPUT}"| grep "packet loss" | awk '{print $6}')
                if [ "${RESULT}" = "0%" ]; then
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
        echo "NSC ${nsc} failed to connect to an icmp-responder NetworkService"
        kubectl get pod "${nsc}" -o wide
        echo "POD ${nsc} Network dump -------------------------------"
        kubectl exec -ti "${nsc}" -- vppctl show int
        kubectl exec -ti "${nsc}" -- vppctl show int addr
        kubectl exec -ti "${nsc}" -- vppctl show memif
        echo "+++++++==ERROR==ERROR=============================================================================+++++"
    fi
    unset PingSuccess
done
exit ${EXIT_VAL}
