FROM ubuntu:20.04
COPY ./examples/4g-spgw/dp-init/setup_af_packet.sh /opt/dp/setup_af_packet.sh
RUN apt update && apt -y dist-upgrade && apt install -y iproute2 && rm -rf /var/lib/apt/lists/*
ENTRYPOINT ["/opt/dp/setup_af_packet.sh"]
