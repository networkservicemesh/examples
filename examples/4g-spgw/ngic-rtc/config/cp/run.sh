#!/usr/bin/env bash

RUN_DIR="/opt/cp/config"
CNI_IF="eth0"
SX_IF="sx"

cd ${RUN_DIR}

nextip(){
    IP=$1
    IP_HEX=$(printf '%.2X%.2X%.2X%.2X\n' `echo $IP | sed -e 's/\./ /g'`)
    NEXT_IP_HEX=$(printf %.8X `echo $(( 0x$IP_HEX + 1 ))`)
    NEXT_IP=$(printf '%d.%d.%d.%d\n' `echo $NEXT_IP_HEX | sed -r 's/(..)/0x\1 /g'`)
    echo "$NEXT_IP"
}

CNI_IP=$(ip -4 addr show dev ${CNI_IF} | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
CP_COMM_IP=$(ip -4 addr show dev ${SX_IF} | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
DP_COMM_IP=$(nextip $CP_COMM_IP)

sed -i "s/CP_COMM_IP/$CP_COMM_IP/g" interface.cfg
sed -i "s/DP_COMM_IP/$DP_COMM_IP/g" interface.cfg


#   {"spgw_cfg",  required_argument, NULL, 'd'},
#   {"s11_mme_ip",  required_argument, NULL, 'm'},
#   {"s11_sgw_ip",  required_argument, NULL, 's'},
#   {"s5s8_sgwc_ip", optional_argument, NULL, 'r'},
#   {"s5s8_pgwc_ip",  optional_argument, NULL, 'g'},
#   {"s1u_sgw_ip",  required_argument, NULL, 'w'},
#   {"s5s8_sgwu_ip",  optional_argument, NULL, 'v'},
#   {"s5s8_pgwu_ip",  optional_argument, NULL, 'u'},
#   {"ip_pool_ip",  required_argument, NULL, 'i'},
#   {"ip_pool_mask", required_argument, NULL, 'p'},
#   {"apn_name",   required_argument, NULL, 'a'},
#   {"log_level",   required_argument, NULL, 'l'},
#   {"pcap_file_in", required_argument, NULL, 'x'},
#   {"pcap_file_out", required_argument, NULL, 'y'},

# | ARGUMENT           | PRESENCE    | DESCRIPTION                                |
# |:-------------------|:------------|:-------------------------------------------|
# | --SPGW_CFG         | MANDATORY   | CP run setup:01(SGWC), 02(PGWC),03(SPGWC)  |
# | --s11_sgw_ip       | MANDATORY   | Local interface IP exposed to Linux        |
# |                    |             | networking stack to be used by the Control |
# |                    |             | Plane for messaging with the MME           |
# | --s11_mme_ip       | MANDATORY   | MME IP                                     |
# | --s1u_sgw_ip       | MANDATORY   | Network interface IP exposed by DP; must be|
# |                    |             | equivalent to --s1u_ip parameter of DP     |
# | --s5s8_sgwc_ip     | OPTIONAL    | Applicable in case of SGWC configuration   |
# | --s5s8_sgwu_ip     | OPTIONAL    | Applicable in case of SGWC configuration   |
# | --s5s8_pgwc_ip     | OPTIONAL    | Applicable in case of PGWC configuration   |
# | --s5s8_pgwu_ip     | OPTIONAL    | Applicable in case of PGWC configuration   |
# | --ip_pool_ip       | MANDATORY   | Along with mask, defines pool of IP        |
# |                    |             | addresses that CP may assign to UEs        |
# | --ip_pool_mask     | MANDATORY   | ip_pool_mask                               |
# | --apn_name         | MANDATORY   | Access Point Name label supported by CP;   |
# |                    |             | must correspond to APN referenced in create|
# |                    |             | session request messages along the s11     |
# | --pcap_file_in     | OPTIONAL    | Ignores s11 interface and acts as if       |
# |                    |             | packets contained in input file arrived    |
# |                    |             | from MME                                   |
# | --pcap_file_out    | OPTIONAL    | Creates a capture of messages created by   |
# |                    |             | CP. Mainly for development purposes        |
# | --memory           | MANDATORY   | Memory size for hugepages setup            |
# | --numa0_memory     | MANDATORY   | Socket memory related to numa0 socket      |
# | --numa1_memory     | MANDATORY   | Socket memory related to numa1 socket      |
# |:-------------------|:------------|:-------------------------------------------|

/bin/ngic_controlplane \
    -c 3f --no-huge -m 2048 --no-pci -- \
    --s11_sgw_ip ${CNI_IP} \
    --s1u_sgw_ip 11.1.1.1 \
    --ip_pool_ip 16.0.0.0 \
    --ip_pool_mask 255.0.0.0 \
    --apn_name apn1 \
    --spgw_cfg 03 \
    --log_level 2 \
    # --s5s8_sgwc_ip 7.7.7.7 \
    # --s5s8_pgwc_ip 6.6.6.6 \
    # --s5s8_sgwu_ip 4.4.4.4 \
    # --s5s8_pgwu_ip 5.5.5.5
