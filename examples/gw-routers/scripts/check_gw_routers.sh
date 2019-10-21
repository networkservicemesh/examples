#!/bin/bash

kubectl wait -n default --timeout=150s --for condition=Ready --all pods

#  Ping all the things!
EXIT_VAL=0

for gw in $(kubectl get pods -o=name | grep -E "gateway-left" | sed 's@.*/@@'); do
    echo "===== >>>>> PROCESSING ${gw}  <<<<< ==========="
    for i in {1..10}; do
        echo Try ${i}
        for ip in $(kubectl exec -n default -it "${gw}" -- vppctl show int addr | grep L3 | awk '{print $2}'); do
            if [[ "${ip}" == 10.60.1.* ]];then
                lastSegment=$(echo "${ip}" | cut -d . -f 4 | cut -d / -f 1)
                nextOp=$((lastSegment + 1))
                targetIp="10.60.3.${nextOp}"
                endpointName="gateway-right"
            fi

            if [ -n "${targetIp}" ]; then
                # Prime the pump, its normal to get a packet loss due to arp
                kubectl exec -n default -it "${gw}" -- vppctl ping "${targetIp}" repeat 5 > /dev/null 2>&1
                OUTPUT=$(kubectl exec -n default -it "${gw}" -- vppctl ping "${targetIp}" repeat 3)
                echo "${OUTPUT}"
                RESULT=$(echo "${OUTPUT}"| grep "packet loss" | awk '{print $6}')
                if [ "${RESULT}" = "0%" ]; then
                    echo "Left Gateway ${gw} with IP ${ip} pinging ${endpointName} TargetIP: ${targetIp} successful"
                    PingSuccess="true"
                    EXIT_VAL=0
                else
                    echo "Left Gateway ${gw} with IP ${ip} pinging ${endpointName} TargetIP: ${targetIp} unsuccessful"
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
        echo "Left Gateway ${gw} failed to connect to gateway-left"
        kubectl get pod "${gw}" -o wide
        echo "POD ${gw} Network dump -------------------------------"
        kubectl exec -n default -ti "${gw}" -- vppctl show int
        kubectl exec -n default -ti "${gw}" -- vppctl show int addr
        kubectl exec -n default -ti "${gw}" -- vppctl show memif
        echo "+++++++==ERROR==ERROR=============================================================================+++++"
    fi
    unset PingSuccess
done

for gw in $(kubectl get pods -o=name | grep -E "gateway-right" | sed 's@.*/@@'); do
    echo "===== >>>>> PROCESSING ${gw}  <<<<< ==========="
    for i in {1..10}; do
        echo Try ${i}
        for ip in $(kubectl exec -n default -it "${gw}" -- vppctl show int addr | grep L3 | awk '{print $2}'); do
            if [[ "${ip}" == 10.60.3.* ]];then
                lastSegment=$(echo "${ip}" | cut -d . -f 4 | cut -d / -f 1)
                nextOp=$((lastSegment - 1))
                targetIp="10.60.1.${nextOp}"
                endpointName="gateway-left"
            fi

            if [ -n "${targetIp}" ]; then
                OUTPUT=$(kubectl exec -n default -it "${gw}" -- vppctl ping "${targetIp}" repeat 3)
                echo "${OUTPUT}"
                RESULT=$(echo "${OUTPUT}"| grep "packet loss" | awk '{print $6}')
                if [ "${RESULT}" = "0%" ]; then
                    echo "Right Gateway ${gw} with IP ${ip} pinging ${endpointName} TargetIP: ${targetIp} successful"
                    PingSuccess="true"
                    EXIT_VAL=0
                else
                    echo "Right Gateway ${gw} with IP ${ip} pinging ${endpointName} TargetIP: ${targetIp} unsuccessful"
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
        echo "Right Gateway ${gw} failed to connect to gateway-left"
        kubectl get pod "${gw}" -o wide
        echo "POD ${gw} Network dump -------------------------------"
        kubectl exec -n default -ti "${gw}" -- vppctl show int
        kubectl exec -n default -ti "${gw}" -- vppctl show int addr
        kubectl exec -n default -ti "${gw}" -- vppctl show memif
        echo "+++++++==ERROR==ERROR=============================================================================+++++"
    fi
    unset PingSuccess
done

exit ${EXIT_VAL}
