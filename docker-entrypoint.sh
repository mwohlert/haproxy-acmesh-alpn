#!/usr/bin/env bash

set -euo pipefail
ACMEOPTS=()
if [ "$TEST"  == "true" ]; then
    ACMEOPTS+=("--staging")
    ACMEOPTS+=("--debug")
fi

ACMERENEWOPTS=()
if [ "$MODE" == "alpn" ]; then
    ACMERENEWOPTS+=("--alpn")
    ACMERENEWOPTS+=("--tlsport 10443")
elif [ "$MODE" == "http" ]; then
    ACMERENEWOPTS+=("--httport 10808")
fi

# Setup haproxy dir 
if [ ! -d "$HAPROXYCERTSHOME" ]; then
    mkdir -p "$HAPROXYCERTSHOME"
fi

# Setup crontab
if ! crontab -l | grep -q 'acme.sh' && "$TEST" == "false"
then
    echo "0 0 0 1/30 * ? * acme.sh --renew" "${ACMERENEWOPTS[@]}" "${ACMEOPTS[@]}" "--reloadcmd \"supervisorctl restart haproxy"\" | crontab -
fi

#Make sure we are registered with zerossl
acme.sh --register-account -m "$EMAIL"

# Check or acquire certificates
for i in ${DOMAINS//,/ }
do
    echo "Check if certificate for $i exists and is valid"
    CERTDIR="$ACMEHOME/$i"
    if [[ -f "$CERTDIR"/fullchain.cer && -f "$CERTDIR/$i".key ]]; then
        #Check if existing cert expires within the next 30 days
        if openssl x509 -checkend 2592000 -noout -in "$CERTDIR"/fullchain.cer; then
            echo "Certificate is still valid at least 30 days"
        else
            echo "Certificate is not valid/will expire soon. Getting certificate for $i"
            if [ "$MODE" == "alpn" ]; then
                acme.sh --issue --alpn "${ACMEOPTS[@]}" -d "$i"
            else
                acme.sh --issue --standalone "${ACMEOPTS[@]}" -d "$i"
            fi
        fi
    else
        echo "Certificate does not exist. Getting certificate for $i"
        if [ "$MODE" == "alpn" ]; then
            acme.sh --issue --alpn "${ACMEOPTS[@]}" -d "$i"
        else
            acme.sh --issue --standalone "${ACMEOPTS[@]}" -d "$i"
        fi
    fi

    cat "$CERTDIR"/fullchain.cer \
        "$CERTDIR/$i".key > "$HAPROXYCERTSHOME/$i".pem
done

/usr/bin/supervisord