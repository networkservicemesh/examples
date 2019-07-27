# Envoy interceptor

This example demos how Envoy can be used as a transparent proxy, to intercept the NS traffic. We declare a NS named `web-service` and implemented by a single NS endpoint. The endpoint leverages the SDK's built in simple IPAM and adds a new Iptables composite. That new composite calls an external script which redirects all the traffic to a designated port.

A simplified diagram of the demo is shown below:

```
+----------+                         +----------+
|          |                         |          |
|  Alpine  |       web-service       |  Envoy   |
|    NSC   +------------------------->   NSE    |
|          |                         |          |
+----------+                         +----------+

```

## The NS client

The Alpine image is run in a pod annotated with `ns.networkservicemesh.io: web-service`. This lets the NSM admission controller to inject an init container that will request the NS `web-service`.

## Envoy configuration
The envoy [configuration](./envoy-nse/etc/envoy/envoy.yaml) is a simplivied single cluster, single listener with an [envoy.echo](https://www.envoyproxy.io/docs/envoy/latest/configuration/network_filters/echo_filter.html) network filter. It will return all the data received on the configured port `8080`.

### Recognition
The approach for running Envoy with `supervisord` was inspired by the work of Terminus published in their repo [envoy-alpine-base](https://github.com/GetTerminus/envoy-alpine-base) under the [MIT license](https://github.com/GetTerminus/envoy-alpine-base/blob/master/LICENSE).

The script for traffic interception `/usr/bin/iptables.sh` is an almost unmodified copy of the [Istio's istio-iptables.sh](https://raw.githubusercontent.com/istio/istio/master/tools/packaging/common/istio-iptables.sh) used in their `proxy-init` container.
