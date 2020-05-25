virsh net-create virbr1.xml
virsh net-create virbr2.xml
virsh net-create virbr3.xml

sudo ip route add 172.31.0.0/16 via 172.31.100.2 dev virbr2

