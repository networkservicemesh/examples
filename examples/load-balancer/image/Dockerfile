ARG VPP_AGENT

FROM golang:alpine as build
RUN apk --no-cache add git
ENV PACKAGEPATH=github.com/networkservicemesh/networkservicemesh/
ENV GO111MODULE=on

RUN mkdir /root/networkservicemesh
ADD ["go.mod","/root/networkservicemesh"]
WORKDIR /root/networkservicemesh/
RUN go mod download

ADD [".","/root/networkservicemesh"]
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags '-extldflags "-static"' -o /go/bin/bridge-domain ./examples/load-balancer/image/cmd/

FROM ${VPP_AGENT} as runtime
COPY --from=build /go/bin/bridge-domain /bin/bridge-domain
COPY ./examples/load-balancer/image/bin/ /bin/
COPY ./examples/load-balancer/image/etc/ /etc/
COPY ./examples/load-balancer/image/etc/supervisord/supervisord.conf /opt/vpp-agent/dev/supervisor.conf
RUN rm /opt/vpp-agent/dev/etcd.conf; \
    echo 'Endpoint: "localhost:9113"' > /opt/vpp-agent/dev/grpc.conf ; \
    echo "disabled: true" > /opt/vpp-agent/dev/telemetry.conf; \
    echo "disabled: true" > /opt/vpp-agent/dev/linux-plugin.conf
