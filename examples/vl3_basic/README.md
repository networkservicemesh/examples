# virtual layer 3

This example is an NSE that creates a L3 routing domain between NSC workloads.  Each NSE
performs the following:

1. Creates an IPAM composite endpoint with a /24 prefix pulled from the /16 prefix given in
   the `endpoint.ipam` objects in the configmap.

1. Creates a virtual L3 composite endpoint that does the following upon receipt of NS requests:

   1. if the NS request is from an app workload NSC,
      1. respond with the IP context set for its route for the /24 subnet it handles IPAM for
         1. program VPP agent for the NSC connection with the request parameters
      1. create a thread that
         1. finds all other NSEs for the same network service type
         1. for each other NSE to peer with
            1. if not already connected to it, create a NS connection request with
               1. source route set to the /24 it handles IPAM for
               1. the destination endpoint of the target peer NSE 
               1. the destination NSM for the target peer NSE
               1. upon request response, program the VPP agent for the peer connection
   
   1. otherwise, the NS request is from a peer virtual-L3 NSE,
      1. set the destRoutes to the /24 that the NSE handles IPAM for
      1. respond
      1. setup VPP agent for the peer connection

## Single NSM Domain

### Constraints

1. This currently only works with a custom version of the NSM installation.

   ```bash
   $ cd $GOPATH/src/github.com/
   $ mkdir networkservicemesh
   $ cd networkservicemesh
   $ git clone https://github.com/tiswanso/networkservicemesh
   $ cd networkservicemesh
   $ git checkout vl3_api_rebase
      $
   $ cd $GOPATH/src/github.com/networkservicemesh
   $ git clone https://github.com/tiswanso/examples
   $ cd examples
   $ git checkout <this branch >
   ```
   
2. The `demo_*.sh` scripts in this repo work with `demo-magic` which has a dependency on `pv` (ie. `brew install pv`)

### Usage

#### Helloworld example

```
$ examples/vl3_basic/scripts/demo_vl3_single.sh --kconf_clus1=<path to your kubeconfig> --hello
```

#### Mysql example

```
$ examples/vl3_basic/scripts/demo_vl3_single.sh --kconf_clus1=<path to your kubeconfig> --mysql
```

#### Validate vl3 helloworld client inter-connectivity

```
KCONF=<path to your kubeconfig> ./examples/vl3_basic/scripts/check_vl3.sh
```

#### Cleanup example

```
$ examples/vl3_basic/scripts/demo_vl3_single.sh --kconf_clus1=<path to your kubeconfig> --mysql --hello --nowait --delete
```


## Multiple Domain Usage

### Helloworld Demo example

1. Create an AWS EKS and GKE cluster using the below `Public Cloud` instructions.

1. Use script to install inter-domain NSM & helloworld.

   ```bash
   $ cd $GOPATH/src/github.com/networkservicemesh/examples
   $ examples/vl3_basic/scripts/demo_vl3.sh --kconf_clus1=${KCONFAWS} --kconf_clus2=${KCONFGKE} --hello --nowait
   ```

1. Validation:

   1. On each cluster exec into a helloworld pod's `kali` container

      ```bash
      $ awsHello=$(kubectl get pods --kubeconfig ${KCONFAWS} -l "app=helloworld" -o jsonpath="{.items[0].metadata.name}")
      $ gkeHello=$(kubectl get pods --kubeconfig ${KCONFGKE} -l "app=helloworld" -o jsonpath="{.items[0].metadata.name}")
      $ awsHelloIp=$(kubectl exec --kubeconfig ${KCONFAWS} -t ${awsHello} -c kali -- ip a show dev nsm0 | grep inet | awk '{ print $2 }' | cut -d '/' -f 1)
      $ gkeHelloIp=$(kubectl exec --kubeconfig ${KCONFGKE} -t ${gkeHello} -c kali -- ip a show dev nsm0 | grep inet | awk '{ print $2 }' | cut -d '/' -f 1)
      $ # curl from aws to gke
      $ kubectl exec --kubeconfig ${KCONFAWS} -t ${awsHello} -c kali -- curl http://${gkeHelloIp}:5000/hello
      $ # curl from gke to aws
      $ kubectl exec --kubeconfig ${KCONFGKE} -t ${gkeHello} -c kali -- curl http://${awsHelloIp}:5000/hello
      ```

