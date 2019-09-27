# virtual layer 3

This example is an NSE that creates a L3 routing domain between NSC workloads.  Each NSE
performs the following:

1. Creates an IPAM composite endpoint with a /24 prefix pulled from the /16 prefix given in
   the `endpoint.ipam` objects in the configmap.

1. Creates a virtual L3 composite endpoint that does the following upon receipt of NS requests:

   1. if the NS request is from an app workload NSC,
      1. respond with the IP context set for its route for the /24 subnet it handles IPAM for
         1. program VPP agent for the NSC connection with the request parameters
      1. create a thread that
         1. finds all other NSEs for the same network service type
         1. for each other NSE to peer with
            1. if not already connected to it, create a NS connection request with
               1. source route set to the /24 it handles IPAM for
               1. the destination endpoint of the target peer NSE 
               1. the destination NSM for the target peer NSE
               1. upon request response, program the VPP agent for the peer connection
   
   1. otherwise, the NS request is from a peer virtual-L3 NSE,
      1. set the destRoutes to the /24 that the NSE handles IPAM for
      1. respond
      1. setup VPP agent for the peer connection

## Single NSM Domain

### Constraints

1. This currently only works with a custom version of the NSM installation.

```bash
$ git clone https://github.com/tiswanso/networkservicemesh
$ cd networkservicemesh
$ git checkout vl3_interdomain
$ helm template deployments/helm/nsm-monitoring --namespace nsm-system --set monSvcType=NodePort --set org=tiswanso,tag=vl3-inter-domain | kubectl apply -f
$ kubednsip=$(kubectl get svc -n kube-system | grep kube-dns | awk '{ print $3 }')
$ helm template deployments/helm/nsm --namespace nsm-system --set global.JaegerTracing=true --set org=tiswanso --set tag=vl3-inter-domain --set pullPolicy=Always --set admission-webhook.org=tiswanso --set admission-webhook.tag=vl3-inter-domain --set admission-webhook.pullPolicy=Always --set global.NSRegistrySvc=true --set global.NSMApiSvc=true --set global.NSMApiSvcPort=30501 --set global.NSMApiSvcAddr="0.0.0.0:30501" --set global.NSMApiSvcType=NodePort --set global.ExtraDnsServers=${kubednsip} | kubectl apply -f -
```

### Usage

```
$ kubectl apply -f examples/vl3_basic/k8s/vl3-nse-ucnf.yaml
$ kubectl apply -f examples/vl3_basic/k8s/vl3-hello.yaml
```

#### Validate vl3 helloworld client inter-connectivity

```
./examples/vl3_basic/scripts/check_vl3.sh
```

## Multiple Domain Usage

### NSM Installation

1. This currently only works with a custom version of the NSM installation.

```bash
$ cd ..
$ git clone https://github.com/tiswanso/networkservicemesh 
$ cd networkservicemesh
$ git checkout vl3_interdomain
```

1. Use script to install inter-domain NSM.

   1. From the root of the `examples` repo, where files `cluster1.kubeconf` and `cluster2.kubeconf`
      are the kubeconfig files for each cluster to be part of the NSM interdomain setup.
   
      ```bash
      kubeconfig_list="cluster1.kubeconf cluster2.kubeconf cluster3.kubeconf"

      for kubeconfig in ${kubeconfig_list}; do
        echo "Installing NSM with kubeconfig=${kubeconfig}"
        KCONF=${kubeconfig} examples/vl3_basic/scripts/nsm_install_interdomain.sh
      done

      ```

### Install vL3 NSEs and helloworld NSCs

The script `examples/vl3_basic/scripts/vl3_interdomain.sh` will install the virtual L3 NSE
daemonset in a cluster, wait for the pods to come up, and install the `helloworld` pods as
NSCs.

The script requires the env var `REMOTE_CLUSTERIP` to be set.  The format is a comma separated
list of IPs that act as the remote cluster's NSM API endpoints.  Its value is the NodePort IP for
the `nsmgr` Kubernetes service created in the `nsm_install_interdomain.sh` NSM installation step.

```bash
REMOTE_IP=${cluster2_nsmgr_ip},${cluster3_nsmgr_ip} KCONF=cluster1.kconf examples/vl3_basic/scripts/vl3_interdomain.sh
REMOTE_IP=${cluster1_nsmgr_ip},${cluster3_nsmgr_ip} KCONF=cluster2.kconf examples/vl3_basic/scripts/vl3_interdomain.sh
REMOTE_IP=${cluster1_nsmgr_ip},${cluster2_nsmgr_ip} KCONF=cluster3.kconf examples/vl3_basic/scripts/vl3_interdomain.sh

```

