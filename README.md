# Network Service Mesh Examples

This repository contains examples and use-cases for Network Service Mesh. It is an independent way to deploy both NSM and a selection of examples, implemented as an overlay over the original `netowrkservicemesh` reporsitory.

## Quick Start

### Control where NSM code is with `NSM_PATH`

The main cluster and infrastructure deployment targets are executed straight from the upstream `netowrkservicemesh` repository. The path to it is set by the environment `NSM_PATH`, with a default value of `../networkservicemesh`. The easiest way to use it is to download both `networkservicemesh` and `examples` in the same root folder and then follow the nex intructions.

### Run the `examples`

In the `examples` repository folder, execute the following set of commands:

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

If there is a need to run a particular version of the NSM, checkout the code under `NSM_PATH` and then ensure the conteiners are built and loaded. Run these commands in `examples` and after the Kubernetes cluster is initalised:

```shell
make k8s-save k8s-load-images
```

## Adding more examples

Please refer to [examples/README.md](examples/README.md)
