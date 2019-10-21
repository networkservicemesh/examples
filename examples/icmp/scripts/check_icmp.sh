#!/bin/bash

kubectl wait -n default --timeout=150s --for condition=Ready --all pods

#  Ping all the things!
EXIT_VAL=0
for nsc in $(kubectl get -n default pods -o=name | grep -E "simple-client" | sed 's@.*/@@'); do
    echo "===== >>>>> PROCESSING ${nsc}  <<<<< ==========="
    for ip in $(kubectl exec -n default -it "${nsc}" -- ip addr| grep inet | awk '{print $2}'); do
        if [[ "${ip}" == 10.60.1.* ]];then
            lastSegment=$(echo "${ip}" | cut -d . -f 4 | cut -d / -f 1)
            nextOp=$((lastSegment + 1))
            targetIp="10.60.1.${nextOp}"
            endpointName="icmp-responder-nse"
        fi

        if [ -n "${targetIp}" ]; then
            if kubectl exec -n default -it "${nsc}" -- ping -c 1 "${targetIp}" ; then
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

    if [ -z ${PingSuccess} ]; then
        EXIT_VAL=1
        echo "+++++++==ERROR==ERROR=============================================================================+++++"
        echo "NSC ${nsc} failed to connect to an icmp-responder NetworkService"
        kubectl get pod -n default "${nsc}" -o wide
        echo "POD ${nsc} Network dump -------------------------------"
        kubectl exec -n default -ti -n default "${nsc}" -- ip addr
        kubectl exec -n default -ti -n default "${nsc}" ip route
        echo "+++++++==ERROR==ERROR=============================================================================+++++"
    fi
    unset PingSuccess
done
exit ${EXIT_VAL}
