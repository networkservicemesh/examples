# VPP based ICMP example

This example deploys a 2 replica ICMP responder NS Endpoint. Then a 4 replica client is deployed. Since the NSMgrs are round robin the available NS Endpoints within the same service and labels, this will result in equal distribution of 2 Clients per Responder. Note that since the Responders operate their own IPAMs, the IP ranges overlap. That is not a problem since the Clients connected to different responders do not have their interfaces 

```
+--------+            +----------------+
| Client +------------>                |
+--------+            |      ICMP      |
                      |                |
                      |    responder   |
+--------+            |                |
| Client +------------>  10.60.1.0/24  |
+--------+            +----------------+


+--------+            +----------------+
| Client +------------>                |
+--------+            |      ICMP      |
                      |                |
                      |    responder   |
+--------+            |                |
| Client +------------>  10.60.1.0/24  |
+--------+            +----------------+

```