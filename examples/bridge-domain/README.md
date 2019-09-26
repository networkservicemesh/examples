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

Usage;
```
# Start the bridge and the test app;
kubectl apply -f ./k8s/bridge.yaml
kubectl get pods -l networkservicemesh.io/app=bridge-domain
kubectl apply -f ./k8s/simple-client.yaml
kubectl get pods -l networkservicemesh.io/app=simple-client
# (wait until all simple-clients are running and ready (3/3))

# Test;
p=<select-a-simple-client-pod>
kubectl exec -it -c alpine-img $p sh
# Inside the container;
ifconfig
ping 10.60.1.1
ping 10.60.1.2
ping 10.60.1.3
```
