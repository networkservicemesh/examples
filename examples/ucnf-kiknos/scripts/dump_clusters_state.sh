#!/usr/bin/env bash

# Topology information
CLUSTER1=${CLUSTER1:-kiknos-demo-1}
CLUSTER2=${CLUSTER2:-kiknos-demo-2}


pushd "$(dirname "$0")/../../../"

print_usage() {
  echo "$(basename "$0") - Deploy NSM Kiknos topology. All properties can also be provided through env variables

NOTE: The defaults will change to the env values for the ones set.

Usage: $(basename "$0") [options...]
Options:
  --cluster1            Name of Kind cluster one - Represents the client network            env var: CLUSTER1         - (Default: $CLUSTER1)
  --cluster2            Name of Kind cluster two - Represents the VPN Gateway               env var: CLUSTER2         - (Default: $CLUSTER2)
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

function dump_state_of_namespace() {
    local cluster=$1; shift
    local namespace=$1; shift
    echo ""
    echo "##################################### Dumping state of $namespace for $cluster #########################################"
    kubectl get pods --context "$cluster" -n "$namespace"
}

function dump_addresses_of_endpoints() {
  local cluster=$1; shift
  echo
  echo "##################################### Dumping NSE interfaces for $cluster #########################################"
  for NSE in $(kubectl --context "$cluster" get pods -l networkservicemesh.io/impl=vpn-endpoint -o=name); do
    echo "--------------------------------------- NSE $NSE interfaces --------------------------------------------------"
    echo "-------------------------------------------Addresses----------------------------------------------------------"
    kubectl --context "$cluster" exec -it "$NSE" -- vppctl show interf addr
    echo "-------------------------------------------Interfaces---------------------------------------------------------"
    kubectl --context "$cluster" exec -it "$NSE" -- vppctl show interf
    echo "---------------------------------------------Mode-------------------------------------------------------------"
    kubectl --context "$cluster" exec -it "$NSE" -- vppctl sh mode
    echo "-------------------------------------------VxLan Tunnel-------------------------------------------------------"
    kubectl --context "$cluster" exec -it "$NSE" -- vppctl sh vxlan tunnel
    echo "-------------------------------------------IpIP Tunnel--------------------------------------------------------"
    kubectl --context "$cluster" exec -it "$NSE" -- vppctl sh ipip tunnel
    echo "--------------------------------------------Ip Sec Sa---------------------------------------------------------"
    kubectl --context "$cluster" exec -it "$NSE" -- vppctl sh ipsec sa
    echo "--------------------------------------------Ip Sec Sa 0-------------------------------------------------------"
    kubectl --context "$cluster" exec -it "$NSE" -- vppctl sh ipsec sa 0
    echo "--------------------------------------------Ip Sec Sa 1-------------------------------------------------------"
    kubectl --context "$cluster" exec -it "$NSE" -- vppctl sh ipsec sa 1
    echo "--------------------------------------------Ip Sec Protect----------------------------------------------------"
    kubectl --context "$cluster" exec -it "$NSE" -- vppctl sh ipsec sa
    echo "--------------------------------------------Crypto Engines----------------------------------------------------"
    kubectl --context "$cluster" exec -it "$NSE" -- vppctl sh crypto engines
    echo "--------------------------------------------Crypto Handlers---------------------------------------------------"
    kubectl --context "$cluster" exec -it "$NSE" -- vppctl sh crypto handlers
    echo "--------------------------------------------Vpp Log-----------------------------------------------------------"
    kubectl --context "$cluster" exec -it "$NSE" -- vppctl sh log

  done
}

function dump_addresses_of_clients() {
  local cluster=$1; shift
  echo
  echo "##################################### Dumping NSC interfaces for $cluster #########################################"
  for NSC in $(kubectl --context "$cluster" get pods -n istio-system -l app=istio-ingressgateway -o=name); do
    echo "--------------------------------------- NSC $NSC interfaces --------------------------------------------------"
    kubectl --context "$cluster" -n istio-system exec "$NSC" -c istio-proxy -- ip addr show dev nsm0
  done

  for NSC2 in $(kubectl --context "$cluster" get pods -l app=icmp-responder -o=name); do
    echo "--------------------------------------- NSC $NSC2 interfaces --------------------------------------------------"
    kubectl --context "$cluster" exec "$NSC2" -c helloworld -- ip addr show dev nsm0
  done
}
echo
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "+++++++++++++++++++++++++++++++++++++++ State of cluster $CLUSTER1 ++++++++++++++++++++++++++++++++++++++++++++++"
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
dump_state_of_namespace "$CLUSTER1" "nsm-system"
dump_state_of_namespace "$CLUSTER1" "istio-system"
dump_state_of_namespace "$CLUSTER1" "default"
dump_addresses_of_endpoints "$CLUSTER1"
dump_addresses_of_clients "$CLUSTER1"


echo
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "+++++++++++++++++++++++++++++++++++++++ State of cluster $CLUSTER2 ++++++++++++++++++++++++++++++++++++++++++++++"
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
dump_state_of_namespace "$CLUSTER2" "nsm-system"
dump_state_of_namespace "$CLUSTER2" "default"
dump_addresses_of_endpoints "$CLUSTER2"
dump_addresses_of_clients "$CLUSTER2"