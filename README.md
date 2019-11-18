# Network Service Mesh Examples

[![CircleCI Build Status](https://circleci.com/gh/networkservicemesh/examples/tree/master.svg?style=svg)](https://circleci.com/gh/networkservicemesh/examples/tree/master)

This repository contains examples and use-cases for Network Service Mesh. It is an independent way to deploy both NSM and a selection of examples, superimposed over the original `networkservicemesh` repository.

## Quick Start

### Control where NSM code is with `NSM_PATH`

The main cluster and infrastructure deployment targets are executed straight from the upstream `networkservicemesh` repository. The path to it is set by the environment `NSM_PATH`, with a default value of `../networkservicemesh`. The easiest way to use it is to download both `networkservicemesh` and `examples` in the same root folder and then follow the next instructions.

### Browsing the `examples`

The repo host s number of example setups of NSM based applications. The quick way to check what is availabe is to run:

```shell
$ make list
	 4g-network                     4G Network Topology example
	 bridge-domain                  A simple VPP bridge domain example
	 envoy_interceptor              Run Envoy as a NS Endpoint
	 gw-routers                     GW and Router - usecase for the CNF Testbed
	 icmp                           Basic kernel interface ICMP reposnder
	 packet-filtering               Packet filtering - usecase for the CNF Testbed
	 proxy                          HTTP reverse proxy, which maps the HTTP requests to NSM Client requests
	 secure-intranet                The *Sarah* Secure Intranet Connectivity implementation
	 ucnf-icmp                      Basic ICMP reposnder based on the Universal CNF
	 universal-cnf                  The Universal CNF
	 vpp-icmp                       Basic memif interface ICMP reposnder with VPP

 Get the full description of the example by calling:

 	 make <example-name>-describe
```

As seen ont he last line, there is a possibility to run `make <example>-describe` and get a more detailed explanation of the particular application. Please consider installing `consolemd` (`pip install consolemd`) for a better console experience browsing the documentation.

### Run the `examples`

In the `examples` repository folder, execute the following set of commands.  These commands are for the proxy example.  Change the term "proxy" for other examples:

```shell
make kind-start

SPIRE_ENABLED=false INSECURE=true make helm-init helm-install-nsm

make k8s-proxy-save k8s-proxy-load-images

make k8s-proxy-deploy

make k8s-proxy-check
```

## More details

The repo follows the main NSM development and deployment model based on `Kind`. Please refer to [NSM's QUICK-START.md](https://github.com/networkservicemesh/networkservicemesh/blob/master/docs/guide-quickstart.md) for detailed instructions on how to set-up the development environment.

### Cluster setup

By default, the cluster is deployed with `Kind` using the following `make` target:

```shell
make kind-start
```

Make sure you use the `kind-nsm` context:
```shell
kubectl config use-context kind-nsm
```

### NSM infra deployment

NSM's core components are started as DaemonSets. By default all the images are downloaded off the [official Dockerhub of the project](https://hub.docker.com/u/networkservicemesh).

Note: Make sure that you've initialized helm before that. If not, use - `make helm-init`

```shell
make helm-install-nsm
```

If there is a need to run a particular version of the NSM, checkout the code under `NSM_PATH` and then ensure the containers are built and loaded. Run these commands in `examples` and after the Kubernetes cluster is initialized:

```shell
make k8s-save k8s-load-images
```

## Updating dependencies on the [networkservicemesh/](https://github.com/networkservicemesh/networkservicemesh) repo

examples/ uses go modules for its dependencies.  Many of these are against the [networkservicemesh/](https://github.com/networkservicemesh/networkservicemesh) repo.

A convenience script is provided for updating these dependencies [scripts/update_networkservicemesh.sh](https://github.com/networkservicemesh/examples/blob/master/scripts/update_networkservicemesh.sh) - which will update `examples/` dependencies to the [networkservicemesh/](https://github.com/networkservicemesh/networkservicemesh) repo. The default is the HEAD of the `master` branch, but this can be changed by passing a argument at the command line to the script:

 `./scripts/update_networkservicemesh.sh [<branch>|<local path>]`

## Adding more examples

Please refer to [examples/README.md](examples/README.md)