### Mysql Demo example

1. Create an AWS EKS and GKE cluster using the below `Public Cloud` instructions.

1. Use script to install inter-domain NSM & mysql DB replication.

   ```bash
   $ cd $GOPATH/src/github.com/networkservicemesh/examples
   $ examples/vl3_basic/scripts/demo_vl3.sh --kconf_clus1=${KCONFAWS} --kconf_clus2=${KCONFGKE} --mysql --nowait
   ```

The result is NSM & vL3 interdomain deployed on AWS EKS and GKE clusters with a mysql-master on the EKS cluster
and mysql-slave on the GKE cluster.  DB replication should be operational between the master and slave.

1. Check whether replication is setup.

   1. On master use
   
      ```
      masterPod=$(kubectl get pods --kubeconfig ${KCONFAWS} -l "app.kubernetes.io/name=mysql-master" -o jsonpath="{.items[0].metadata.name}")
      kubectl exec -it ${masterPod} -c mysql-master --kubeconfig ${KCONFAWS} bash
      root@vl3-mysql-master-687d5c7d94-8mt4h:/# mysql -u root -ptest
      mysql> show processlist;
      +----+------+------------------+------+-------------+------+---------------------------------------------------------------+------------------+
      | Id | User | Host             | db   | Command     | Time | State                                                         | Info             |
      +----+------+------------------+------+-------------+------+---------------------------------------------------------------+------------------+
      |  2 | demo | 172.31.0.5:59320 | NULL | Binlog Dump |  274 | Master has sent all binlog to slave; waiting for more updates | NULL             |
      |  3 | root | localhost        | NULL | Query       |    0 | starting                                                      | show processlist |
      +----+------+------------------+------+-------------+------+---------------------------------------------------------------+------------------+
      2 rows in set (0.00 sec)
      ```
      
   1. On slave use `show slave status\G`:
      
      ```
      slavePod=$(kubectl get pods --kubeconfig ${KCONFGKE} -l "app.kubernetes.io/name=mysql-slave" -o jsonpath="{.items[0].metadata.name}")
      kubectl exec -it ${slavePod} -c mysql-slave --kubeconfig ${KCONFGKE} bash
      root@vl3-mysql-slave-76b8d9c847-2zr5x:/# mysql -u root -ptest
      mysql> show slave status \G
      *************************** 1. row ***************************
                     Slave_IO_State: Waiting for master to send event
                        Master_Host: 172.31.127.1
                        Master_User: demo
                        Master_Port: 3306
                      Connect_Retry: 60
                    Master_Log_File: vl3-mysql-master-687d5c7d94-8mt4h-bin.000003
                Read_Master_Log_Pos: 154
                     Relay_Log_File: vl3-mysql-slave-76b8d9c847-2zr5x-relay-bin.000005
                      Relay_Log_Pos: 423
              Relay_Master_Log_File: vl3-mysql-master-687d5c7d94-8mt4h-bin.000003
                   Slave_IO_Running: Yes
                  Slave_SQL_Running: Yes
                    Replicate_Do_DB:
                Replicate_Ignore_DB:
                 Replicate_Do_Table:
             Replicate_Ignore_Table:
            Replicate_Wild_Do_Table:
        Replicate_Wild_Ignore_Table:
                         Last_Errno: 0
                         Last_Error:
                       Skip_Counter: 0
                Exec_Master_Log_Pos: 154
                    Relay_Log_Space: 3053547
                    Until_Condition: None
                     Until_Log_File:
                      Until_Log_Pos: 0
                 Master_SSL_Allowed: No
                 Master_SSL_CA_File:
                 Master_SSL_CA_Path:
                    Master_SSL_Cert:
                  Master_SSL_Cipher:
                     Master_SSL_Key:
              Seconds_Behind_Master: 0
      Master_SSL_Verify_Server_Cert: No
                      Last_IO_Errno: 0
                      Last_IO_Error:
                     Last_SQL_Errno: 0
                     Last_SQL_Error:
        Replicate_Ignore_Server_Ids:
                   Master_Server_Id: 1
                        Master_UUID: 1eaaeeb1-056d-11ea-bd3a-16a547414672
                   Master_Info_File: /var/lib/mysql/master.info
                          SQL_Delay: 0
                SQL_Remaining_Delay: NULL
            Slave_SQL_Running_State: Slave has read all relay log; waiting for more updates
                 Master_Retry_Count: 86400
                        Master_Bind:
            Last_IO_Error_Timestamp:
           Last_SQL_Error_Timestamp:
                     Master_SSL_Crl:
                 Master_SSL_Crlpath:
                 Retrieved_Gtid_Set:
                  Executed_Gtid_Set:
                      Auto_Position: 0
               Replicate_Rewrite_DB:
                       Channel_Name:
                 Master_TLS_Version:
      1 row in set (0.00 sec)
      ```
   
