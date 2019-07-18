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
	 bridge-domain                  A simple VPP bridge domain example
	 envoy_interceptor              No description set
	 icmp                           Basic kernel interface ICMP reposnder
	 proxy                          HTTP reverse proxy, which maps the HTTP requests to NSM Client requests
	 secure-intranet                The *Sarah* Secure Intranet Connectivity implementation
	 vpp-icmp                       Basic memif interface ICMP reposnder with VPP

 Get the full description of the example by calling:

	 make <example-name>-describe
```

As seen ont he last line, there is a possibility to run `make <example>-describe` and get a more detailed explanation of the particular application. Please consider installing `consolemd` (`pip install consolemd`) for a better console experience browsing the documentation.

### Run the `examples`

In the `examples` repository folder, execute the following set of commands.  These commands are for the proxy example.  Change the term "proxy" for other examples:

```shell
make vagrant-start

. ./scripts/vagrant.sh

make k8s-infra-deploy

make k8s-proxy-save k8s-proxy-load-images

make k8s-proxy-deploy

make k8s-proxy-check
```

## More details

The repo follows the main NSM development and deployment model based on `Vagrant`. Please refer to [NSM's QUICK-START.md](https://github.com/networkservicemesh/networkservicemesh/blob/master/docs/QUICK-START.md) for detailed instructions on how to set-up the development environment.

### Cluster setup

By default, the cluster is deployed with `Vagrant` using the following `make` target:

```shell
make vagrant-start
```

And then initialize the Kubernetes cluster access with:
```shell
. ./scripts/vagrant.sh
```

### NSM infra deployment

NSM's core components are started as DaemonSets. By default all the images are downloaded off the [official Dockerhub of the project](https://hub.docker.com/u/networkservicemesh).

```shell
make k8s-infra-deploy
```

If there is a need to run a particular version of the NSM, checkout the code under `NSM_PATH` and then ensure the containers are built and loaded. Run these commands in `examples` and after the Kubernetes cluster is initialized:

```shell
make k8s-save k8s-load-images
```

## Adding more examples

Please refer to [examples/README.md](examples/README.md)
