#!/usr/bin/env bash

set -euo pipefail

# Aquire initial certificates
if [ ! -d "$HAPROXYCERTSHOME" ]; then
    ACMEOPTS=("--alpn")
    if [ "$TEST"  == "true" ]; then
        ACMEOPTS+=("test")
    fi

    mkdir -p "$HAPROXYCERTSHOME"
    for i in ${DOMAINS//,/ }
    do
        echo "Getting certificate for $i"
        acme.sh --issue "${ACMEOPTS[@]}" -d "$i"
        CERTDIR="$ACMEHOME/$i"
        cat "$CERTDIR"/fullchain.cer \
            "$CERTDIR/$i".key > "$HAPROXYCERTSHOME/$i".pem
    done

    if ! crontab -l | grep -q 'acme.sh' && ! "$TEST"  == "true"
    then
        echo "0 0 12 1 1/2 ? * acme.sh --renew --tlsport 10443" "${ACMEOPTS[@]}" "--reloadcmd \"supervisorctl restart haproxy"\" | crontab -
    fi
fi


/usr/bin/supervisord