1. Run the following script to test db replication:

   ```bash
   $ examples/vl3_basic/scripts/check_mysql.sh --kconf_clus1=${KCONFAWS} --kconf_clus2=${KCONFGKE} --populate
   ```


### Install vL3 NSEs and helloworld NSCs

The script `examples/vl3_basic/scripts/vl3_interdomain.sh` will install the virtual L3 NSE
daemonset in a cluster, wait for the pods to come up, and install the `helloworld` pods as
NSCs.

The script requires the env var `REMOTE_CLUSTERIP` to be set.  The format is a comma separated
list of IPs that act as the remote cluster's NSM API endpoints.  Its value is the NodePort IP for
the `nsmgr` Kubernetes service created in the `nsm_install_interdomain.sh` NSM installation step.

```bash
REMOTE_IP=${cluster2_nsmgr_ip},${cluster3_nsmgr_ip} KCONF=cluster1.kconf examples/vl3_basic/scripts/vl3_interdomain.sh
REMOTE_IP=${cluster1_nsmgr_ip},${cluster3_nsmgr_ip} KCONF=cluster2.kconf examples/vl3_basic/scripts/vl3_interdomain.sh
REMOTE_IP=${cluster1_nsmgr_ip},${cluster2_nsmgr_ip} KCONF=cluster3.kconf examples/vl3_basic/scripts/vl3_interdomain.sh

```

#### Validating Connectivity

The `helloworld` pods should have connectivity to each other across clusters through the
NSM interdomain dataplane connections.  The following is an example of HTTP access between
the `helloworld` pods in 2 clusters.

