#!/usr/bin/env bash

set -euo pipefail
ACMEOPTS=("--alpn")
if [ "$TEST"  == "true" ]; then
    ACMEOPTS+=("test")
fi

# Setup haproxy dir 
if [ ! -d "$HAPROXYCERTSHOME" ]; then
    mkdir -p "$HAPROXYCERTSHOME"
fi

# Setup crontab
if ! crontab -l | grep -q 'acme.sh' && ! "$TEST"  == "true"
then
    echo "0 0 0 1/30 * ? * acme.sh --renew --tlsport 10443" "${ACMEOPTS[@]}" "--reloadcmd \"supervisorctl restart haproxy"\" | crontab -
fi

# Check or acquire certificates
for i in ${DOMAINS//,/ }
do
    echo "Check if certificate for $i exists and is valid"
    CERTDIR="$ACMEHOME/$i"
    if [[ -f "$CERTDIR"/fullchain.cer && -f "$CERTDIR/$i".key ]]; then
        #Check if existing cert expires within the next 30 days
        if openssl x509 -checkend 2592000 -noout -in "$CERTDIR"/fullchain.cer
            echo "Certificate is still valid at least 30 days"
            continue
        fi
    fi
    echo "Certificate is not valid or does not exist. Getting certificate for $i"
    acme.sh --issue "${ACMEOPTS[@]}" -d "$i"
    cat "$CERTDIR"/fullchain.cer \
        "$CERTDIR/$i".key > "$HAPROXYCERTSHOME/$i".pem
done

/usr/bin/supervisord