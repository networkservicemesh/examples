FROM jrottenberg/ffmpeg:4.2-alpine as runtime
RUN apk --no-cache add nmap-ncat
COPY ./examples/streamer/assets/ /streamer/assets/
COPY ./examples/streamer/streamer/scripts/* /bin/
ENTRYPOINT ["/bin/entry.sh"]
