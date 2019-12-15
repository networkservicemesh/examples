
NAME = 4g-spgw
DESCRIPTION = "4G Network Topology example"
CONTAINERS = dp-init enb-sim sidecar-nse
PODS = spgw-c spgw-u enb-sim rtr
NETWORK_SERVICES = 4g-network
CHECK = scripts/check-connectivity.sh

include $(TOP)/mk/targets.mk


NGIC_NAME=4g-spgw
EXTRA_CFLAGS_CP="-DUSE_AF_PACKET -DPERF_TEST -DSIMU_CP -DSTATIC_ARP -O2"
EXTRA_CFLAGS_DP="-DUSE_AF_PACKET -DPERF_TEST -DSTATIC_ARP -O2"

.PHONY: docker-${NGIC_NAME}-ngic-build
docker-${NGIC_NAME}-ngic-build:
	@docker build --target cp \
				-t ${ORG}/${NGIC_NAME}-ngic-cp \
				-f examples/${NGIC_NAME}/ngic-rtc/Dockerfile \
				--build-arg EXTRA_CFLAGS=${EXTRA_CFLAGS_CP} \
				. ; \
	docker build --target dp \
				-t ${ORG}/${NGIC_NAME}-ngic-dp \
				-f examples/${NGIC_NAME}/ngic-rtc/Dockerfile \
				--build-arg EXTRA_CFLAGS=${EXTRA_CFLAGS_DP} \
				. ; \
	if [ "x${TAG}" != "x" ] ; then \
		docker tag \
			${ORG}/${NGIC_NAME}-ngic-cp \
			${ORG}/${NGIC_NAME}-ngic-cp:${TAG} ; \
		docker tag \
			${ORG}/${NGIC_NAME}-ngic-dp \
			${ORG}/${NGIC_NAME}-ngic-dp:${TAG} ; \
	fi ; \

.PHONY: docker-${NGIC_NAME}-ngic-save
docker-${NGIC_NAME}-ngic-save: docker-${NGIC_NAME}-ngic-build
	@for target in cp dp; do \
		echo "Saving ${ORG}/${NGIC_NAME}-ngic-$$target"; \
		mkdir -p ${NSM_PATH}/build/images/ ; \
		docker save -o ${NSM_PATH}/build/images/${NGIC_NAME}-ngic-$$target.tar ${ORG}/${NGIC_NAME}-ngic-$$target ; \
	done

.PHONY: $(PREFIX)-$(NGIC_NAME)-ngic-load-images
$(PREFIX)-$(NGIC_NAME)-ngic-load-images:
	@for target in cp dp; do \
		make $(CLUSTER_RULES_PREFIX)-$(NGIC_NAME)-ngic-$$target-load-images ; \
	done
