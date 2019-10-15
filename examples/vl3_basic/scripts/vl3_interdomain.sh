#!/bin/bash

HUB=${HUB:-tiswanso}
TAG=${TAG:-vl3-inter-domain}

INSTALL_OP=${INSTALL_OP:-apply}

sdir=$(dirname ${0})
#echo "$sdir"

NSMDIR=${NSMDIR:-${sdir}/../../../../networkservicemesh}
#echo "$NSMDIR"

MFSTDIR=${MFSTDIR:-${sdir}/../k8s}

KUBEINSTALL="kubectl $INSTALL_OP ${KCONF:+--kubeconfig $KCONF}"

CFGMAP="configmap nsm-vl3"
if [[ "${INSTALL_OP}" == "delete" ]]; then
    echo "delete configmap"
    kubectl delete ${KCONF:+--kubeconfig $KCONF} ${CFGMAP}
else
    kubectl create ${KCONF:+--kubeconfig $KCONF} ${CFGMAP} --from-literal=remote.ip_list=${REMOTE_IP}
fi

echo "---------------Install NSE-------------"
${KUBEINSTALL} -f ${MFSTDIR}/vl3-nse-ucnf.yaml

if [[ "$INSTALL_OP" != "delete" ]]; then
  sleep 20
  kubectl wait ${KCONF:+--kubeconfig $KCONF} --timeout=150s --for condition=Ready -l networkservicemesh.io/app=vl3-nse-ucnf pod
fi

echo "---------------Install hello-------------"
#${KUBEINSTALL} -f ${MFSTDIR}/vl3-hello.yaml
${KUBEINSTALL} -f ${MFSTDIR}/vl3-hello-kiali.yaml

if [[ "$INSTALL_OP" != "delete" ]]; then
  sleep 10
  kubectl wait ${KCONF:+--kubeconfig $KCONF} --timeout=150s --for condition=Ready -l app=helloworld pod
fi
