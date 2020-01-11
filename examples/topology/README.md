# Network topology builder
Using NSM to build arbitrary network topologies. 

For example, the below topology is comprised of 5 Quagga routers running OSPF on all their links and loopback IP addresses allocated from RFC 5737 (192.0.2.0/24) range.

```
                +-----------+                  
                |           |                  
      +---------|  Router5  |-----------+      
      |         | 192.0.2.5 |           |      
      |         +-----------+           |      
      |                                 |      
+-----------+                     +-----------+
|           |                     |           |
|  Router1  |---------------------|  Router4  |
| 192.0.2.1 |                     | 192.0.2.4 |
+-----------+                     +-----------+
      |                                 |      
      |                                 |      
+-----------+                     +-----------+
|           |                     |           |
|  Router2  |---------------------|  Router3  |
| 192.0.2.2 |                     | 192.0.2.3 |
+-----------+                     +-----------+

```

Please check [k8s-topo](https://github.com/networkop/k8s-topo#network-service-mesh) for more details of how to build various network topologies.