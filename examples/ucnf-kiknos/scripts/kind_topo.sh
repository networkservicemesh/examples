#!/usr/bin/env bash

# Topology information
CLUSTER1=${CLUSTER1:-kind-cl1}
CLUSTER2=${CLUSTER2:-kind-cl2}
VPP_AGENT=${VPP_AGENT:-ciscolabs/kiknos:latest}
NSE_ORG=${NSE_ORG:-mmatache}
NSE_TAG=${NSE_TAG:-kiknos}
PULL_POLICY=${PULL_POLICY:-IfNotPresent}
SERVICE_NAME=${SERVICE_NAME:-icmp-responder}

# Script run information
DELETE=${DELETE:-false}
CLEAN=${CLEAN:=false}
CLUSTERS_PRESENT=${CLUSTERS_PRESENT:-false}
NSM_INSTALLED=${NSM_INSTALLED:-false}
ISTIO=${ISTIO:-false}
OPERATION=${OPERATION:-apply}
BUILD_IMAGE=${BUILD_IMAGE:-false}

pushd "$(dirname "$0")/../../../"

print_usage() {
  echo "$(basename "$0") - Deploy NSM Kiknos topology. All properties can also be provided through env variables

NOTE: The defaults will change to the env values for the ones set.

Usage: $(basename "$0") [options...]
Options:
  --cluster1            Name of Kind cluster one - Represents the client network            env var: CLUSTER1         - (Default: $CLUSTER1)
  --cluster2            Name of Kind cluster two - Represents the VPN Gateway               env var: CLUSTER2         - (Default: $CLUSTER2)
  --vpp_agent           Base docker image for NSE                                           env var: VPP_AGENT        - (Default: $VPP_AGENT)
  --org                 Organisation of NSE image                                           env var: NSE_ORG          - (Default: $NSE_ORG)
  --tag                 NSE image tag                                                       env var: NSE_TAG          - (Default: $NSE_TAG)
  --pull_policy         Pull policy for the NSE image                                       env var: PULL_POLICY      - (Default: $PULL_POLICY)
  --service_name        NSM service                                                         env var: SERVICE_NAME     - (Default: $SERVICE_NAME)
  --build_image         Indicates whether the NSE image should be built or just pulled
                        from the image repository                                           env var: BUILD_IMAGE      - (Default: $BUILD_IMAGE)
  --clusters_present    Set if you already have kind clusters present                       env var: CLUSTERS_PRESENT - (Default: $CLUSTERS_PRESENT)
  --nsm_installed       Set if the NSM is already installed on the clusters                 env var: NSM_INSTALLED    - (Default: $NSM_INSTALLED)
  --istio               Set one of the clients to be an istio ingress gateway               env var: ISTIO            - (Default: $ISTIO)
  --clean               Removes the NSEs and Clients from the clusters                      env var: CLEAN            - (Default: $CLEAN)
  --delete              Delete the Kind clusters                                            env var: DELETE           - (Default: $DELETE)
" >&2

}

for i in "$@"; do
  case $i in
  --cluster1=*)
    CLUSTER1="${i#*=}"
    ;;
  --cluster2=*)
    CLUSTER2="${i#*=}"
    ;;
  --vpp_agent=*)
    VPP_AGENT="${i#*=}"
    ;;
  --org=*)
    NSE_ORG="${i#*=}"
    ;;
  --tag=*)
    NSE_TAG="${i#*=}"
    ;;
  --pull_policy=*)
    PULL_POLICY="${i#*=}"
    ;;
  --service_name=*)
    SERVICE_NAME="${i#*=}"
    ;;
  --operation=*)
    OPERATION="${i#*=}"
    ;;
  --istio)
    ISTIO=true
    ;;
  --build_image)
    BUILD_IMAGE=true
    ;;
  --clusters_present)
    CLUSTERS_PRESENT=true
    ;;
  --clean)
    OPERATION=delete
    CLUSTERS_PRESENT=true
    ;;
  --delete)
    DELETE=true
    ;;
  -h | --help)
    print_usage
    exit 0
    ;;
  *)
    print_usage
    exit 1
    ;;
  esac
