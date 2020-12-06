#!/bin/sh

echo -ne "HTTP/1.0 200 OK\r\n\r\n"
ffmpeg \
    -re \
    -fflags +genpts \
    -stream_loop -1 \
    -i /streamer/assets/video.mp4 \
    -c copy \
    -f mpegts -
