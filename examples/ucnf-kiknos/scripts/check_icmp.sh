#!/bin/bash

#  Ping all the things!
for nsc in $(kubectl get pods -o=name | grep -E "ucnf-client" | sed 's@.*/@@'); do
    echo "===== >>>>> PROCESSING ${nsc}  <<<<< ==========="
    for i in {1..10}; do
        EXIT_VAL=0
        echo Try ${i}
        for ip in $(kubectl exec -it "${nsc}" -c=helloworld -- ip addr | grep nsm0 | grep inet | awk '{print $2}'); do
            if [[ "${ip}" == 172.31.0* ]];then
                lastSegment=$(echo "${ip}" | cut -d . -f 4 | cut -d / -f 1)
                nextOp=$((lastSegment + 1))
                targetIp="172.31.0.${nextOp}"
                endpointName="vpn-endpoint"
            fi

            if [ -n "${targetIp}" ]; then
                # Prime the pump, its normal to get a packet loss due to arp
                kubectl exec -it "${nsc}" -c=helloworld -- ping "${targetIp}" -c 10 > /dev/null 2>&1
                OUTPUT=$(kubectl exec -it "${nsc}" -c=helloworld -- ping "${targetIp}" -c 3)
                echo "${OUTPUT}"
                RESULT=$(echo "${OUTPUT}"| grep "packet loss" | awk '{print $7}')
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
        kubectl exec -ti "${nsc}" -- ip addr
        kubectl exec -ti "${nsc}" -- ip route
        echo "+++++++==ERROR==ERROR=============================================================================+++++"
    fi
    unset PingSuccess
done
exit ${EXIT_VAL}
