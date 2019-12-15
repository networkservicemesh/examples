FROM ubuntu:20.04 as build
RUN apt update && apt -y dist-upgrade
RUN apt install -y build-essential git autoconf libmnl-dev libtool pkg-config
RUN git clone git://git.osmocom.org/libgtpnl
RUN cd libgtpnl/ && autoreconf -fi && ./configure --enable-static --disable-shared && make
RUN pwd && ls -laR /libgtpnl
RUN ldd /libgtpnl/tools/gtp-link

FROM ubuntu:20.04 as runtime
RUN apt update && \
    apt -y dist-upgrade && \
    apt install -y \
    libmnl0 iproute2 netcat-openbsd iputils-ping curl && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*
COPY --from=build /libgtpnl/tools/gtp-link /opt/gtp-link
COPY --from=build /libgtpnl/tools/gtp-tunnel /opt/gtp-tunnel