# Create a Network Service Mesh example

To add a new example, you should create a folder under `examples` and add a `Makefile` based on the following template:

```Makefile
NAME = <example name>
CONTAINERS = <container 1> <container 2> <container 3>
AUX_CONTAINERS = <aux container 1> <aux container 2>
PODS = <pod 1> <pod 2>
CHECK = <a command to check the operability of the deployed example>

include $(TOP)/mk/targets.mk
```

* `NAME` - name of the example, e.g. `proxy`

* `DESCRIPTION` - a short, one line description of the example

* `CONTAINERS` - list of all the containers to be built. Each of these should have a folder under `examples/<NAME>`, e.g. `examples/proxy/nginx`. This folder should have a file called `Dockerfile` to describe how the container is built. The `Dockerfile` is assumed to be executed from the top level project folder, i.e. the paths referenced in it should look like `examples/proxy/nginx/html`.

* `AUX_CONTAINERS` - specify a dependency container from another example. This allows for example to share container build definitions. The container name has to be in the form of `<DEP_NAME>-<DEP_CONTAINER>`, where `<DEP_NAME>` is the name of the dependency example, and `<DEP_CONTAINER>` is the name of the container within that example.

* `PODS` - list of the pods to be deployed. Each of the names here should correspond to a file in the example's `k8s` folder. E.g. `examples/proxy/k8s/proxy-nsc.yaml`

* `NETWORK_SERVICES` - a list of the Network Services to be deployed before the Endpoints that implement them. Each of the names here should correspond to a file in the example's `k8s` folder. E.g. `examples/secure-intranet/k8s/secure-intranet.yaml`.

* `CHECK` - a command to be executed to verify the operability of the deployment. The command is executed from the `examples` folder. It assumes all paths are relative to it.

* `FAIL_GOLINT` - shall the golang lint fail. Defaults to true, but should be unused with `FAIL_GOLINT =` in case the example does not contain any go code.

Adding an example will generate the following new make targets:

* `k8s-<NAME>-build` - builds the container images as specified in `CONTAINER`

* `k8s-<NAME>-save` - saves the container images. Invokes `k8s-<NAME>-build`

* `k8s-<NAME>-load-images` - loads the images specified in `CONTAINER` to the k8s cluster infrastructure

* `k8s-<NAME>-deploy` - deploys the pods specified in `PODS`

* `k8s-<NAME>-delete` - deletes the pods specified in `PODS`

* `k8s-<NAME>-%-deploy` - a wildcard target to match pod deployments

* `k8s-<NAME>-<POD NAME>-deploy` - a concrete target for pod deployments, e.g. `k8s-<NAME>-<pod 1>-deploy` `k8s-<NAME>-<pod 2>-deploy`

* `k8s-<NAME>-check` - a target to verify the operability of the example after being deployed. Invokes `${CHECK}`
