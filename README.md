# Network Service Mesh Examples

This repository contains examples and use-cases for Network Service Mesh. It is an independent way to deploy both NSM and a selection of examples.

## Quick Start

After downloading the repository, execute the following set of commands:

```shell
make vagrant-start

make k8s-config

make k8s-infra-deploy

make k8s-proxy-save k8s-proxy-deploy

make k8s-proxy-check
```

## More details

The repo follows the main NSM development and deployment model based on `Vagrant`. Please refer to [NSM's QUICK-START.md](https://github.com/networkservicemesh/networkservicemesh/blob/master/docs/QUICK-START.md) for detailed instructions on how to set-up the development environment.

### Cluster setup

By default, the cluster is deployed with `Vagrant` using the following `make` target:

```shell
make vagrant-start
```

### Cluster initialization

The default Kubernetes cluster needs to be initialized before we can deploy NSM:

```shell
make k8s-config
```

### NSM infra deployment

NSM's core components are started as DaemonSets. All the images are downloaded off the [official Dockerhub of the project](https://hub.docker.com/u/networkservicemesh).

```shell
make k8s-infra-deploy
```

**Note** that for the time being, we use the `latest` image tag for deployment. This could lead to non-reproducible effects, so keep in mind that it will be changed once NSM releases an official set of images.

## Adding more examples

Please refer to [examples/README.md](examples/README.md)
