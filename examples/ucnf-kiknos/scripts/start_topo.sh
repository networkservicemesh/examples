#!/usr/bin/env bash

# Topology information
CLUSTER1=${CLUSTER1:-kiknos-demo-1}
CLUSTER2=${CLUSTER2:-kiknos-demo-2}
VPP_AGENT=${VPP_AGENT:-ciscolabs/kiknos:latest}
NSE_ORG=${NSE_ORG:-mmatache}
NSE_TAG=${NSE_TAG:-kiknos}
PULL_POLICY=${PULL_POLICY:-IfNotPresent}
SERVICE_NAME=${SERVICE_NAME:-hello-world}
AWS_KEY_PAIR=${KEY_PAIR:-kiknos-asa}

# Script run information
DELETE=${DELETE:-false}
CLEAN=${CLEAN:=false}
CLUSTERS_PRESENT=${CLUSTERS_PRESENT:-false}
NSM_INSTALLED=${NSM_INSTALLED:-false}
OPERATION=${OPERATION:-apply}
BUILD_IMAGE=${BUILD_IMAGE:-false}
KIND_LOAD=${KIND_LOAD:-true}
PUSH_IMAGE=${PUSH_IMAGE:-false}
AWS=${AWS:-false}
DEPLOY_ASA=${DEPLOY_ASA:-false}
DRY_RUN=${DRY_RUN:-false}
NO_ISTIO=${NO_ISTIO:-false}

pushd "$(dirname "${BASH_SOURCE[0]}")/../../../" || exit 1

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
  --aws_key_pair        Key Pair used for SSH on AWS EC2 instance                           env var: AWS_KEY_PAIR     - (Default: $AWS_KEY_PAIR)
  --build_image         Indicates whether the NSE image should be built or just pulled
                        from the image repository                                           env var: BUILD_IMAGE      - (Default: $BUILD_IMAGE)
  --push_image          Indicates whether the build image should be pushed
                        (works only with --build_image option)                              env var: PUSH_IMAGE       - (Default: $PUSH_IMAGE)
  --kind_load           Loads the built image into kind clusters
                        (works only with --build_image option and without --aws option)     env var: KIND_LOAD        - (Default: $KIND_LOAD)
  --clusters_present    Set if you already have kind clusters present                       env var: CLUSTERS_PRESENT - (Default: $CLUSTERS_PRESENT)
  --nsm_installed       Set if the NSM is already installed on the clusters                 env var: NSM_INSTALLED    - (Default: $NSM_INSTALLED)
  --clean               Removes the NSEs and Clients from the clusters                      env var: CLEAN            - (Default: $CLEAN)
  --delete              Delete the Kind clusters                                            env var: DELETE           - (Default: $DELETE)
  --aws                 Creates aws clusters (requires python >= v2.7 and eksctl v0.18.0)   env var: AWS              - (Default: $AWS)
  --deploy_asa          Creates an ASAv instance in an aws environment                      env var: DEPLOY_ASA       - (Default: $DEPLOY_ASA)
  --dry_run             Display commands instead of executing them (useful for debugging)   env var: DRY_RUN          - (Default: $DRY_RUN)
  --no_istio            Set if you do not want the istio service mesh to be deployed        env var: NO_ISTIO         - (Default: $ISTIO)
  --help -h             Help
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
  --aws_key_pair=*)
    AWS_KEY_PAIR="${i#*=}"
    ;;
  --build_image)
    BUILD_IMAGE=true
    ;;
  --clusters_present)
    CLUSTERS_PRESENT=true
    ;;
  --deploy_asa)
    DEPLOY_ASA=true
    ;;
  --clean)
    OPERATION=delete
    CLUSTERS_PRESENT=true
    ;;
  --delete)
    DELETE=true
    ;;
  --push_image)
    PUSH_IMAGE=true
    ;;
  --kind_load)
    KIND_LOAD=true
    ;;
  --aws)
    AWS=true
    ;;
  --dry_run)
    DRY_RUN=true
    ;;
   --no_istio)
    NO_ISTIO=true
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

if [ $DRY_RUN == "true" ]; then
  source ./examples/ucnf-kiknos/scripts/dry_run.sh
fi

if [ $AWS == "true" ]; then
  KIND_LOAD=false
  FIRST_CLUSTER=""
  # Start a AWS cluster
  function startCluster() {
    local cluster=$1; shift
    ref=""
    # Use the first cluster as a reference for the next cluster in order to have the same VPC
    if [ -z $FIRST_CLUSTER ]; then
      FIRST_CLUSTER=$cluster
    else
      ref="--ref $FIRST_CLUSTER"
    fi

    python ./examples/ucnf-kiknos/scripts/pyaws/create_cluster.py --name "$cluster" $ref --cidr "$CIDR" --open-sg
    rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
    aws eks update-kubeconfig --name="$cluster" --alias "$cluster"
  }
else
  # Start a Kind cluster
  function startCluster() {
    local cluster=$1; shift

    echo "# Start kind clusters: $cluster"
    kind create cluster --name "$cluster"
    rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
  }
fi

# Install NSM on the cluster
function installNSM() {
  local cluster=$1; shift

  echo "# Helm init: $cluster"
  kubectl config use-context "$cluster"
  SPIRE_ENABLED=false INSECURE=true make helm-init

  echo "# Install NSM: $cluster"
  kubectl --context "$cluster" wait -n kube-system --timeout=150s --for condition=Ready --all pods -l app=helm
  SPIRE_ENABLED=false INSECURE=true make helm-install-nsm
  kubectl wait --context "$cluster" --timeout=150s --for condition=Ready -l "app in (nsm-admission-webhook,nsmgr-daemonset,proxy-nsmgr-daemonset,nsm-vpp-plane)" -n nsm-system pod
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
    --set nsm.serviceName="$SERVICE_NAME" $opts | kubectl --context "$cluster" "$operation" -f -

  if [ "$operation" == "apply" ]; then
    kubectl --context "$cluster" wait -n default --timeout=150s --for condition=Ready --all pods -l k8s-app
    kubectl --context "$cluster" wait -n default --timeout=150s --for condition=Ready --all pods -l networkservicemesh.io/app
  fi
}