done

# Start a Kind cluster
function startCluster() {
  local cluster=$1; shift

  echo "Start kind clusters: $cluster"
  kind create cluster --name "$cluster"
}

# Install NSM on the cluster
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

# Perform the given kubectl operation for the NSE
function performNSE() {
  local cluster=$1; shift
  local operation=$1; shift
  local opts=$*
  echo "$operation NSE into cluster: $cluster"
  helm template ./examples/ucnf-kiknos/helm/kiknos_vpn_endpoint \
    --set org="$NSE_ORG" \
    --set tag="$NSE_TAG" \
    --set pullPolicy="$PULL_POLICY" \
    --set nsm.serviceName="$SERVICE_NAME" $opts | kubectl --context "kind-$cluster" "$operation" -f -

  if [ "$operation" == "apply" ]; then
    kubectl --context "kind-$cluster" wait -n default --timeout=150s --for condition=Ready --all pods -l k8s-app
    kubectl --context "kind-$cluster" wait -n default --timeout=150s --for condition=Ready --all pods -l networkservicemesh.io/app
  fi
}

if [ "$DELETE" == "true" ]; then
  echo "Delete clusters: $CLUSTER1, $CLUSTER2"
  KIND_CLUSTER_NAME=$CLUSTER1 make kind-stop
  KIND_CLUSTER_NAME=$CLUSTER2 make kind-stop
  exit 0
fi

if [ "$CLUSTERS_PRESENT" == "false" ]; then
  for cluster in "$CLUSTER1" "$CLUSTER2"; do
    startCluster "$cluster" &
  done

  wait
fi

if [ "$NSM_INSTALLED" == "false" ]; then
  for cluster in "$CLUSTER1" "$CLUSTER2"; do
    installNSM "$cluster"
  done
fi

if [ "$BUILD_IMAGE" == "true" ]; then
  echo "Build ucnf image with kiknos base"
  VPP_AGENT=$VPP_AGENT ORG=$NSE_ORG TAG=$NSE_TAG make k8s-universal-cnf-save

  for cluster in "$CLUSTER1" "$CLUSTER2"; do
      echo "Load images into: $cluster"
      KIND_CLUSTER_NAME=$cluster make k8s-universal-cnf-load-images &
  done
  wait
fi

performNSE "$CLUSTER1" $OPERATION --set strongswan.network.localSubnet=172.31.22.0/24 \
  --set strongswan.network.remoteSubnet=172.31.23.0/24

echo "Retrieving IP and MAC addr of interface"
POD_NAME=$(kubectl --context "$CLUSTER1" get pods -o name | grep icmp-responder | cut -d / -f 2)
IP_ADDR=$(kubectl --context "$CLUSTER1" exec -it "$POD_NAME" -- ip addr | grep "global eth0" | grep inet | awk '{print $2}' | cut -d / -f 1)

performNSE "$CLUSTER2" $OPERATION --set strongswan.network.remoteAddr="$IP_ADDR" \
  --set strongswan.network.localSubnet=172.31.23.0/24 \
  --set strongswan.network.remoteSubnet=172.31.22.0/24

if [ "$ISTIO" == "true" ]; then
  echo "Installing Istio control plane"
  kubectl --context "$CLUSTER1" apply -f ./examples/ucnf-kiknos/k8s/istio_cfg.yaml
  kubectl --context "kind-$cluster" wait -n istio-system --timeout=150s --for condition=Ready --all pods
  rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
  ./examples/ucnf-kiknos/scripts/start_clients.sh --cluster1="$CLUSTER1" --cluster2="$CLUSTER2" --istio_client
else
  ./examples/ucnf-kiknos/scripts/start_clients.sh --cluster1="$CLUSTER1" --cluster2="$CLUSTER2"
fi
rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi

sleep 2
CLUSTER2="$CLUSTER2" SERVICE_NAME="$SERVICE_NAME" ./examples/ucnf-kiknos/scripts/start_vpn.sh
rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi

