FROM golang:alpine as build
RUN apk --no-cache add git

RUN mkdir /root/networkservicemesh
ADD ["go.mod","/root/networkservicemesh"]
WORKDIR /root/networkservicemesh/
RUN go mod download

ADD [".","/root/networkservicemesh"]
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags '-extldflags "-static"' -o /go/bin/nse ./examples/vl3_basic/vl3-nse/cmd/...

FROM envoyproxy/envoy-alpine:v1.10.0

# install requisite packages
RUN apk --no-cache add \
    bind-tools \
    bash \
    iptables \
    ip6tables \
    iproute2 \
    python \
    py-pip \
    tini \
    && pip install --upgrade \
    pip \
    supervisor

# copy the config files for envoy, and the startup files for supervisord
COPY ./examples/envoy_interceptor/envoy-nse/etc/ /etc/
COPY ./examples/envoy_interceptor/envoy-nse/usr/ /usr/

COPY --from=build /go/bin/nse /usr/bin/nse

ENTRYPOINT [ "/sbin/tini", "--" ]
CMD ["/usr/bin/nse"]