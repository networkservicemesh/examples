# SPDX-License-Identifier: Apache-2.0
# Copyright 2019-present Open Networking Foundation
# Copyright (c) 2019 Intel Corporation
# Copyright 2020 VMware, Inc.

# Multi-stage Dockerfile
ARG BASE_OS=ubuntu:18.04

## Stage build: kitchen sink stage for compiling dependencies and CP/DP bins
FROM $BASE_OS as build
ARG CPUS=2
ARG RTE_MACHINE=hsw
ARG EXTRA_CFLAGS='-DUSE_AF_PACKET -O2'

WORKDIR /
SHELL ["/bin/bash", "-c"]

RUN apt-get update && apt-get install -y git
RUN git clone --depth 1 --single-branch https://github.com/omec-project/ngic-rtc.git
WORKDIR /ngic-rtc
RUN ./install_builddeps.sh
RUN source ./install_builddeps.sh && make -j $CPUS clean && make -j $CPUS RTE_MACHINE=$RTE_MACHINE EXTRA_CFLAGS="$EXTRA_CFLAGS"

## Stage runtime: no utils
FROM $BASE_OS as runtime
SHELL ["/bin/bash", "-c"]
COPY --from=build /ngic-rtc/install_rundeps.sh .
RUN source ./install_rundeps.sh && install_run_utils && apt install -y vim && cleanup_image

## Stage cp: creates the runtime image of control plane
FROM runtime as cp
RUN source ./install_rundeps.sh && install_run_cp_deps && cleanup_image
COPY --from=build /ngic-rtc/cp/build/ngic_controlplane /bin/ngic_controlplane
COPY ./examples/4g-spgw/ngic-rtc/config/cp /opt/cp/config


## Stage dp: creates the runtime image of data plane
FROM runtime as dp
RUN source ./install_rundeps.sh && install_run_dp_deps && cleanup_image
COPY --from=build /ngic-rtc/dp/build/ngic_dataplane /bin/ngic_dataplane
COPY ./examples/4g-spgw/ngic-rtc/config/dp /opt/dp/config