if [ "$DELETE" == "true" ]; then
  echo "# Delete clusters: $CLUSTER1, $CLUSTER2"
  if [[ $AWS == "true" ]]; then
     eksctl delete cluster "$CLUSTER2"
     eksctl delete cluster "$CLUSTER1"
  else
    KIND_CLUSTER_NAME=$CLUSTER1 make kind-stop
    KIND_CLUSTER_NAME=$CLUSTER2 make kind-stop
  fi
  kubectl config delete-context "$CLUSTER1"
  kubectl config delete-context "$CLUSTER2"
  exit 0
fi

if [ "$CLUSTERS_PRESENT" == "false" ]; then
  for cluster in "$CLUSTER1" "$CLUSTER2"; do
    if [[ $(kubectl config get-contexts) == "$cluster" ]]; then
      echo "Cluster with this context already configured on this machine! please use other cluster name or delete the the cluster if you previously run this script";
      exit 1
    fi
    startCluster "$cluster"
  done
fi

for cluster in "$CLUSTER1" "$CLUSTER2"; do
    kubectl config rename-context "kind-$cluster" "$cluster"
done

if [ "$NSM_INSTALLED" == "false" ]; then
  for cluster in "$CLUSTER1" "$CLUSTER2"; do
    installNSM "$cluster"
  done
fi

if [ "$BUILD_IMAGE" == "true" ]; then
  echo "# Build ucnf image with kiknos base"
  VPP_AGENT=$VPP_AGENT ORG=$NSE_ORG TAG=$NSE_TAG make k8s-universal-cnf-save

  if [ "$PUSH_IMAGE" == "true" ]; then
    echo "# Push ucnf image to $NSE_ORG"
    docker push "$NSE_ORG/universal-cnf-vppagent:$NSE_TAG"
  fi

  if [ "$KIND_LOAD" == "true" ]; then
    for cluster in "$CLUSTER1" "$CLUSTER2"; do
        echo "# Load images into: $cluster"
        KIND_CLUSTER_NAME=$cluster make k8s-universal-cnf-load-images &
    done
    wait
  fi
fi

if [[ "$OPERATION" == "delete" ]]; then
    bash ./examples/ucnf-kiknos/scripts/install_kiknos.sh --cluster="$CLUSTER1" --delete
    bash ./examples/ucnf-kiknos/scripts/install_kiknos.sh --cluster="$CLUSTER2" --delete
    exit 0
fi

bash ./examples/ucnf-kiknos/scripts/install_kiknos.sh --cluster="$CLUSTER1"

if [[ "$DEPLOY_ASA" == "true" ]] && [[ "$AWS" == "true" ]]; then
  echo "# Retrieving IP and MAC addr of interface"
  POD_NAME=$(kubectl --context "$CLUSTER1" get pods -o name | grep endpoint | cut -d / -f 2)
  IP_ADDR=$(kubectl --context "$CLUSTER1" exec -it "$POD_NAME" -- ip addr | grep "$INTERFACE" | grep inet | awk '{print $2}' | cut -d / -f 1)

  # Update ASA config file
  day0=$(sed -e "s/<PEER_CONNECT_IP>/${IP_ADDR}/g" -e "s/<HOST_NETWORK>/192.168.254.0/g" "examples/ucnf-kiknos/scripts/day0.txt")
  # Deploy ASA
  python  examples/ucnf-kiknos/scripts/pyaws/create_ec2.py --name kiknos-asa --key-pair "$AWS_KEY_PAIR" \
      --ref "$CLUSTER1"  --image-id ami-0fe62e1a9161ec45e --interface-count 2 --user-data "$day0" --interface-in-subnet "192.168.254.0/24"
  # Deploy Ubuntu to act as client for ASA
  python  examples/ucnf-kiknos/scripts/pyaws/create_ec2.py --name kiknos-client --key-pair "$AWS_KEY_PAIR" \
      --ref "$CLUSTER1"  --image-id ami-07c1207a9d40bc3bd --instance-type t2.micro --interface-count 1 --interface-in-subnet "192.168.254.0/24"
fi

bash ./examples/ucnf-kiknos/scripts/install_kiknos.sh --cluster="$CLUSTER2" --cluster-ref="$CLUSTER1"

if [[ "$NO_ISTIO" == "false" ]]; then
  echo "Installing Istio control plane"
  kubectl --context "$CLUSTER1" apply -f ./examples/ucnf-kiknos/k8s/istio_cfg.yaml
  sleep 2
  kubectl --context "$CLUSTER1" wait -n istio-system --timeout=150s --for condition=Ready --all pods
  rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
  bash ./examples/ucnf-kiknos/scripts/start_clients.sh --cluster1="$CLUSTER1" --cluster2="$CLUSTER2" --istio_client
else
  bash ./examples/ucnf-kiknos/scripts/start_clients.sh --cluster1="$CLUSTER1" --cluster2="$CLUSTER2"
fi
rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi

sleep 2
CLUSTER="$CLUSTER2" SERVICE_NAME="$SERVICE_NAME" bash ./examples/ucnf-kiknos/scripts/start_vpn.sh
rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
