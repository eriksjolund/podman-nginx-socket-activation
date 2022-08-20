FROM docker.io/library/ubuntu
RUN apt-get update && apt-get install -y build-essential less wget
RUN wget https://nginx.org/download/nginx-1.23.1.tar.gz && tar xfz nginx-1.23.1.tar.gz
RUN cd nginx-1.23.1 && ./configure --prefix=/usr  --without-http_gzip_module --without-http_rewrite_module && make -j 4 && make install
RUN sed  -i "s/listen\s\+80;/listen 11080;/g" /usr/conf/nginx.conf
STOPSIGNAL SIGQUIT
CMD ["nginx", "-g", "daemon off;"]