```bash
$ kubectl get pods --kubeconfig clus2.kubeconfig
NAME                            READY   STATUS    RESTARTS   AGE
helloworld-v1-fc4998b76-rkf8b   3/3     Running   0          10m
helloworld-v1-fc4998b76-vj76w   3/3     Running   0          10m
vl3-nse-ucnf-cvhzf              1/1     Running   0          11m
$ kubectl get pods --kubeconfig clus1.kubeconfig
NAME                            READY   STATUS    RESTARTS   AGE
helloworld-v1-fc4998b76-j6pgw   3/3     Running   0          12m
helloworld-v1-fc4998b76-tm6tq   3/3     Running   0          12m
vl3-nse-ucnf-4lf6k              1/1     Running   0          13m
vl3-nse-ucnf-jxdlp              1/1     Running   0          13m

$ kubectl exec --kubeconfig clus1.kubeconfig -t helloworld-v1-fc4998b76-tm6tq ip a
Defaulting container name to helloworld.
Use 'kubectl describe pod/helloworld-v1-fc4998b76-tm6tq -n default' to see all of the containers in this pod.
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
2: tunl0@NONE: <NOARP> mtu 1480 qdisc noop state DOWN group default qlen 1
    link/ipip 0.0.0.0 brd 0.0.0.0
4: eth0@if76: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default
    link/ether 02:8b:0d:cb:b0:fb brd ff:ff:ff:ff:ff:ff
    inet 192.150.232.101/32 scope global eth0
       valid_lft forever preferred_lft forever
77: nsm0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UNKNOWN group default qlen 1000
    link/ether e2:33:29:ba:8f:53 brd ff:ff:ff:ff:ff:ff
    inet 10.60.232.1/30 brd 10.60.232.3 scope global nsm0
       valid_lft forever preferred_lft forever
$ kubectl exec --kubeconfig clus2.kubeconfig -t helloworld-v1-fc4998b76-vj76w ip a
Defaulting container name to helloworld.
Use 'kubectl describe pod/helloworld-v1-fc4998b76-vj76w -n default' to see all of the containers in this pod.
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
2: tunl0@NONE: <NOARP> mtu 1480 qdisc noop state DOWN group default qlen 1000
    link/ipip 0.0.0.0 brd 0.0.0.0
4: eth0@if88: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default
    link/ether 16:3e:e1:d6:f4:f8 brd ff:ff:ff:ff:ff:ff
    inet 192.178.180.209/32 scope global eth0
       valid_lft forever preferred_lft forever
90: nsm0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UNKNOWN group default qlen 1000
    link/ether 9e:cc:7c:b7:63:6c brd ff:ff:ff:ff:ff:ff
    inet 10.60.180.1/30 brd 10.60.180.3 scope global nsm0
       valid_lft forever preferred_lft forever
$ kubectl exec --kubeconfig clus2.kubeconfig -t helloworld-v1-fc4998b76-vj76w -- curl http://10.60.232.1:5000/hello
Defaulting container name to helloworld.
Use 'kubectl describe pod/helloworld-v1-fc4998b76-vj76w -n default' to see all of the containers in this pod.
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    59  100    59    0     0    312      0 --:--:-- --:--:-- --:--:--   312
Hello version: v1, instance: helloworld-v1-fc4998b76-tm6tq

$ kubectl exec --kubeconfig clus1.kubeconfig -t helloworld-v1-fc4998b76-tm6tq -- curl http://10.60.180.1:5000/hello
Defaulting container name to helloworld.
Use 'kubectl describe pod/helloworld-v1-fc4998b76-tm6tq -n default' to see all of the containers in this pod.
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    59  100    59    0     0    366      0 --:--:-- --:--:-- --:--:--   368
Hello version: v1, instance: helloworld-v1-fc4998b76-vj76w
```

## Public Cloud Setup

This section will show the use of `networkservicemesh` project's makefiles to setup public cloud clusters
to run the vL3 demos.

### Prereq

1. Checkout local NSM

   ```bash
   $ cd ..
   $ git clone https://github.com/tiswanso/networkservicemesh 
   $ cd networkservicemesh
   $ git checkout vl3_api_rebase
   ```

### GKE

1. Select a project ID to use:

   ```bash
   $ gcloud projects list
   ```

1. Use makefile to start GKE cluster and setup firewall rules.  Note this creates a GKE cluster called `dev` in your GCP project.

   ```bash
   $ GKE_PROJECT_ID=<your project ID> make gke-start
   ```

1. For inter-domain: The NSM make machinery cluster startup creates firewall rules for proxy-nsmgr service.
   An ingress rule on the nodes is added for port range `5000 - 5006` src `0.0.0.0/0`.
   If it's not there, do this via gcloud console's VPC Firewall rules or the below commands:

   ```bash
   $ gcloud compute firewall-rules create proxynsmgr-svc --allow=tcp:5000-5006 --direction=INGRESS --priority=900 --source-ranges="0.0.0.0/0" --project <your proj>
   $ # to validate the rule creation
   $ gcloud compute firewall-rules list --project <your proj>
   ```
   
