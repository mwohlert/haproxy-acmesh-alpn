
# haproxy-acmesh-alpn

This container runs HAProxy with certificates managed by acme.sh. It supports
ZeroSSL by default and both `tls-alpn-01` and `http-01` challenges.

## Usage

### Pull from Docker Hub:

```
docker pull mwohlert/haproxy-acmesh-alpn
```

### Build from Dockerfile:

```
docker build -t haproxy-acmesh-alpn:latest .
```

## Environment variables

| Variable Key | Default Value | Description|
|--------------|---------------|------------|
| DOMAINS      |               | Comma separated list of domains/subdomains to generate certs for |
| EMAIL        |               | Email to register with the CA |
| TEST         | false         | Run verbose and in debug/staging mode. Possible values: `false`, `true` |
| MODE         | alpn          | Challenge mode. Possible values: `alpn`, `http` |
| SERVER       | zerossl       | CA name per [acme.sh servers](https://github.com/acmesh-official/acme.sh/wiki/Server) |
| ACMEHOME     | /root/.acme.sh | acme.sh working directory (persist via volume) |
| HAPROXYCERTSHOME | /etc/haproxy/certs | Directory where HAProxy PEM files are assembled |

### Run container:

Example of run command (replace domains, email, and volume paths with yours).
Setting `TEST=true` uses the staging CA and enables debug output, which is useful for testing.

```
docker run --name lb -d \
    -e DOMAINS=my.domain,my.other.domain \
    -e EMAIL=you@example.com \
    -e TEST=false \
    -v /srv/letsencrypt:/root/.acme.sh \
    -v /srv/haproxycfg/haproxy.cfg:/etc/haproxy/haproxy.cfg \
    --network my_network \
    -p 80:80 -p 443:443 \
    mwohlert/haproxy-acmesh-alpn:latest
```

### Run with docker-compose:

Example compose file (haproxy plus a linked nginx backend for testing):

```
version: '3'
services:
    haproxy:
        container_name: lb
        environment:
            - DOMAINS=my.domain,my.other.domain
            - EMAIL=you@example.com
            - TEST=false
        volumes:
            - '$PWD/data/letsencrypt:/root/.acme.sh'
            - '$PWD/data/haproxy.cfg:/etc/haproxy/haproxy.cfg'
        networks:
            - lbnet
        ports:
            - '80:80'
            - '443:443'
        image: 'mwohlert/haproxy-acmesh-alpn:latest'
    nginx:
        container_name: www
        networks:
            - lbnet
        image: nginx

networks:
  lbnet:

docker-compose up -d
```

### Renewal cron job

A daily Alpine periodic job runs `acme.sh --cron` with GNU wget. On successful
renewal it rebuilds HAProxy PEM files under `/etc/haproxy/certs` and restarts
only the HAProxy process via supervisord. A container restart is not required.

For `MODE=alpn`, certificates are issued on port 443 before HAProxy starts.
Renewals use port 10443; HAProxy must route `acme-tls/1` traffic received on
443 to that port.

For `MODE=http`, certificates are issued on port 80 before HAProxy starts.
Renewals use port 10808; HAProxy must route
`/.well-known/acme-challenge/` requests on port 80 to that port. See
[`conf/haproxy.http01.cfg`](conf/haproxy.http01.cfg).


## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.
