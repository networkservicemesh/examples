FROM alpine

RUN apk add --no-cache quagga

COPY examples/topology/qrtr/entrypoint.sh /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
