#!/usr/bin/env bash

set -euo pipefail

readonly REFRESH_SCRIPT_PATH="/etc/periodic/daily/001.refresh-certs"
readonly DEPLOY_SCRIPT_PATH="/deploy-haproxy-certs.sh"
readonly RENEWAL_WINDOW_SECONDS=2592000

ACME_OPTIONS=(--use-wget)
if [ "$TEST" == "true" ]; then
    ACME_OPTIONS+=(--staging --debug)
fi

case "$MODE" in
    alpn)
        ISSUE_OPTIONS=(--alpn)
        RENEW_OPTIONS=(--alpn --tlsport 10443)
        RENEW_PORT_KEY="Le_TLSPort"
        RENEW_PORT=10443
        ;;
    http)
        ISSUE_OPTIONS=(--standalone)
        RENEW_OPTIONS=(--httpport 10808)
        RENEW_PORT_KEY="Le_HTTPPort"
        RENEW_PORT=10808
        ;;
    *)
        echo "Unsupported MODE: $MODE" >&2
        exit 1
        ;;
esac

cert_dir() {
    local domain="$1"

    if [[ -f "$ACMEHOME/${domain}_ecc/fullchain.cer" ]]; then
        echo "$ACMEHOME/${domain}_ecc"
    elif [[ -f "$ACMEHOME/${domain}/fullchain.cer" ]]; then
        echo "$ACMEHOME/${domain}"
    else
        echo "$ACMEHOME/${domain}_ecc"
    fi
}

set_renewal_port() {
    local domain="$1"
    local config
    config="$(cert_dir "$domain")/$domain.conf"

    if [[ ! -f "$config" ]]; then
        return
    fi

    if grep -q "^${RENEW_PORT_KEY}=" "$config"; then
        sed -i "s/^${RENEW_PORT_KEY}=.*/${RENEW_PORT_KEY}='${RENEW_PORT}'/" "$config"
    else
        echo "${RENEW_PORT_KEY}='${RENEW_PORT}'" >> "$config"
    fi

    echo "Set ${RENEW_PORT_KEY}=${RENEW_PORT} for renewals in $config"
}

issue_certificate() {
    acme.sh --issue "${ISSUE_OPTIONS[@]}" "${ACME_OPTIONS[@]}" -d "$1"
}

: "${DOMAINS:?DOMAINS is required}"
: "${EMAIL:?EMAIL is required}"

IFS=',' read -r -a domains <<< "$DOMAINS"
mkdir -p "$HAPROXYCERTSHOME"

mkdir -p "$(dirname "$REFRESH_SCRIPT_PATH")"
cat > "$REFRESH_SCRIPT_PATH" << EOF
#!/usr/bin/env bash
set -euo pipefail
exec >> /proc/1/fd/1 2>> /proc/1/fd/2
export DOMAINS='${DOMAINS}'
export ACMEHOME='${ACMEHOME}'
export HAPROXYCERTSHOME='${HAPROXYCERTSHOME}'
acme.sh --cron ${RENEW_OPTIONS[*]} ${ACME_OPTIONS[*]} --reloadcmd "${DEPLOY_SCRIPT_PATH}"
EOF
chmod 755 "$REFRESH_SCRIPT_PATH"

acme.sh --set-default-ca --server "$SERVER" "${ACME_OPTIONS[@]}" || true

has_certificates=false
for domain in "${domains[@]}"; do
    if [[ -f "$ACMEHOME/${domain}_ecc/fullchain.cer" || -f "$ACMEHOME/${domain}/fullchain.cer" ]]; then
        has_certificates=true
        break
    fi
done
if [ "$has_certificates" = false ]; then
    acme.sh --register-account -m "$EMAIL" "${ACME_OPTIONS[@]}" || true
fi

for domain in "${domains[@]}"; do
    directory="$(cert_dir "$domain")"
    if [[ ! -f "$directory/fullchain.cer" || ! -f "$directory/$domain.key" ]] ||
        ! openssl x509 -checkend "$RENEWAL_WINDOW_SECONDS" -noout -in "$directory/fullchain.cer"; then
        issue_certificate "$domain"
    fi

    set_renewal_port "$domain"
done

"$DEPLOY_SCRIPT_PATH"

exec /usr/bin/supervisord -n -c /etc/supervisord.conf
