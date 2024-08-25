
# haproxy-acmesh-alpn

This container provides an HAProxy instance with Let's Encrypt certificates generated
at startup using acme.sh with the tls-alpn-01 method. This is useful if you can't use port 80 for verification.

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
| DOMAINS      |               | Comma seperated lists of domains/subdomains to generate certs for |
| TEST         | false         | Run verbose and in debug mode for testing purposes. <br/> Possible Values: <br/> - "false" <br/> - "true" |
| EMAIL        |               | Email to register with the CA with \
| MODE         | alpn          | Wether to use ALPN or HTTP. <br/> Possible Values: <br/> - "alpn" <br/> - "http" |
| SERVER       | zerossl       | Name for CA according to: https://github.com/acmesh-official/acme.sh/wiki/Server |

### Run container:

Example of run command (replace DOMAIN, TEST and volume paths with yours)
Setting TEST to true will result in staging letsencrypt certificates, which is useful for testing.

```
docker run --name lb -d \
    -e DOMAINS=my.domain,my.other.domain \
    -e TEST=false \
    -v /srv/letsencrypt:/root/.acme.sh \
    -v /srv/haproxycfg/haproxy.cfg:/etc/haproxy/haproxy.cfg \
    --network my_network \
    -p 80:80 -p 443:443 \
    mwohlert/haproxy-acmesh-alpn:latest
```

### Run with docker-compose:

Use the docker-compose.yml file in `run` directory (it creates 2 containers, the haproxy one and a nginx container linked in haproxy configuration for test purposes)

```
docker-compose.yml file contenct:

version: '3'
services:
    haproxy:
        container_name: lb
        environment:
            - DOMAINS=my.domain,my.other.domain
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

Every 2 months a cron job check for expiring certificates with certbot agent and reload haproxy if a certificate is renewed. No containers restart needed.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.
