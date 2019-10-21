# The Universal CNF

Universal CNF (UCNF) is an attempt to implement a swiss-army knife container, which implements basic networking functions useful for demoing NSM. It is currently heavily based on [VPP](https://github.com/FDio/vpp) and [vppagent](https://github.com/ligato/vpp-agent).

## Configuration

UCNF can be deployed and configured to implement various cloud-native networking scenarios. For that, it exposes a configuration file interface, where the solution integrator can program it.

### The configuration file
The configuration of UCNF is a yaml file that resides in `/etc/universal-cnf/config.yaml`. One would typically want to manage these configurations through Kubernetes ConfigMap and mount it as volume. Here is an incomplete `Deployment` which illustrates this concept:

```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
        - name: universal-cnf-client
          image: networkservicemesh/universal-cnf-vppagent:latest
          volumeMounts:
            - mountPath: /etc/universal-cnf/config.yaml
              subPath: config.yaml
              name: universal-cnf-config-volume
      volumes:
        - name: universal-cnf-config-volume
          configMap:
            name: universal-cnf-client
metadata:
  name: ucnf-client
```
Then and sample `ConfigMap` can be modelled as follows:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: universal-cnf-client
data:
  config.yaml: |
    initactions:
      - command:
          name: "vppctl"
          args: ["show", "version"]
```

### Configuration concepts

UCNF is implemented following the Network Service Mesh (NSM) networking model, where there are point to point links established for each service consumption request. Each Network Service (NS) is composed of Endpoints. The composition is happening when the NS Clients request a particular NS. These requests might or might not be labelled and the NSM distributed infrastructure consults the pre-defined `NetworkService` descriptors where the routing rules are defined. A typical CNF will expose one or more NS through one or more Endpoints and will connect to other services and/or Endpoints.

UCNF configuration is based on events and actions. The supported events are generated on initialization and upon Endpoint connection request. The available actions are: command line execution, Client and forwarder configuration.

Here is a more detailed explanation of the supported event types:
 * The initialization event is the first event generated when UCNF starts. The actions associated with it will be executed before anything else in the system. This can typically be used to execute any pre-configured Clients or container wide commands.

 * The Endpoint connection request event is generated when a Client requests a connection from the UCNF announced Endpoint.

The actions which UCNF supports are as follows:
 * Commands are command line execution snippets.
 * Client is a simple NS Client
 * Forwarder config is an implementation specific forwarder configuration. In its current version UCNF configures `vpp` management through the `vppagent`. It is a YAML version of the JSON configuration as explained in the [Ligato plugins documentation](https://docs.ligato.io/en/latest/plugins/vpp-plugins/#l2-plugin).

### The `config.yaml` format

 * `initactions` - a list of actions
    * `command`
        * `name` - the executable name
        * `args` - a list of arguments to be passed to the executable
    * `client`
        * `name` - the name of the NS to be requested
        * `labels` - the labels to be sent with the NS connection request
        * `routes` - a list of IPv4/v6 route prefixes that the Client will announce to the connecting Endpoint
        * `ifname`- the name of the network interface to be created for this connection
    * `dpconfig` - forwarder specific YAML configuration
 * `endpoints`
    * `name` - the name of the NS to be announced
    * `labels` - the labels to be assigned with this Endpoint
    * `ifname` - the base of the name of the network interface to be created upon Client connection. The actual interface name will have an index added to the base
    * `ipam`
        * `prefixpool` - a single prefix to define the IP pool that the IPAM will use do distribute point ot point IP subnets from
        * `routes` - a list of IPv4/v6 route prefixes Endpoint
    * `action` - a single action to be executed on Client connect event. It consist of the same `command`, `client` and `dpconfig` members as described in `initactions`

A sample file to illustrate this scheme is shown below:

```yaml
    initactions:
      - client:
          name: "packet-filtering"
          ifname: "client0"
          routes: ["10.60.3.0/24"]
          labels:
            app: "packet-filter"
    endpoints:
    - name: "packet-filtering"
      labels:
        app: "packet-filter"
      ipam:
        prefixpool: "10.60.3.0/24"
        routes: ["10.60.1.0/24", "10.60.2.0/24"]
      ifname: "endpoint0"
      action:
        dpconfig:
          acls:
            - name: "acl-1"
              rules:
              - action: 2
                iprule:
                  icmp:
                    icmptyperange:
                      first: 8
                      last: 8
                    icmpcoderange:
                      first: 0
                      last: 65535
              - action: 2
                iprule:
                  tcp:
                    sourceportrange:
                      lowerport: 0
                      upperport: 65535
                    destinationportrange:
                      lowerport: 80
                      upperport: 80
              interfaces:
                ingress: ["endpoint0"]
```
