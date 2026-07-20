#!/usr/bin/env bash
# Assemble HAProxy PEM files from acme.sh certs and reload HAProxy when running.
set -euo pipefail

: "${DOMAINS:?DOMAINS is required}"
: "${ACMEHOME:?ACMEHOME is required}"
: "${HAPROXYCERTSHOME:?HAPROXYCERTSHOME is required}"

resolve_certdir() {
    local domain="$1"
    if [[ -f "$ACMEHOME/${domain}_ecc/fullchain.cer" ]]; then
        echo "$ACMEHOME/${domain}_ecc"
    elif [[ -f "$ACMEHOME/${domain}/fullchain.cer" ]]; then
        echo "$ACMEHOME/${domain}"
    else
        echo "$ACMEHOME/${domain}_ecc"
    fi
}

mkdir -p "$HAPROXYCERTSHOME"

for domain in ${DOMAINS//,/ }; do
    certdir="$(resolve_certdir "$domain")"
    cat "$certdir/fullchain.cer" "$certdir/$domain.key" > "$HAPROXYCERTSHOME/$domain.pem"
    echo "Deployed certificate PEM for $domain from $certdir"
done

# On first boot the entrypoint deploys PEMs before supervisord starts.
if supervisorctl status haproxy >/dev/null 2>&1; then
    supervisorctl restart haproxy
fi