1. copy kubeconfig to a separate file for use with scripts
   
   ```bash
   $ cp ~/.kube/config ~/.kube/gke-dev.kubeconfig
   $ KCONFGKE=~/.kube/gke-dev.kubeconfig
   ```

1. Proceed with normal NSM installation using `${KCONFGKE}` in the `kubeconfig` script params


### AWS

1. Setup your AWS CLI environment for the project you want to use.

1. Use makefile to start AWS cluster and setup firewall rules.  Note this creates a AWS EKS cluster in your project.

   ```bash
   $ make aws-start
   ```

1. For inter-domain: The NSM make machinery cluster startup creates firewall rules for proxy-nsmgr service.
   An ingress rule on the nodes is added for port range `5000 - 5006` src `0.0.0.0/0`.
   If it's not there, create it via AWS console's VPC Firewall rules.

1. copy kubeconfig to a separate file for use with scripts

   ```bash
   $ cp ~/.kube/config ~/.kube/aws-nsm.kubeconfig
   $ KCONFAWS=~/.kube/aws-nsm.kubeconfig
   ```

1. Proceed with normal NSM installation  using `${KCONFAWS}` in the `kubeconfig` script params

## KinD Setup

Using multiple KinD clusters hosted on the same docker instance allows the KinD k8s nodes
to have IP communication across the cluster boundary (due to the common docker bridge).
Therefore, it's possible to replicate the NSM interdomain setup and vL3 examples on KinD.

The following are instructions for starting 2 KinD clusters with port mappings to allow
for access to each cluster's NSM Jaeger UI (NodePort service).

1. Cluster 1 bringup

   ```
   $ JAEGER_HOSTPORT=38901
   $ cat <<EOF > kind1.yaml
   kind: Cluster
   apiVersion: kind.sigs.k8s.io/v1alpha3
   nodes:
   - role: control-plane
     extraPortMappings:
     - containerPort:  31922
       hostPort: ${JAEGER_HOSTPORT}
   EOF

   $ kind create cluster --config kind1.yaml --name kind1 
   ```

1. Cluster 2 bringup

   ```
   $ JAEGER_HOSTPORT=38902
   $ cat <<EOF > kind2.yaml
   kind: Cluster
   apiVersion: kind.sigs.k8s.io/v1alpha3
   nodes:
   - role: control-plane
     extraPortMappings:
     - containerPort:  31922
       hostPort: ${JAEGER_HOSTPORT}
   EOF

   $ kind create cluster --config kind2.yaml --name kind2 
   ```

1. Run the demo script against the 2 clusters.  The following example runs vL3 with the
   `helloworld` example.

   ```
   $ KIND1="$(kind get kubeconfig-path --name="kind1")"
   $ KIND2="$(kind get kubeconfig-path --name="kind2")"
   $ examples/vl3_basic/scripts/demo_vl3.sh --kconf_clus1=${KIND1} --kconf_clus2=${KIND2} --hello
   ```

   __NOTE:__  The latest versions of `kind` no longer support the `kubeconfig-path` option.
   Instead, use `kind get kubeconfig --name kind1` to the kubeconfig file contents
   and save it to a file.

1. NSM gets installed into the namespace `nsm-system` and the `jaeger` UI is reachable
   via browser on the localhost at:

   1. `http://127.0.0.1:38901` -- Jaeger KinD cluster 1
   1. `http://127.0.0.1:38902` -- Jaeger KinD cluster 2
   

## References

1. [Interdomain NSM](https://github.com/networkservicemesh/networkservicemesh/issues/714)
1. [Build instructions](BUILD.md)

## TODOs

1. DNS integration for workload service discovery
