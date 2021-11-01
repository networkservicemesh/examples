#!/usr/bin/env bash

RUN_DIR="/opt/dp/config"
CNI_IF="eth0"
SX_IF="sx"
##S1U INTERFACE##
S1U_IF="s1u"
UL_IFACE="S1Udev"
##SGI INTERFACE##
SGI_IF="sgi"
DL_IFACE="SGIdev"
RTR_SGI_IP="13.1.1.110"
RTR_SGI_MASK="255.255.255.192"


cd ${RUN_DIR}

previp(){
    IP=$1
    IP_HEX=$(printf '%.2X%.2X%.2X%.2X\n' `echo $IP | sed -e 's/\./ /g'`)
    NEXT_IP_HEX=$(printf %.8X `echo $(( 0x$IP_HEX -1 ))`)
    NEXT_IP=$(printf '%d.%d.%d.%d\n' `echo $NEXT_IP_HEX | sed -r 's/(..)/0x\1 /g'`)
    echo "$NEXT_IP"
}

CNI_IP=$(ip -4 addr show dev ${CNI_IF} | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
CP_COMM_IP=$(ip -4 addr show dev ${SX_IF} | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
DP_COMM_IP=$(previp $CP_COMM_IP)

sed -i "s/CP_COMM_IP/$CP_COMM_IP/g" interface.cfg
sed -i "s/DP_COMM_IP/$DP_COMM_IP/g" interface.cfg

S1U_IP=$(ip -4 addr show dev ${S1U_IF} | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
SGI_IP=$(ip -4 addr show dev ${SGI_IF} | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
S1U_MAC=$(ip addr show dev ${S1U_IF} | awk '$1=="link/ether"{print $2}')
SGI_MAC=$(ip addr show dev ${SGI_IF} | awk '$1=="link/ether"{print $2}')
S1U="--s1u_ip ${S1U_IP} --s1u_mac ${S1U_MAC} --ul_iface ${UL_IFACE}"
SGI="--sgi_ip ${SGI_IP} --sgi_mac ${SGI_MAC} --dl_iface ${DL_IFACE} --sgi_gw_ip ${RTR_SGI_IP} --sgi_mask ${RTR_SGI_MASK}"


# =======================================================================
# Setup AF_PACKET

calc_cidrmask() {
    local CIDR_MASK=0
    local DOTTED_MASK=$1
    for octet in $(echo $DOTTED_MASK | sed 's/\./ /g'); do
	binbits=$(echo "obase=2; ibase=10; ${octet}"| bc | sed 's/0//g')
	let CIDR_MASK+=${#binbits}
    done

    echo $CIDR_MASK
}

# SUDO=''
# [[ $EUID -ne 0 ]] && SUDO=sudo

# $SUDO ip link add $UL_IFACE type veth peer name l_$UL_IFACE
# $SUDO ip link add $DL_IFACE type veth peer name l_$DL_IFACE
# $SUDO ip link set $UL_IFACE up
# $SUDO ip link set $DL_IFACE up
# $SUDO ip link set l_$UL_IFACE up
# $SUDO ip link set l_$DL_IFACE up
$SUDO ip link set dev $UL_IFACE address $S1U_MAC
$SUDO ip link set dev $DL_IFACE address $SGI_MAC

CIDR_MASK=$(calc_cidrmask $S1U_MASK)
$SUDO ip addr add $S1U_IP/$CIDR_MASK dev $UL_IFACE

CIDR_MASK=$(calc_cidrmask $SGI_MASK)
$SUDO ip addr add $SGI_IP/$CIDR_MASK dev $DL_IFACE

ip route

# =======================================================================

/bin/ngic_dataplane \
	-c 3f --no-huge -m 2048 --no-pci \
	--vdev eth_af_packet1,iface=${S1U_IF} --vdev eth_af_packet2,iface=${SGI_IF} -- \
	${S1U} \
	${SGI} \
	--log 1 \
	--spgw_cfg 03
