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

## Current Usage

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

### TODOs

1. Validate with [Interdomain NSM](https://github.com/networkservicemesh/networkservicemesh/issues/714)

1. DNS integration for workload service discovery



