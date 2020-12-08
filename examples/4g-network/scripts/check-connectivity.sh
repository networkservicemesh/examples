#!/bin/bash

kubectl wait -n default --timeout=150s --for condition=Ready --all pods

CLIENTS="hss p-gw-u pcrf s-gw-c tdf-c"
ENDPOINTS="mme p-gw-c s-gw-u tdf-u"

#  Ping all the things!
EXIT_VAL=0
for client in ${CLIENTS}; do
    # This is only applicable to single replica deployments
    nsc=$(kubectl get pods -l=networkservicemesh.io/app=${client} -o jsonpath='{.items[*].metadata.name}')
    echo "===== >>>>> PROCESSING ${nsc}  <<<<< ==========="
    for ip in $(kubectl exec -n default -it -c "${client}" "${nsc}" -- ip addr| grep "inet 10.60" | awk '{print $2}' | uniq); do
        lastSegment=$(echo "${ip##*\.}" | cut -d / -f 1)
        nextOp=$((lastSegment + 1))
        targetIp="${ip%\.*}.${nextOp}"
        # Get the name of its corresponding endpoint pair
        for endpoint in ${ENDPOINTS}; do
            nse=$(kubectl get pods -l=networkservicemesh.io/app=${endpoint} -o jsonpath='{.items[*].metadata.name}')
            for ip_e in $(kubectl exec -n default -it -c "${endpoint}" "${nse}" -- ip addr| grep "inet 10.60" | awk '{print $2}' | uniq ); do
                if [[ "${ip_e}" == "${targetIp}/30" ]];then
                    echo "===== >>>>> ENDPOINT PAIR - ${nse}  <<<<< ==========="
                    endpointName="${nse}"

                    # Do the actual pinging once we have the target IP address
                    if kubectl exec -n default -it -c "${client}" "${nsc}" -- ping -c 1 "${targetIp}" > /dev/null; then
                        echo "NSC ${nsc} with IP ${ip} pinging ${endpointName} TargetIP: ${targetIp} successful"
                    else
                        EXIT_VAL=1
                        echo "NSC ${nsc} with IP ${ip} pinging ${endpointName} TargetIP: ${targetIp} unsuccessful"
                        echo "+++++++==ERROR==ERROR=============================================================================+++++"
                        echo "NSC ${nsc} failed to connect to the desired ${endpointName} NetworkService"
                        kubectl get pod -n default "${nsc}" -o wide
                        echo "Client POD ${nsc} Network dump -------------------------------"
                        kubectl exec -n default -ti "${nsc}" -- ip addr
                        kubectl exec -n default -ti "${nsc}" -- ip route
                        echo "Endpoint POD ${nse} Network dump -------------------------------"
                        kubectl exec -n default -ti "${nse}" -- ip addr
                        kubectl exec -n default -ti "${nse}" -- ip route
                        echo "+++++++==ERROR==ERROR=============================================================================+++++"
                    fi
                fi
            done
        done
    done
done
exit ${EXIT_VAL}