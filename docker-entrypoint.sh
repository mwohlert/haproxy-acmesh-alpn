#!/usr/bin/env bash

set -euo pipefail

REFRESH_SCRIPT_PATH="/etc/periodic/daily/001.refresh-certs"
readonly REFRESH_SCRIPT_PATH

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
if [ ! -f "$REFRESH_SCRIPT_PATH" ] && [ "$TEST" == "false" ]; then
    cat << EOF > "$REFRESH_SCRIPT_PATH"
#!/bin/bash
acme.sh --cron ${ACMERENEWOPTS[@]} ${ACMEOPTS[@]} --reloadcmd "supervisorctl restart haproxy"
EOF
    chmod 755 "$REFRESH_SCRIPT_PATH"
fi

# Set default CA
acme.sh  --set-default-ca  --server "$SERVER"

#Make sure we are registered 
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

/usr/bin/supervisord -c /etc/supervisor.d/supervisord.ini