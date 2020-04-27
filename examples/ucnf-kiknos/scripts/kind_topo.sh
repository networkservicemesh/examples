#!/usr/bin/env bash

pushd "$(dirname $0)/../../../"
pwd

CLUSTER1=${CLUSTER1:-cl1}
CLUSTER2=${CLUSTER2:-cl2}
VPP_AGENT=${VPP_AGENT:-rastislavszabo/vl3_ucnf-vl3-nse:v4}
NSE_HUB=networkservicemesh
NSE_TAG=kiknos
PULLPOLICY=${PULLPOLICY:-IfNotPresent}
SERVICENAME=${SERVICENAME:-icmp-responder}
KUBECONFDIR=${KUBECONFDIR:-~/kubeconfigdir}

if [ "$1" == "--delete" ]; then
  echo "Delete clusters: $CLUSTER1, $CLUSTER2"
  KIND_CLUSTER_NAME=$CLUSTER1 make kind-stop
  KIND_CLUSTER_NAME=$CLUSTER2 make kind-stop
  exit 0
fi

K8S_STARTPORT=${K8S_STARTPORT:-38790}
JAEGER_STARTPORT=${JAEGER_STARTPORT:-38900}

function kindCreateCluster {
    local name=$1; shift
    local kconf=$1; shift
    if [[ $# > 1 ]]; then
        local hostip=$1; shift
        local portoffset=$1; shift
    fi

    if [[ -n ${hostip} ]]; then
        HOSTIP=${hostip}
        K8S_HOSTPORT=$((${K8S_STARTPORT} + $portoffset))
        JAEGER_HOSTPORT=$((${JAEGER_STARTPORT} + $portoffset))
        cat <<EOF > ${KINDCFGDIR}/${name}.yaml
kind: Cluster
apiVersion: kind.sigs.k8s.io/v1alpha3
kubeadmConfigPatchesJson6902:
- group: kubeadm.k8s.io
  version: v1beta2
  kind: ClusterConfiguration
  patch: |
    - op: add
      path: /apiServer/certSANs/-
      value: "${HOSTIP}"
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 6443
    hostPort: ${K8S_HOSTPORT}
    listenAddress: ${HOSTIP}
  - containerPort:  31922
    hostPort: ${JAEGER_HOSTPORT}
    listenAddress: ${HOSTIP}
EOF
        kind create cluster --name ${name} --config ${KINDCFGDIR}/${name}.yaml
    else
        kind create cluster --name ${name}
    fi
    kind get kubeconfig --name=${name} > ${kconf}
}

echo "Build ucnf image with kiknos base"
VPP_AGENT=${VPP_AGENT} TAG=kiknos make k8s-universal-cnf-save &
dockerBuildProcess=$!

function installNSM() {
  local cluster=$1; shift

  echo "Helm init: $cluster"
  kubectl config use-context "kind-$cluster"
  SPIRE_ENABLED=false INSECURE=true make helm-init

  echo "Install NSM: $cluster"
  kubectl --context "kind-$cluster" wait -n kube-system --timeout=150s --for condition=Ready --all pods -l app=helm
  SPIRE_ENABLED=false INSECURE=true make helm-install-nsm
  kubectl wait --context "kind-$cluster" --timeout=150s --for condition=Ready -l "app in (nsm-admission-webhook,nsmgr-daemonset,proxy-nsmgr-daemonset,nsm-vpp-plane)" -n nsm-system pod
}

function startCluster() {
  local cluster=$1; shift

  echo "Start kind clusters: $cluster"
  kindCreateCluster "$cluster" "$KUBECONFDIR/$cluster.kubeconfig"

  wait $dockerBuildProcess
  echo "Load images into: $cluster"
  KIND_CLUSTER_NAME=$cluster make k8s-universal-cnf-load-images
}

for cluster in "$CLUSTER1" "$CLUSTER2"; do
  startCluster "$cluster" &
done

wait

for cluster in "$CLUSTER1" "$CLUSTER2"; do
  installNSM "$cluster"
done

echo "Install NSE into cluster: $CLUSTER1"
ip=$(kubectl --context "kind-$CLUSTER1" get nodes \
  --selector='node-role.kubernetes.io/master' \
  -o jsonpath='{ $.items[*].status.addresses[?(@.type=="InternalIP")].address }')
baseaddr="$(echo "${ip}" | cut -d. -f1-3)"
lsv="$(echo "${ip}" | cut -d. -f4)"
lsv=$(( $lsv + 1 ))
helm template ./examples/ucnf-kiknos/helm/kiknos_vpn_endpoint --set org=${NSE_HUB} \
  --set tag=${NSE_TAG} \
  --set pullPolicy="${PULLPOLICY}" \
  ${IPAMPOOL:+ --set ipam.prefixPool=${IPAMPOOL}} \
  ${IPAMOCTET:+ --set ipam.uniqueOctet=${IPAMOCTET}} \
  ${CNNS_NSRADDR:+ --set cnns.nsr.addr=${CNNS_NSRADDR}} \
  ${CNNS_NSRPORT:+ --set cnns.nsr.port=${CNNS_NSRPORT}} \
  --set nsm.serviceName="${SERVICENAME}" \
  --set ikester.network.redInterfaceIP="${baseaddr}.${lsv}" | kubectl --context "kind-$CLUSTER1" apply -f -

kubectl --context "kind-$CLUSTER1" wait -n default --timeout=150s --for condition=Ready --all pods --selector k8s-app &
kubectl --context "kind-$CLUSTER1" wait -n default --timeout=150s --for condition=Ready --all pods --selector networkservicemesh.io/app &
wait

echo "Install NSE into cluster: $CLUSTER2"
helm template ./examples/ucnf-kiknos/helm/kiknos_vpn_endpoint \
  --set org=${NSE_HUB} --set tag=${NSE_TAG} \
  --set pullPolicy="${PULLPOLICY}" \
  ${IPAMPOOL:+ --set ipam.prefixPool=${IPAMPOOL}} \
  ${IPAMOCTET:+ --set ipam.uniqueOctet=${IPAMOCTET}} \
  ${CNNS_NSRADDR:+ --set cnns.nsr.addr=${CNNS_NSRADDR}} \
  ${CNNS_NSRPORT:+ --set cnns.nsr.port=${CNNS_NSRPORT}} \
  --set nsm.serviceName="${SERVICENAME}" \
  --set aio.network.redInterfaceIP=172.17.0.201 \
  --set aio.network.redInterfaceMAC=02:00:00:00:00:06 \
  --set strongswan.network.remoteAddr=172.17.0.200 \
  --set strongswan.network.localSubnet=172.31.23.0/24 \
  --set strongswan.network.remoteSubnet=172.31.22.0/24 \
  --set ikester.enabled=true \
  --set ikester.network.remoteIP=172.17.0.200 | kubectl --context "kind-$CLUSTER2" apply -f -

kubectl --context "kind-$CLUSTER2" wait -n default --timeout=150s --for condition=Ready --all pods --selector k8s-app &
kubectl --context "kind-$CLUSTER2" wait -n default --timeout=150s --for condition=Ready --all pods --selector networkservicemesh.io/app &
wait

echo "Create hello world pods"
helm template ./examples/ucnf-kiknos/helm/vl3_hello | kubectl --context "kind-$CLUSTER1" apply -f -
helm template ./examples/ucnf-kiknos/helm/vl3_hello --set nsm.serviceName="$SERVICENAME" | kubectl --context "kind-$CLUSTER2" apply -f -

kubectl --context "kind-$CLUSTER1" wait -n default --timeout=150s --for condition=Ready --all pods -l app=icmp-responder &
kubectl --context "kind-$CLUSTER2" wait -n default --timeout=150s --for condition=Ready --all pods -l app=icmp-responder &
wait

CLUSTER1=$CLUSTER1 CLUSTER2=$CLUSTER2 SERVICENAME=$SERVICENAME ./examples/ucnf-kiknos/scripts/test_vpn_conn.sh
