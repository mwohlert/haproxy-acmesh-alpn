#!/usr/bin/env bash

set -euo pipefail

# Aquire initial certificates
if [ -n "$HAPROXYCERTSHOME" ]; then
    ACMEOPTS=("--test" "--alpn")
    for i in ${DOMAINS//,/ }
    do
        ACMEOPTS+=( "-d" "$i" )
    done

    echo "${ACMEOPTS[@]}"
    acme.sh --issue "${ACMEOPTS[@]}"

    mkdir -p /etc/haproxy/certs
    for i in ${DOMAINS//,/ }
    do
        CERTDIR="$ACMEHOME/$i"
        cat "$CERTDIR"/fullchain.cer \
            "$CERTDIR/$i".key > "$HAPROXYCERTSHOME/$i".pem
    done

    if ! crontab -l | grep -q 'acme.sh'
    then
        echo "0 0 12 1 1/3 ? * acme.sh --renew --tlsport 10443" "${ACMEOPTS[@]}" "--reloadcmd \"supervisorctl restart haproxy"\" | crontab -
    fi
fi


/usr/bin/supervisord