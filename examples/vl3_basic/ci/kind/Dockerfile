FROM golang:alpine as build
RUN apk --no-cache add git make


# Note: Latest version of kubectl may be found at:
# https://github.com/kubernetes/kubernetes/releases
ENV KUBE_LATEST_VERSION="v1.13.12"
# Note: Latest version of helm may be found at:
# https://github.com/kubernetes/helm/releases
ENV HELM_VERSION="v2.16.0"

RUN apk add --no-cache ca-certificates bash git openssh curl \
    && wget -q https://storage.googleapis.com/kubernetes-release/release/${KUBE_LATEST_VERSION}/bin/linux/amd64/kubectl -O /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl \
    && wget -q https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz -O - | tar -xzO linux-amd64/helm > /usr/local/bin/helm \
    && chmod +x /usr/local/bin/helm

RUN apk add --no-cache docker

# install kind
RUN curl -Lo ./kind https://github.com/kubernetes-sigs/kind/releases/download/v0.7.0/kind-linux-amd64 && \
    chmod +x ./kind && \
    mv ./kind /usr/bin/kind

# install requisite packages
RUN apk --no-cache add \
    bind-tools \
    iptables \
    ip6tables \
    iproute2 \
    python \
    py-pip \
    tini \
    && pip install --upgrade \
    pip \
    supervisor

#ENTRYPOINT [ "/sbin/tini", "--" ]
CMD ["bash"]
