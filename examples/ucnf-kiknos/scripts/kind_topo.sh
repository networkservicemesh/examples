#!/usr/bin/env bash

pushd "$(dirname $0)/../../../"
pwd

CLUSTER1=${CLUSTER1:-cl1}
CLUSTER2=${CLUSTER2:-cl2}
VPP_AGENT=${VPP_AGENT:-rastislavszabo/vl3_ucnf-vl3-nse:v4}
NSE_HUB=networkservicemesh
NSE_TAG=kiknos
PULLPOLICY=${PULLPOLICY:-IfNotPresent}
SERVICENAME=${SERVICENAME:-icmp-responder}

if [ "$1" == "--delete" ]; then
  echo "Delete clusters: $CLUSTER1, $CLUSTER2"
  KIND_CLUSTER_NAME=$CLUSTER1 make kind-stop
  KIND_CLUSTER_NAME=$CLUSTER2 make kind-stop
  exit 0
fi

echo "Build ucnf image with kiknos base"
VPP_AGENT=${VPP_AGENT} TAG=kiknos make k8s-universal-cnf-save &
dockerBuildProcess=$!

function installNSM() {
  local cluster=$1; shift

  echo "Helm init: $cluster"
  kubectl config use-context "kind-$cluster"
  SPIRE_ENABLED=false INSECURE=true make helm-init

  echo "Install NSM: $cluster"
  kubectl --context "kind-$cluster" wait -n kube-system --timeout=150s --for condition=Ready --all pods -l app=helm
  SPIRE_ENABLED=false INSECURE=true make helm-install-nsm
}

function startCluster() {
  local cluster=$1; shift

  echo "Start kind clusters: $cluster"
  KIND_CLUSTER_NAME=$cluster make kind-start

  wait $dockerBuildProcess
  echo "Load images into: $cluster"
  KIND_CLUSTER_NAME=$cluster make k8s-universal-cnf-load-images
}

for cluster in "$CLUSTER1" "$CLUSTER2"; do
  startCluster "$cluster" &
done

wait

for cluster in "$CLUSTER1" "$CLUSTER2"; do
  installNSM "$cluster"
done

echo "Install NSE into cluster: $CLUSTER1"
helm template ./examples/ucnf-kiknos/helm/kiknos_vpn_endpoint \
  --set org=${NSE_HUB} --set tag=${NSE_TAG} \
  --set pullPolicy="${PULLPOLICY}" \
  ${IPAMPOOL:+ --set ipam.prefixPool=${IPAMPOOL}} \
  ${IPAMOCTET:+ --set ipam.uniqueOctet=${IPAMOCTET}} \
  ${CNNS_NSRADDR:+ --set cnns.nsr.addr=${CNNS_NSRADDR}} \
  ${CNNS_NSRPORT:+ --set cnns.nsr.port=${CNNS_NSRPORT}} \
  --set nsm.serviceName="${SERVICENAME}" \
  --set aio.network.redInterfaceIP=172.17.0.201 \
  --set aio.network.redInterfaceMAC=02:00:00:00:00:06 \
  --set strongswan.network.remoteAddr=172.17.0.200 \
  --set strongswan.network.localSubnet=172.31.23.0/24 \
  --set strongswan.network.remoteSubnet=172.31.22.0/24 \
  --set ikester.enabled=true \
  --set ikester.network.remoteIP=172.17.0.200 | kubectl --context "kind-$CLUSTER1" apply -f -

echo "Install NSE into cluster: $CLUSTER2"
ip=$(kubectl --context "kind-$CLUSTER2" get nodes \
  --selector='node-role.kubernetes.io/master' \
  -o jsonpath='{ $.items[*].status.addresses[?(@.type=="InternalIP")].address }')
baseaddr="$(echo "${ip}" | cut -d. -f1-3)"
lsv="$(echo "${ip}" | cut -d. -f4)"
lsv=$(( $lsv + 1 ))
helm template ./examples/ucnf-kiknos/helm/kiknos_vpn_endpoint --set org=${NSE_HUB} \
  --set tag=${NSE_TAG} \
  --set pullPolicy="${PULLPOLICY}" \
  ${IPAMPOOL:+ --set ipam.prefixPool=${IPAMPOOL}} \
  ${IPAMOCTET:+ --set ipam.uniqueOctet=${IPAMOCTET}} \
  ${CNNS_NSRADDR:+ --set cnns.nsr.addr=${CNNS_NSRADDR}} \
  ${CNNS_NSRPORT:+ --set cnns.nsr.port=${CNNS_NSRPORT}} \
  --set nsm.serviceName="${SERVICENAME}" \
  --set ikester.network.redInterfaceIP="${baseaddr}.${lsv}" | kubectl --context "kind-$CLUSTER2" apply -f -
wait

kubectl --context "kind-$CLUSTER1" wait -n default --timeout=150s --for condition=Ready --all pods --selector k8s-app &
kubectl --context "kind-$CLUSTER2" wait -n default --timeout=150s --for condition=Ready --all pods --selector networkservicemesh.io/app &
wait

echo "Create hello world pods"
helm template ./examples/ucnf-kiknos/helm/vl3_hello --set nsm.serviceName="$SERVICENAME" | kubectl --context "kind-$CLUSTER1" apply -f -
helm template ./examples/ucnf-kiknos/helm/vl3_hello --set nsm.serviceName="$SERVICENAME" | kubectl --context "kind-$CLUSTER2" apply -f -

kubectl --context "kind-$CLUSTER1" wait -n default --timeout=150s --for condition=Ready --all pods -l app=icmp-responder &
kubectl --context "kind-$CLUSTER2" wait -n default --timeout=150s --for condition=Ready --all pods -l app=icmp-responder &
wait