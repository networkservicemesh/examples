include $(TOP)/mk/targets.mk

CLUSTER1?=kiknos-demo-1
CLUSTER2?=kiknos-demo-2
ORG=mmatache
AWS_KEY_PAIR?=kiknos-asa


kiknos-aws:
	$(TOP)/examples/ucnf-kiknos/scripts/start_topo.sh --org=${ORG} --cluster1=${CLUSTER1} --cluster2=${CLUSTER2} \
		--aws_key_pair=${AWS_KEY_PAIR} --aws --deploy_asa

kiknos-kind:
	$(TOP)/examples/ucnf-kiknos/scripts/start_topo.sh --org=${ORG} --cluster1=${CLUSTER1} --cluster2=${CLUSTER2}

kiknos-test-conn:
	CLUSTER1=${CLUSTER1} CLUSTER2=${CLUSTER2} $(TOP)/examples/ucnf-kiknos/scripts/test_vpn_conn.sh

kiknos-test-istio-conn:
	CLUSTER1=${CLUSTER1} CLUSTER2=${CLUSTER2} $(TOP)/examples/ucnf-kiknos/scripts/test_istio_vpn_conn.sh

kiknos-dump-clusters-state:
	CLUSTER1=${CLUSTER1} CLUSTER2=${CLUSTER2} $(TOP)/examples/ucnf-kiknos/scripts/dump_clusters_state.sh