#### Validating Connectivity

The `helloworld` pods should have connectivity to each other across clusters through the
NSM interdomain dataplane connections.  The following is an example of HTTP access between
the `helloworld` pods in 2 clusters.

```bash
$ kubectl get pods --kubeconfig clus2.kubeconfig
NAME                            READY   STATUS    RESTARTS   AGE
helloworld-v1-fc4998b76-rkf8b   3/3     Running   0          10m
helloworld-v1-fc4998b76-vj76w   3/3     Running   0          10m
vl3-nse-ucnf-cvhzf              1/1     Running   0          11m
$ kubectl get pods --kubeconfig clus1.kubeconfig
NAME                            READY   STATUS    RESTARTS   AGE
helloworld-v1-fc4998b76-j6pgw   3/3     Running   0          12m
helloworld-v1-fc4998b76-tm6tq   3/3     Running   0          12m
vl3-nse-ucnf-4lf6k              1/1     Running   0          13m
vl3-nse-ucnf-jxdlp              1/1     Running   0          13m

$ kubectl exec --kubeconfig clus1.kubeconfig -t helloworld-v1-fc4998b76-tm6tq ip a
Defaulting container name to helloworld.
Use 'kubectl describe pod/helloworld-v1-fc4998b76-tm6tq -n default' to see all of the containers in this pod.
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
2: tunl0@NONE: <NOARP> mtu 1480 qdisc noop state DOWN group default qlen 1
    link/ipip 0.0.0.0 brd 0.0.0.0
4: eth0@if76: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default
    link/ether 02:8b:0d:cb:b0:fb brd ff:ff:ff:ff:ff:ff
    inet 192.150.232.101/32 scope global eth0
       valid_lft forever preferred_lft forever
77: nsm0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UNKNOWN group default qlen 1000
    link/ether e2:33:29:ba:8f:53 brd ff:ff:ff:ff:ff:ff
    inet 10.60.232.1/30 brd 10.60.232.3 scope global nsm0
       valid_lft forever preferred_lft forever
$ kubectl exec --kubeconfig clus2.kubeconfig -t helloworld-v1-fc4998b76-vj76w ip a
Defaulting container name to helloworld.
Use 'kubectl describe pod/helloworld-v1-fc4998b76-vj76w -n default' to see all of the containers in this pod.
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
2: tunl0@NONE: <NOARP> mtu 1480 qdisc noop state DOWN group default qlen 1000
    link/ipip 0.0.0.0 brd 0.0.0.0
4: eth0@if88: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default
    link/ether 16:3e:e1:d6:f4:f8 brd ff:ff:ff:ff:ff:ff
    inet 192.178.180.209/32 scope global eth0
       valid_lft forever preferred_lft forever
90: nsm0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UNKNOWN group default qlen 1000
    link/ether 9e:cc:7c:b7:63:6c brd ff:ff:ff:ff:ff:ff
    inet 10.60.180.1/30 brd 10.60.180.3 scope global nsm0
       valid_lft forever preferred_lft forever
$ kubectl exec --kubeconfig clus2.kubeconfig -t helloworld-v1-fc4998b76-vj76w -- curl http://10.60.232.1:5000/hello
Defaulting container name to helloworld.
Use 'kubectl describe pod/helloworld-v1-fc4998b76-vj76w -n default' to see all of the containers in this pod.
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    59  100    59    0     0    312      0 --:--:-- --:--:-- --:--:--   312
Hello version: v1, instance: helloworld-v1-fc4998b76-tm6tq

$ kubectl exec --kubeconfig clus1.kubeconfig -t helloworld-v1-fc4998b76-tm6tq -- curl http://10.60.180.1:5000/hello
Defaulting container name to helloworld.
Use 'kubectl describe pod/helloworld-v1-fc4998b76-tm6tq -n default' to see all of the containers in this pod.
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    59  100    59    0     0    366      0 --:--:-- --:--:-- --:--:--   368
Hello version: v1, instance: helloworld-v1-fc4998b76-vj76w
```

## References

1. [Interdomain NSM](https://github.com/networkservicemesh/networkservicemesh/issues/714)

## TODOs

1. DNS integration for workload service discovery
