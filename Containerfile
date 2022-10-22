FROM docker.io/library/nginx
ARG port
RUN sed  -i "s/listen\s\+80;/listen ${port};/g" /etc/nginx/conf.d/default.conf
