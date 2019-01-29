FROM nginx
COPY examples/proxy/nginx/conf/default.conf /etc/nginx/conf.d/
COPY examples/proxy/nginx/html /usr/share/nginx/html
RUN dd if=/dev/urandom of=/usr/share/nginx/html/huge.bin bs=1M count=64
