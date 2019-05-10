FROM golang:alpine as build
RUN apk --no-cache add git

RUN mkdir /root/networkservicemesh
ADD ["go.mod","/root/networkservicemesh"]
WORKDIR /root/networkservicemesh/
RUN go mod download

ADD [".","/root/networkservicemesh"]
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags '-extldflags "-static"' -o /go/bin/nse ./examples/envoy_echo/envoy-nse/cmd/nse.go

FROM envoyproxy/envoy-alpine:latest

# install requisite packages
RUN apk --no-cache add \
    bind-tools \
    python \
    py-pip \
    tini \
    && pip install --upgrade \
    pip \
    supervisor

# copy the config files for envoy, and the startup files for supervisord
COPY ./examples/envoy_echo/envoy-nse/etc/ /etc/
COPY ./examples/envoy_echo/envoy-nse/usr/ /usr/

COPY --from=build /go/bin/nse /usr/bin/nse

ENTRYPOINT [ "/sbin/tini", "--" ]
CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]