#!/usr/bin/env bash

set -x
set -o errexit
set -o pipefail
set -o nounset

##S1U INTERFACE##
UL_IFACE="S1Udev"
##SGI INTERFACE##
DL_IFACE="SGIdev"

ip a

ip link add $UL_IFACE type veth peer name l_$UL_IFACE
ip link add $DL_IFACE type veth peer name l_$DL_IFACE
ip link set $UL_IFACE up
ip link set $DL_IFACE up
ip link set l_$UL_IFACE up
ip link set l_$DL_IFACE up
