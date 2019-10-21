#!/bin/bash

ITERATIONS=${ITERATIONS:-3}
BATCHES=${BATCHES:-1}

kubectl wait -n default --timeout=150s --for condition=Ready --all pods

function call_wget() {
    i="$1"
    nsc="$2"

    for ip in $(kubectl exec -n default -it "${nsc}" -- ip addr| grep inet | awk '{print $2}'); do
        if [[ "${ip}" == 10.60.1.* ]];then
            lastSegment=$(echo "${ip}" | cut -d . -f 4 | cut -d / -f 1)
            nextOp=$((lastSegment + 1))
            targetIp="10.60.1.${nextOp}"
            port=$((1234 + nextOp))
        fi

        if [ -n "${targetIp}" ]; then

            if kubectl exec -n default -it "${nsc}" -- ping -c 1 "${targetIp}" ; then
                echo "${i}. Simple client ${nsc} with IP ${ip} pinging ${targetIp} successful"
            else
                echo "${i}. Simple client ${nsc} with IP ${ip} pinging ${targetIp} unsuccessful"
                exit 1
            fi

            if kubectl exec -n default -it "${nsc}" -- /bin/sh -c "echo LONG STRING | nc -w 2 ${targetIp} ${port}" >/dev/null 2>&1; then
                echo "${i}. Simple client accessing Envoy NS 'web-service' on ${targetIp}:${port} successful"
                exit 0
            else
                echo "${i}. Simple client accessing Envoy NS 'web-service' on ${targetIp}:${port} unsuccessful"
                kubectl get pod -n default "${nsc}" -o wide
                exit 1
            fi
        fi
    done
}

for nsc in $(kubectl get pods -o=name | grep simple-client | sed 's@.*/@@'); do
    echo "===== >>>>> PROCESSING ${nsc}  <<<<< ==========="

    # This loops and calls with "NSM-App: Firewall" header, directly into the gateway
    for ((i=1;i<=ITERATIONS;i=i+BATCHES)); do
        for ((j=i;j<i+BATCHES;++j)); do
            call_wget ${j} "${nsc}"&
            pids[${j}]=$!
        done
        # wait for all pids
        for pid in ${pids[*]}; do
            if ! wait $pid; then
                echo "A subprocess failed"
                exit 1
            fi
        done
    done
done
echo "All check OK. NSC ${nsc} behaving as expected."
exit 0
