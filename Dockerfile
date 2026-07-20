FROM alpine:3.23

ENV DOMAINS=""
ENV ACMEHOME="/root/.acme.sh"
ENV HAPROXYCERTSHOME="/etc/haproxy/certs"
ENV TEST="false"
ENV EMAIL=""
ENV MODE="alpn"
ENV SERVER="zerossl"

RUN apk add --no-cache bash acme.sh haproxy supervisor socat openssl curl wget \
    && rm -rf /var/cache/apk/*

COPY conf/haproxy.cfg /etc/haproxy/haproxy.cfg
COPY conf/supervisord.ini /etc/supervisor.d/supervisord.ini
COPY docker-entrypoint.sh /
COPY deploy-haproxy-certs.sh /deploy-haproxy-certs.sh
RUN chmod 755 /docker-entrypoint.sh /deploy-haproxy-certs.sh

VOLUME /root/.acme.sh

ENTRYPOINT [ "/docker-entrypoint.sh" ]