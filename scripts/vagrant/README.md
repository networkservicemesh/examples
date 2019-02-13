# Setup the Vagrant environment

## Intro

This Vagrant directory provides a simple environment in which to test various components of Network Service Mesh.

## Prerequisites

Sshfs is used to mount the `/vagrant` directory of the guest. Hence the vagrant-sshfs plugin for Vagrant must be installed.
If `libvirt` is used, the vagrant-libvirt plugin must also be installed.

## Starting Vagrant

```bash
cd scripts/vagrant/
vagrant up
```

## Pointing your local kubectl at the Vagrant K8s

Once Vagrant has completed:

```bash
. scripts/vagrant/env.sh
```

This sources a file that sets up KUBECONFIG to point to
`scripts/vagrant/.kube/config`

You can test it with:

```bash
kubectl version
```

## Getting locally built images into Vagrant VM

```bash
make docker-build
make docker-save
cd dataplanes/vpp
make docker-build
make docker-save
```

This will create the relevant Docker images and put them in `scripts/vagrant/images/`.

If you already have Vagrant running, you can get those images imported into your
guest Docker, by running:

```bash
cd scripts/vagrant/
vagrant ssh
bash /vagrant/scripts/load_images.sh
```

If you don't have Vagrant running, the images will be loaded into the VM automatically when the following:

```bash
vagrant up
```

is run for the first time, or after running ```vagrant destroy```

## Deploying Skydive

If you want to deploy `Skydive` to monitor the networking in Kubernetes, use the following commands:

```bash
docker pull skydive/skydive
docker save -o scripts/vagrant/images/skydive.tar skydive/skydive
vagrant ssh -c 'sh /vagrant/scripts/load_images.sh'
kubectl create -f scripts/vagrant/skydive.yaml
```

The Skydive analyzer is accessible thanks to a Kubernetes service of type 'NodePort'

You need to identify the Skydive API port to use:

```bash
$ kubectl get svc skydive-analyzer
NAME               TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)                                                         AGE
skydive-analyzer   NodePort   10.110.210.212   <none>        8082:30039/TCP,8082:30039/UDP,12379:31614/TCP,12380:31014/TCP   3m25s
```

The Skydive API is listening on TCP/8082, which, in this example, is bound to TCP/30039

Now identify the IP to use:

```bash
$ kubectl cluster-info
Kubernetes master is running at https://172.28.128.23:6443
```

In this example, the Skydive WebUI will be accessible at http://172.28.128.23:30039

## Running integration tests

You can run integration tests on your laptop (ie, outside of the Vagrant VM) by typing:

```bash
bash # Start new shell, as we will be importing
. scripts/integration-tests.sh
run_tests
exit
```

Note: integration tests are *not* idempotent.  So if you want to run them a second time,
your simplest way to do so is:

```bash
vagrant destroy -f;vagrant up
```

and then run them again.
