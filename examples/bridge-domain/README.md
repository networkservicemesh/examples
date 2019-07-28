# VPP bridge domain

This example implements a setup where the NS Endpoint is an Ethernet learning bridge, with a simple IPAM.


```
    +--------+
    | Client +-------+
    +--------+       |       +----------------+
                     |       |                |
                     +------->                |
    +--------+               |    learning    |
    | Client +--------------->                |
    +--------+               |     bridge     |
                     +------->                |
                     |       |  10.60.1.0/24  |
    +--------+       |       +----------------+
    | Client +-------+
    +--------+
```
