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

 
# Testing

> :warning: **For the current version build image are available only with `ORG=vladcodaniel` env **
## Deploy the environment

* Deploy kind environment:
```bash
make kiknos-kind
```
* Deploy on aws:
```bash
make kiknos-aws
```
Both make targets use the script:
```bash
./examples/ucnf-kiknos/scripts/start_topo.sh
```
This make target performs the following actions:
* Starts 2 clusters
* Installs NSM in both clusters
* Deploys the kiknos NSEs on both clusters:
    * In one of the clusters it will act as a VPN client
    * In one of the clusters it will act as a VPN Gateway
* Installs Istio on the VPN client cluster
* Deploys worker pods as NSC in both clusters
* Deploys the Istio ingress gateway as a NSC in the VPN client cluster
* Deploys two pods that will be exposed through an Istio virtual service to the ingress gateway.

For more script options use `--help`:
```bash
./examples/ucnf-kiknos/scripts/kind_topo.sh --help

kind_topo.sh - Deploy NSM Kiknos topology. All properties can also be provided through env variables

NOTE: The defaults will change to the env values for the ones set.

Usage: kind_topo.sh [options...]
Options:
  --cluster1            Name of Kind cluster one - Represents the client network            env var: CLUSTER1         - (Default: kind-cl1)
  --cluster2            Name of Kind cluster two - Represents the VPN Gateway               env var: CLUSTER2         - (Default: kind-cl2)
  --vpp_agent           Base docker image for NSE                                           env var: VPP_AGENT        - (Default: ciscolabs/kiknos:latest)
  --org                 Organisation of NSE image                                           env var: NSE_ORG          - (Default: mmatache)
  --tag                 NSE image tag                                                       env var: NSE_TAG          - (Default: kiknos)
  --pull_policy         Pull policy for the NSE image                                       env var: PULL_POLICY      - (Default: IfNotPresent)
  --service_name        NSM service                                                         env var: SERVICE_NAME     - (Default: icmp-responder)
  --build_image         Indicates whether the NSE image should be built or just pulled
                        from the image repository                                           env var: BUILD_IMAGE      - (Default: false)
  --clusters_present    Set if you already have kind clusters present                       env var: CLUSTERS_PRESENT - (Default: false)
  --nsm_installed       Set if the NSM is already installed on the clusters                 env var: NSM_INSTALLED    - (Default: false)
  --no_istio            Set if you do not want the istio service mesh to be deployed        env var: NO_ISTIO         - (Default: )
  --clean               Removes the NSEs and Clients from the clusters                      env var: CLEAN            - (Default: false)
  --delete              Delete the Kind clusters                                            env var: DELETE           - (Default: false)
```
## Check connectivity between workloads (Scenario 1)
In order to check the connectivity between worker pods run the following make target:
```bash
make kiknos-test-conn
```
Alternatively use the script:
```
./examples/ucnf-kiknos/scripts/test_vpn_conn.sh
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
```sh
make kiknos-test-istio-conn
```
Alternatively use the script:
```sh
./examples/ucnf-kiknos/scripts/test_istio_vpn_conn.sh
```
This will attempt to perform `curl` commands from the workers in the VPN Gateway cluster to the Istio ingress gateway.
This allows a user to connect to different services by keeping the same IP address for each call and differentiating 
between workloads by specifying different ports or URL paths. 

In our current example, we deploy 2 services, and expose each service twice. In all cases, the request goes through the
IP address of the Ingress gateway that was supplied by the NSE.

Output:
```sh
CLUSTER1=kiknos-demo-1 CLUSTER2=kiknos-demo-2 /home/mihai/go/src/github.com/networkservicemesh/examples/examples/ucnf-kiknos/scripts/test_istio_vpn_conn.sh
Detected pod with nsm interface ip: 172.31.22.9
------------------------- Source pod/helloworld-ucnf-client-7bd94648d-2t7zj -------------------------
Connecting to: http://172.31.22.9/hello
Hello version: v1, instance: icmp-responder-v1-88bcb54bf-vt8jv
Connecting to: http://172.31.22.9/hello-v2
Hello version: v2, instance: icmp-responder-v2-7474975c44-mwflt
Connecting to: http://172.31.22.9:8000/hello
Hello version: v1, instance: icmp-responder-v1-88bcb54bf-vt8jv
Connecting to: http://172.31.22.9:8000/hello-v2
Hello version: v2, instance: icmp-responder-v2-7474975c44-mwflt
-----------------------------------------------------------------------------------------------------
------------------------- Source pod/helloworld-ucnf-client-7bd94648d-vl5nn -------------------------
Connecting to: http://172.31.22.9/hello
Hello version: v1, instance: icmp-responder-v1-88bcb54bf-vt8jv
Connecting to: http://172.31.22.9/hello-v2
Hello version: v2, instance: icmp-responder-v2-7474975c44-mwflt
Connecting to: http://172.31.22.9:8000/hello
Hello version: v1, instance: icmp-responder-v1-88bcb54bf-vt8jv
Connecting to: http://172.31.22.9:8000/hello-v2
Hello version: v2, instance: icmp-responder-v2-7474975c44-mwflt
-----------------------------------------------------------------------------------------------------

```
## Dumping the state of the cluster
In order to dump the clusters state run the following make target:

```bash
make kiknos-dump-clusters-state
```

Alternatively run the script:
```sh
./examples/ucnf-kiknos/scripts/dump_clusters_state.sh
```

This will give you information regarding:
- state of the meaningful pods in the system
- state of the NSM provisioned interfaces
 

# Cleanup
The following command will delete the kind clusters.

`./examples/ucnf-kiknos/scripts/start_topo.sh --delete`

# Known issues
These issues require further investigation:

1. If the NSE restarts it loses all the interfaces  - in case of test failure dump the state of the clusters and check 
for restarts on the VPN pods in the default namespace
