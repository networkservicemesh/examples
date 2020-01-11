#!/bin/sh

# Starting Zebra
if [ ! -f /etc/quagga/zebra.conf ]; then
  echo 'Creating empty zebra.conf'
  touch /etc/quagga/zebra.conf
fi
/usr/sbin/zebra -d -f /etc/quagga/zebra.conf

cat << EOF >> /etc/quagga/ospf.conf
!
router ospf
 network 0.0.0.0/0 area 0.0.0.0
 passive-interface eth0
!
EOF

# Starting OSPF daemon
/usr/sbin/ospfd -f /etc/quagga/ospf.conf
