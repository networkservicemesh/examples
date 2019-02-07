# Adding Network Service Mesh Examples

To add a new example, one need to create its folder under `examples` and adda `Makefile` based on the following template:

```Makefile
NAME = <example name>
CONTAINERS = <container 1> <container 2> <container 3>
AUX_CONTAINERS = <aux container 1> <aux container 2>
PODS = <pod 1> <pod 2>
CHECK = <a command to check the operability of the deployed example>

include $(TOP)/mk/targets.mk
```

 * `NAME` - is the name of the example, e.g. `proxy`
 * `CONTAINERS` - is a list of all the containers to be built. Each of these should have a folder under `examples/<NAME>`, e.g. `examples/proxy/nginx`. This folder should have a file called `Dockerfile` to decribe how the container is built. The `Dockerfile` assumes to be executed from the top level project folder, i.e. the paths refernced in it look like `examples/proxy/nginx/html`.
 * `AUX_CONTAINERS` - specify a dependency container from another example. This allows for example to share container build definitions. The container name has to be in the form of `<DEP_NAME>-<DEP_CONTAINER>`, where `<DEP_NAME>` is the name of th dependency example and `<DEP_CONTAINER>` is the name of the contanier within that example.
 * `PODS` - the list of the pods to be deployed. Each of the names here shod correspond to a file in the example's `k8s` folder. E.g. `examples/proxy/k8s/proxy-nsc.yaml`
 * `CHECK` - a command to be executed to verify the operability of the deployment. The command is executed from the examples folder. It assumes all paths are relative to it.

 Adding this will generate the following new make targets:

  * `k8s-<NAME>-build` - a target to build the conatiner images as specified in `CONTAINER`
  * `k8s-<NAME>-save` - a target to save the container images. Invokes `k8s-<NAME>-build`
  * `k8s-<NAME>-load-images` - loads the images specified in `CONTAINER` to the k8s cluster infrastructure
  * `k8s-<NAME>-deploy` - deploys the pods specifed in `PODS`
  * `k8s-<NAME>-delete` - deletes the pods specified in `PODS`
  * `k8s-<NAME>-%-deploy` - a wildcard targed to match pod deployments
  * `k8s-<NAME>-<POD NAME>-deploy` - a concrete targed for pod deploymetns, e.g. `k8s-<NAME>-<pod 1>-deploy` `k8s-<NAME>-<pod 2>-deploy`
  * `k8s-<NAME>-check` - a target to verify the operability of the example after being deployed. Invokes `${CHECK}`
