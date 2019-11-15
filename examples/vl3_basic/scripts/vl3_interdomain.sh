#!/bin/bash

HUB=${HUB:-tiswanso}
TAG=${TAG:-vl3-inter-domain}
INSTALL_OP=${INSTALL_OP:-apply}

for i in "$@"; do
    case $i in
        -h|--help)
            usage
            exit
            ;;
        --namespace=?*)
            NAMESPACE=${i#*=}
            ;;
        --delete)
            INSTALL_OP=delete
            ;;
        --hello)
            HELLO=true
            ;;
        --nowait)
            NOWAIT=true
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done


sdir=$(dirname ${0})
#echo "$sdir"

NSMDIR=${NSMDIR:-${sdir}/../../../../networkservicemesh}
#echo "$NSMDIR"

MFSTDIR=${MFSTDIR:-${sdir}/../k8s}
VL3_NSEMFST=${MFSTDIR}/vl3-nse-ucnf-single.yaml
if [[ -n ${REMOTE_IP} ]]; then
    VL3_NSEMFST=${MFSTDIR}/vl3-nse-ucnf_deploy.yaml
fi

KUBEINSTALL="kubectl $INSTALL_OP ${KCONF:+--kubeconfig $KCONF}"

CFGMAP="configmap nsm-vl3"
if [[ "${INSTALL_OP}" == "delete" ]]; then
    echo "delete configmap"
    kubectl delete ${KCONF:+--kubeconfig $KCONF} ${CFGMAP}
else
    if [[ -n ${REMOTE_IP} ]]; then
        kubectl create ${KCONF:+--kubeconfig $KCONF} ${CFGMAP} --from-literal=remote.ip_list=${REMOTE_IP}
    fi
fi

echo "---------------Install NSE-------------"
${KUBEINSTALL} -f ${VL3_NSEMFST}

if [[ "$INSTALL_OP" != "delete" ]]; then
  sleep 20
  kubectl wait ${KCONF:+--kubeconfig $KCONF} --timeout=150s --for condition=Ready -l networkservicemesh.io/app=vl3-nse-ucnf pod
fi

if [[ "${HELLO}" == "true" ]]; then
    echo "---------------Install hello-------------"
    #${KUBEINSTALL} -f ${MFSTDIR}/vl3-hello.yaml
    ${KUBEINSTALL} -f ${MFSTDIR}/vl3-hello-kali.yaml

    if [[ "$INSTALL_OP" != "delete" ]]; then
        sleep 10
        kubectl wait ${KCONF:+--kubeconfig $KCONF} --timeout=150s --for condition=Ready -l app=helloworld pod
    fi
fi
