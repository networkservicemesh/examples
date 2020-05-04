#!/usr/bin/env bash

CLUSTER1=${CLUSTER1:-cl1}
CLUSTER2=${CLUSTER2:-cl2}
VPP_AGENT=${VPP_AGENT:-ciscolabs/kiknos:latest}
NSE_ORG=${NSE_ORG:-networkservicemesh}
NSE_TAG=${NSE_TAG:-kiknos}
PULL_POLICY=${PULL_POLICY:-IfNotPresent}
SERVICE_NAME=${SERVICE_NAME:-icmp-responder}

pushd "$(dirname "$0")/../../../"

if [ "$1" == "cleanup" ]; then
  echo "Delete clusters: $CLUSTER1, $CLUSTER2"
  KIND_CLUSTER_NAME=$CLUSTER1 make kind-stop
  KIND_CLUSTER_NAME=$CLUSTER2 make kind-stop
  exit 0
fi

echo "Build ucnf image with kiknos base"
VPP_AGENT=$VPP_AGENT ORG=$NSE_ORG TAG=$NSE_TAG make k8s-universal-cnf-save &
dockerBuildProcess=$!

function startCluster() {
  local cluster=$1; shift

  echo "Start kind clusters: $cluster"
  kind create cluster --name "$cluster"

  wait $dockerBuildProcess
  echo "Load images into: $cluster"
  KIND_CLUSTER_NAME=$cluster make k8s-universal-cnf-load-images
}

function installNSM() {
  local cluster=$1; shift

  echo "Helm init: $cluster"
  kubectl config use-context "kind-$cluster"
  SPIRE_ENABLED=false INSECURE=true make helm-init

  echo "Install NSM: $cluster"
  kubectl --context "kind-$cluster" wait -n kube-system --timeout=150s --for condition=Ready --all pods -l app=helm
  SPIRE_ENABLED=false INSECURE=true make helm-install-nsm
  kubectl wait --context "kind-$cluster" --timeout=150s --for condition=Ready -l "app in (nsm-admission-webhook,nsmgr-daemonset,proxy-nsmgr-daemonset,nsm-vpp-plane)" -n nsm-system pod
}

function installNSE() {
  local cluster=$1; shift
  local opts=$*

  echo "TEST: $opts"

  echo "Install NSE into cluster: $cluster"
  helm template ./examples/ucnf-kiknos/helm/kiknos_vpn_endpoint \
    --set org="$NSE_ORG" \
    --set tag="$NSE_TAG" \
    --set pullPolicy="$PULL_POLICY" \
    --set nsm.serviceName="$SERVICE_NAME" $opts | kubectl --context "kind-$cluster" apply -f -

  kubectl --context "kind-$cluster" wait -n default --timeout=150s --for condition=Ready --all pods -l k8s-app
  kubectl --context "kind-$cluster" wait -n default --timeout=150s --for condition=Ready --all pods -l networkservicemesh.io/app
}

for cluster in "$CLUSTER1" "$CLUSTER2"; do
  startCluster "$cluster" &
done

wait

for cluster in "$CLUSTER1" "$CLUSTER2"; do
  installNSM "$cluster"
done

CLUSTER1_IP=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$CLUSTER1-control-plane")
CLUSTER1_MAC=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.MacAddress}}{{end}}' "$CLUSTER1-control-plane")
CLUSTER2_IP=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$CLUSTER2-control-plane")

installNSE "$CLUSTER1" --set strongswan.network.localSubnet=172.31.22.0/24 \
  --set strongswan.network.remoteSubnet=172.31.23.0/24 \
  --set ikester.network.redInterfaceIP="$CLUSTER2_IP"

installNSE "$CLUSTER2" --set strongswan.network.remoteAddr="$CLUSTER1_IP" \
  --set strongswan.network.localSubnet=172.31.23.0/24 \
  --set strongswan.network.remoteSubnet=172.31.22.0/24 \
  --set ikester.enabled=true \
  --set ikester.network.remoteIP="$CLUSTER1_IP" \
  --set ikester.network.remoteMAC="$CLUSTER1_MAC"

helm template ./examples/ucnf-kiknos/helm/vl3_hello --set nsm.serviceName="$SERVICE_NAME" | kubectl --context "kind-$CLUSTER1" apply -f -
helm template ./examples/ucnf-kiknos/helm/vl3_hello --set nsm.serviceName="$SERVICE_NAME" | kubectl --context "kind-$CLUSTER2" apply -f -

kubectl --context "kind-$CLUSTER1" wait -n default --timeout=150s --for condition=Ready --all pods -l app=icmp-responder &
kubectl --context "kind-$CLUSTER2" wait -n default --timeout=150s --for condition=Ready --all pods -l app=icmp-responder &
wait

nsePod=$(kubectl --context "kind-$CLUSTER2" get pods -l "networkservicemesh.io/app=${SERVICE_NAME}" -o=name)
kubectl --context "kind-$CLUSTER2" exec -it "$nsePod" -- ipsec up kiknos
