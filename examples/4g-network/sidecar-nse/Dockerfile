FROM golang:1.15.1-alpine3.12 as build

ENV PACKAGEPATH=github.com/networkservicemesh/networkservicemesh/
ENV GO111MODULE=on

WORKDIR /root/networkservicemesh/

RUN apk --no-cache add git=2.26.2-r0
COPY go.mod .
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags '-extldflags "-static"' -o /go/bin/sidecar-nse ./examples/4g-network/sidecar-nse/cmd/...

FROM alpine:3.12 as runtime
COPY --from=build /go/bin/sidecar-nse /bin/sidecar-nse
ENTRYPOINT ["/bin/sidecar-nse"]
