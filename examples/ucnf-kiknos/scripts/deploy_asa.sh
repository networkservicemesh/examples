#!/usr/bin/env bash

AWS_KEY_PAIR=${AWS_KEY_PAIR:-kiknos-asa}
SUBNET_IP=${SUBNET_IP:-192.168.254.0}

function print_usage() {
    echo "$(basename "$0") - Deploy ASAv. All properties can also be provided through env variables

NOTE: The defaults will change to the env values for the ones set.

Usage: $(basename "$0") [options...]
Options:
  --cluster-ref         Reference to cluster to connect to                                  env var: CLUSTER_REF      - (Default: $CLUSTER_REF)
  --aws-key-pair        AWS Key Pair for connecting over SSH                                env var: AWS_KEY_PAIR     - (Default: $AWS_KEY_PAIR)
  --subnet-ip           IP for the remote ASA subnet (without the mask, ex: 192.168.254.0)  env var: SUBNET_IP        - (Default: $SUBNET_IP)
  --help -h             Help
" >&2
}

for i in "$@"; do
  case $i in
  --cluster-ref=*)
    CLUSTER_REF="${i#*=}"
    ;;
  --aws-key-pair=*)
    AWS_KEY_PAIR="${i#*=}"
    ;;
  --subnet-ip=*)
    SUBNET_IP="${i#*=}"
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

[[ -z "$CLUSTER_REF" ]] && echo "env var: CLUSTER_REF is required!" && print_usage && exit 1

pushd "$(dirname "${BASH_SOURCE[0]}")/../../../" || exit 1

echo "# Retrieving IP and MAC addr of interface"
POD_NAME=$(kubectl --context "$CLUSTER_REF" get pods -o name | grep endpoint | cut -d / -f 2)
IP_ADDR=$(kubectl --context "$CLUSTER_REF" exec -it "$POD_NAME" -- ip addr | grep -E "global (dynamic )?eth0" | grep inet | awk '{print $2}' | cut -d / -f 1)

# Update ASA config file
day0=$(sed -e "s/<PEER_CONNECT_IP>/${IP_ADDR}/g" -e "s/<HOST_NETWORK>/$SUBNET_IP/g" "examples/ucnf-kiknos/scripts/day0.txt")

# Deploy ASA
python  examples/ucnf-kiknos/scripts/pyaws/create_ec2.py --name kiknos-asa --key-pair "$AWS_KEY_PAIR" \
    --ref "$CLUSTER_REF"  --image-id ami-0fe62e1a9161ec45e --interface-count 2 --user-data "$day0" --interface-in-subnet "$SUBNET_IP/24"

# Deploy Ubuntu to act as client for ASA
python  examples/ucnf-kiknos/scripts/pyaws/create_ec2.py --name kiknos-client --key-pair "$AWS_KEY_PAIR" \
    --ref "$CLUSTER_REF"  --image-id ami-07c1207a9d40bc3bd --instance-type t2.micro --interface-count 1 --interface-in-subnet "$SUBNET_IP/24"
