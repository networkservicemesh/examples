FROM golang:alpine as build
RUN apk --no-cache add git
ENV PACKAGEPATH=github.com/networkservicemesh/networkservicemesh/
ENV GO111MODULE=on


RUN mkdir /root/networkservicemesh
ADD ["go.mod","/root/networkservicemesh"]
WORKDIR /root/networkservicemesh
RUN go mod download

ADD [".","/root/networkservicemesh"]
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags '-extldflags "-static"' -o /go/bin/nsc-sidecar ./examples/topology/sidecar-nsc/cmd/...

FROM alpine as runtime
COPY --from=build /go/bin/nsc-sidecar /bin/nsc-sidecar
ENTRYPOINT ["/bin/nsc-sidecar"]
