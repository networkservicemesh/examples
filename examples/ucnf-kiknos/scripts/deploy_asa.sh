#!/usr/bin/env bash

AWS_KEY_PAIR=${AWS_KEY_PAIR:-kiknos-asa}

function print_usage() {
    echo "1"
}

for i in "$@"; do
  case $i in
  --cluster=*)
    CLUSTER="${i#*=}"
    ;;
  --cluster-ref=*)
    CLUSTER_REF="${i#*=}"
    ;;
  --delete)
    OPERATION=delete
    ;;
  --aws_key_pair=*)
    AWS_KEY_PAIR="${i#*=}"
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

[[ -z "$CLUSTER" ]] && echo "env var: CLUSTER is required!" && print_usage && exit 1
[[ -z "$CLUSTER_REF" ]] && echo "env var: CLUSTER_REF is required!" && print_usage && exit 1

pushd "$(dirname "${BASH_SOURCE[0]}")/../../../" || exit 1

echo "# Retrieving IP and MAC addr of interface"
POD_NAME=$(kubectl --context "$CLUSTER_REF" get pods -o name | grep endpoint | cut -d / -f 2)
IP_ADDR=$(kubectl --context "$CLUSTER_REF" exec -it "$POD_NAME" -- ip addr | grep -E "global (dynamic )?eth0" | grep inet | awk '{print $2}' | cut -d / -f 1)

# Update ASA config file
day0=$(sed -e "s/<PEER_CONNECT_IP>/${IP_ADDR}/g" -e "s/<HOST_NETWORK>/192.168.254.0/g" "examples/ucnf-kiknos/scripts/day0.txt")
# Deploy ASA
python  examples/ucnf-kiknos/scripts/pyaws/create_ec2.py --name kiknos-asa --key-pair "$AWS_KEY_PAIR" \
    --ref "$CLUSTER"  --image-id ami-0fe62e1a9161ec45e --interface-count 2 --user-data "$day0" --interface-in-subnet "192.168.254.0/24"
# Deploy Ubuntu to act as client for ASA
python  examples/ucnf-kiknos/scripts/pyaws/create_ec2.py --name kiknos-client --key-pair "$AWS_KEY_PAIR" \
    --ref "$CLUSTER"  --image-id ami-07c1207a9d40bc3bd --instance-type t2.micro --interface-count 1 --interface-in-subnet "192.168.254.0/24"
