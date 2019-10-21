#!/bin/bash

kubectl wait -n default --timeout=150s --for condition=Ready --all pods

CLIENTS="hss p-gw-u pcrf s-gw-c tdf-c"
ENDPOINTS="mme p-gw-c s-gw-u tdf-u"

#  Ping all the things!
EXIT_VAL=0
for client in ${CLIENTS}; do
    for nsc in $(kubectl get pods -n default -o=name | grep -E "${client}" | sed 's@.*/@@'); do
        echo "===== >>>>> PROCESSING ${nsc}  <<<<< ==========="
        for ip in $(kubectl exec -n default -it -c "${client}" "${nsc}" -- ip addr| grep inet | awk '{print $2}'); do
            if [[ "${ip}" == 10.60.*.* ]];then
                firstSegment=$(echo "${ip}" | cut -d . -f 1-3)
                lastSegment=$(echo "${ip}" | cut -d . -f 4 | cut -d / -f 1)
                nextOp=$((lastSegment + 1))
                targetIp="${firstSegment}.${nextOp}"
                # Get the name of its corresponding endpoint pair
                for endpoint in ${ENDPOINTS}; do
                    for nse in $(kubectl get pods -n default -o=name | grep -E "${endpoint}" | sed 's@.*/@@'); do
                        for ip_e in $(kubectl exec -n default -it -c "${endpoint}" "${nse}" -- ip addr| grep inet | awk '{print $2}'); do
                            if [[ "${ip_e}" == "${targetIp}/30" ]];then
                                echo "===== >>>>> ENDPOINT PAIR - ${nse}  <<<<< ==========="
                                endpointName="${nse}"
                            fi
                        done
                    done
                done
            fi
            # Do the actual pinging once we have the target IP address
            if [ -n "${targetIp}" ]; then
                if kubectl exec -n default -it -c "${client}" "${nsc}" -- ping -c 1 "${targetIp}" ; then
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
            echo "NSC ${nsc} failed to connect to the desired ${endpointName} NetworkService"
            kubectl get pod -n default "${nsc}" -o wide
            echo "POD ${nsc} Network dump -------------------------------"
            kubectl exec -n default -ti "${nsc}" -- ip addr
            kubectl exec -n default -ti "${nsc}" ip route
            echo "+++++++==ERROR==ERROR=============================================================================+++++"
        fi
        unset PingSuccess
    done
done
exit ${EXIT_VAL}
