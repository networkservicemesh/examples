# Cisco ASAv firewall IPSec connection
These scripts allow starting an ASAv firewall using qemu
and connecting it to a running Kiknos instance via an IPSec tunnel.

1. Download ASAv qcow2 image into this directory:
```
ls -lh asav9-12-3-12.qcow2
-rw-r--r-- 1 user user 199M May 25 01:54 asav9-12-3-12.qcow2
```
(if the file name that you downloaded is different, modify it in the `start.sh` file)


2. Edit day0-config file if needed:
(e.g. hardcoded remote VPN endpoint is `172.17.0.2`)


3. Generate day0.iso from day0-config file:
```
./day0.sh
```


4. Setup virtual networks on the host:
```
./virt_network_setup.sh
```


5. Start an ASAv instance:
```
./start.sh
```
(it may take several minutes to boot)


6. SSH to the ASAv instance:
```
ssh cisco@192.168.1.2
```
(see day0-config file for password)


7. Test the conenctivity between the host and k8s cluster via ASAv:
```
$ ping 172.31.22.1
PING 172.31.22.1 (172.31.22.1) 56(84) bytes of data.
64 bytes from 172.31.22.1: icmp_seq=3 ttl=63 time=3.14 ms
64 bytes from 172.31.22.1: icmp_seq=4 ttl=63 time=3.77 ms
64 bytes from 172.31.22.1: icmp_seq=5 ttl=63 time=2.74 ms
64 bytes from 172.31.22.1: icmp_seq=6 ttl=63 time=3.04 ms
```

```
ciscoasa# sh crypto ipsec sa
interface: outside
    Crypto map tag: ikev2-map, seq num: 1, local addr: 198.51.100.2

      access-list ikev2-list extended permit ip 172.31.100.0 255.255.255.0 172.31.22.0 255.255.255.0 
      local ident (addr/mask/prot/port): (172.31.100.0/255.255.255.0/0/0)
      remote ident (addr/mask/prot/port): (172.31.22.0/255.255.255.0/0/0)
      current_peer: 172.17.0.2


      #pkts encaps: 5, #pkts encrypt: 5, #pkts digest: 5
      #pkts decaps: 4, #pkts decrypt: 4, #pkts verify: 4
```


8. Stop the ASAv instance:
```
./stop.sh
```

