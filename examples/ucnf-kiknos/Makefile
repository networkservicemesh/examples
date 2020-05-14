include $(TOP)/mk/targets.mk

CLUSTER1=kiknos-demo-1
CLUSTER2=kiknos-demo-2

kiknos-aws:
	./scripts/start_topo.sh --org=$ORG --cluster1=$CLUSTER1 --cluster2=$CLUSTER2 --aws

kiknos-kind:
	./scripts/start_topo.sh --org=$ORG --cluster1=$CLUSTER1 --cluster2=$CLUSTER2

kiknos-test-conn:
	CLUSTER1=$CLUSTER1 CLUSTER2=$CLUSTER2 ./scripts/test_vpn_conn.sh
