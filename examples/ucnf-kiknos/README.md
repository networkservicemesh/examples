# Kiknos base VPN NSE

This replaces the VPP agent in the universal-cnf with the Kiknos VPP aio-agent

# Prerequisites
You first need to clone the [Network Service Mesh repo](https://github.com/networkservicemesh/networkservicemesh)
Please follow the instructions on where the NSM project should be in the [Examples README.md](../../README.md)

- helm v2.16.3
- kubectl v1.18.2

##### Kind deployment
- kind v0.7.0 

##### AWS deployment
- aws-cli v2.0.11
- eksctl v0.18.0
- python >= 2.7

 
 # Scenarios
 ## 1. Direct connection between workloads and NSE
 In this case, the NSE connects directly to the workloads (pods) deployed on the cluster. 
 With this configuration, all the workloads can be accessed from outside the cluster using the IP address provided by 
 the NSM through a secure IP Sec tunnel.  
 
 ## 2. Using an Ingress Gateway as NSC
 Expose the workloads through an [Istio](https://istio.io/) Ingress Gateway. In this case the Ingress Gateway will act 
 as a network service client. With this configuration, it is easy to expose workloads through a common entry point. This 
 allows for the case where you want all workloads to be exposed through a single IP address and differentiate between them.
 This case provides better configurability of the k8s cluster, but adds a layer of complexity with the introduction of Istio.

## Deploy the environment

* Deploy kind environment:
```bash
make deploy-kiknos-clients CLUSTER=kiknos-demo-1
make deploy-kiknos-start-vpn BUILD_IMAGE=false DEPLOY_ISTIO=false CLUSTER=kiknos-demo-2 CLUSTER_REF=kiknos-demo-1 
```

* Deploy on aws:
```bash
make deploy-kiknos-clients AWS=true CLUSTER=kiknos-demo-1
make deploy-kiknos-start-vpn AWS=true BUILD_IMAGE=false DEPLOY_ISTIO=false CLUSTER=kiknos-demo-2 CLUSTER_REF=kiknos-demo-1
```

* Deploy ASAv with istio
```bash
make deploy-asa AWS=true CLUSTER=kiknos-demo-asa
```

By default, most of the deployment scripts depend on `k8s-ucnf-kiknos-save` rule. 
This rule builds a docker image. To control the registry and tag use `ORG` and `TAG` options. 
If you know that the image is already present you can skip this step with `BUILD_IMAGE=false` as in example above. 

Makefile consists of the following rules: 
* *provide-image*: Builds docker image and pushes or executes a `kind-load`.
* *docker-push*: Pushes the docker image to the registry specified in `ORG`. 
* *create-cluster*: Creates a cluster whether kind or aws (if set `AWS=true`). use `CLUSTER` variable for cluster name.
* *helm-init*: Deploys Tiller for helm version 2.x.
* *helm-install-nsm*: Installs NSM.
* *deploy-kiknos*: Deploys the kiknos NSEs.
* *deploy-istio*: Installs Istio. Used for the VPN client cluster.
* *deploy-kiknos-clients*: Deploys worker pods as NSC in both clusters.
    * When `DEPLOY_ISTIO=true` Deploys the Istio ingress gateway as a NSC in the VPN client cluster.
    * When `DEPLOY_ISTIO=true` Deploys two pods that will be exposed through an Istio virtual service to the ingress gateway.
* *deploy-kiknos-start-vpn*: Starts kiknos ipsec.
>Note: Only the AWS target will perform the following steps
* *deploy-asa*: Deploys an ASAv and Ubuntu EC2 instances to act as Kiknos clients. The Ubuntu client needs to be manually configured.

>Note: Make sure to check the deletion of items in AWS as they can sometimes be redeployed

Makefile options:

- `CLUSTER` - Set the cluster name - (Default: `kiknos-demo-1`)
- `ORG` - Set the org of new built image - (Default: `tiswanso`)
- `TAG` - Set the tag of new built image - (Default: `kiknos`)
- `AWS_KEY_PAIR` - AWS Key Pair for connecting over SSH - (Default: `kiknos-asa`)
- `CLUSTER_REF` - Reference cluster required when deploying the second cluster in
    order to be able to take some configurations such as remote IP address when configuring kiknos NSE or the AWS VPC - (Default: *None*)
- `VPP_AGENT` - Parent image for the NSE - (Default: `ciscolabs/kiknos:latest`)
- `FORWARDING_PLANE` - Set a default forwarding plane - (Default: `vpp`)
- `NETWORK_SERVICE` - Set a default network service for Example clients - (Default: `hello-world`)
- `BUILD_IMAGE` - Set whether to build the image or not - (Default: `true`)
- `PROVISION_MODE` - Set the mode to provision the built image. Default "push"
    one of "push" or "kind-load"
    not relevant if $BUILD_IMAGE is not true - (Default: `push`)
- `DEPLOY_ISTIO` - Set whether to deploy istio gateway or not - (Default: `true`)
- `AWS` - Create aws cluster - (Default: `false`)
- `SUBNET_IP` - IP for the remote ASA subnet (without the mask, ex: 192.168.254.0) - (Default: `192.168.254.0`)

## Check connectivity between workloads (Scenario 1)
In order to check the connectivity between worker pods run the following make target:
```bash
./examples/ucnf-kiknos/scripts/test_vpn_conn.sh --cluster1=kiknos-demo-1 --cluster2=kiknos-demo-2 
```
This will attempt to perform `curl` commands from the workers in the VPN Gateway cluster to the workers in the VPN client cluster directly.

Output:
```bash
CLUSTER1=kiknos-demo-1 CLUSTER2=kiknos-demo-2 /home/mihai/go/src/github.com/networkservicemesh/examples/examples/ucnf-kiknos/scripts/test_vpn_conn.sh
Detected pod with nsm interface ip: 172.31.22.5
Detected pod with nsm interface ip: 172.31.22.1
Hello version: v1, instance: helloworld-ucnf-client-7bd94648d-d2gbh 
Hello version: v1, instance: helloworld-ucnf-client-7bd94648d-nksbm
Hello version: v1, instance: helloworld-ucnf-client-7bd94648d-d2gbh
Hello version: v1, instance: helloworld-ucnf-client-7bd94648d-nksbm
```

## Check connectivity to workloads through the Istio gateway (Scenario 2)
In order to check the connectivity to workloads through the Istio gateway run the following make target:
```bash
./examples/ucnf-kiknos/scripts/test_istio_vpn_conn.sh --cluster1=kiknos-demo-1 --cluster2=kiknos-demo-2
```
This will attempt to perform `curl` commands from the workers in the VPN Gateway cluster to the Istio ingress gateway.
This allows a user to connect to different services by keeping the same IP address for each call and differentiating 
between workloads by specifying different ports or URL paths. 

In our current example, we deploy 2 services, and expose each service twice. In all cases, the request goes through the
IP address of the Ingress gateway that was supplied by the NSE.

Output:
```bash
./examples/ucnf-kiknos/scripts/test_istio_vpn_conn.sh --cluster1=kiknos-demo-1 --cluster2=kiknos-demo-2 
Detected pod with nsm interface ip: 172.31.22.9
------------------------- Source pod/helloworld-ucnf-client-d7d79cf54-dzs4m -------------------------
Connecting to: http://172.31.22.9/hello
no healthy upstreamConnecting to: http://172.31.22.9/hello-v2
no healthy upstreamConnecting to: http://172.31.22.9:8000/hello
no healthy upstreamConnecting to: http://172.31.22.9:8000/hello-v2
no healthy upstream-----------------------------------------------------------------------------------------------------
------------------------- Source pod/helloworld-ucnf-client-d7d79cf54-qx786 -------------------------
Connecting to: http://172.31.22.9/hello
no healthy upstreamConnecting to: http://172.31.22.9/hello-v2
no healthy upstreamConnecting to: http://172.31.22.9:8000/hello
no healthy upstreamConnecting to: http://172.31.22.9:8000/hello-v2
no healthy upstream-----------------------------------------------------------------------------------------------------

```
## AWS ASA Deployment

When using the `make kiknos-aws` target, an ASAv and an Ubuntu client are deployed in AWS. 
Then an additional IPSec tunnel gets created which connects to the Kiknos deployment.

The ASA uses a [day0](./scripts/day0.txt) configuration in order to be able to create the IPSec tunnel.

## Dumping the state of the cluster
In order to dump the clusters state run the following make target:

```bash
make kiknos-dump-clusters-state
```

Alternatively run the script:
```bash
./examples/ucnf-kiknos/scripts/dump_clusters_state.sh
```

This will give you information regarding:
- state of the meaningful pods in the system
- state of the NSM provisioned interfaces
 

# Cleanup
The following commands will delete the kind clusters.

```bash
make clean CLUSTER=kiknos-demo-1
make clean CLUSTER=kiknos-demo-2
```

If on AWS:

```bash
make clean AWS=true CLUSTER=kiknos-demo-1
make clean AWS=true CLUSTER=kiknos-demo-2
```

# Known issues
These issues require further investigation:

1. If the NSE restarts it loses all the interfaces  - in case of test failure dump the state of the clusters and check 
for restarts on the VPN pods in the default namespace
