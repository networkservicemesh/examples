#!/bin/bash

ITERATIONS=${ITERATIONS:-3}
BATCHES=${BATCHES:-1}

function call_wget() {
    i="$1"
    nsc="$2"
    color=$3

    html=$(kubectl exec -it "${nsc}" -- wget --header="NSM-Color: ${color}" -O - localhost:8080 2>/dev/null)

    if echo ${html} | grep ${color} >/dev/null 2>&1 ; then
        echo "${i}. Proxy NSC accessing 'web-service' successful"
        exit 0
    else
        echo "Proxy NSC accessing 'web-service' unsuccessful"
        kubectl get pod "${nsc}" -o wide
        exit 1
    fi
}

for nsc in $(kubectl get pods -o=name | grep proxy-nsc | sed 's@.*/@@'); do
    echo "===== >>>>> PROCESSING ${nsc}  <<<<< ==========="

    # This loops and calls with "NSM-App: Firewall" header, directly into the gateway
    for ((i=1;i<=ITERATIONS;i=i+BATCHES)); do
        for ((j=i;j<i+BATCHES;++j)); do
            call_wget ${j} "${nsc}" "Red" &
            pids[${j}]=$!
            call_wget ${j} "${nsc}" "Green" &
            pids[${j}]=$!
            call_wget ${j} "${nsc}" "Blue" &
            pids[${j}]=$!
        done
        # wait for all pids
        for pid in ${pids[*]}; do
            if ! wait $pid; then
                echo "A subprocess failed"
                exit 1
            fi
        done
        # sleep 1
    done
done
echo "All check OK. NSC ${nsc} behaving as expected."
exit 0