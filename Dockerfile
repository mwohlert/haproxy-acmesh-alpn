FROM alpine:3.20

ENV DOMAINS ""
ENV ACMEHOME "/root/.acme.sh"
ENV HAPROXYCERTSHOME "/etc/haproxy/certs"
ENV TEST "false"
ENV EMAIL ""
ENV MODE="alpn"
ENV SERVER="zerossl"

RUN apk add --no-cache bash acme.sh haproxy supervisor socat \
    && rm -rf /var/cache/apk/*

COPY conf/haproxy.cfg /etc/haproxy/haproxy.cfg
COPY conf/supervisord.ini /etc/supervisor.d/supervisord.ini
COPY docker-entrypoint.sh /

VOLUME /root/.acme.sh

ENTRYPOINT [ "/docker-entrypoint.sh" ]