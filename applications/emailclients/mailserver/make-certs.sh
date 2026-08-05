#!/usr/bin/env bash
# Mint the benchmark mail server's TLS material.
#
# A throwaway CA signs a leaf for mail.parrot.test.  Nothing is committed to the
# repository, so there is no private key in version control.
#
# Idempotent: does nothing if the fullchain already exists, unless
# PARROT_FORCE_CERTS=1.  That lets the prebuilt image bake certificates once and
# still lets a from-scratch run mint its own.
set -euo pipefail

# readlink -f, so this still resolves when the script is reached through a
# symlink: BASH_SOURCE is then the link's path and ../account.env would not
# exist next to it.  The prebuilt image relies on this - it puts start.sh on
# PATH as /usr/local/bin/parrot-mailserver-start.
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=../account.env
source "${HERE}/../account.env"

MAIL_FQDN="${PARROT_MAIL_HOST}"
CERT_DIR="${PARROT_CERT_DIR:-/etc/dovecot/private}"

log() { printf '[make-certs] %s\n' "$*"; }

if [[ -f "${CERT_DIR}/${MAIL_FQDN}.fullchain.crt" && "${PARROT_FORCE_CERTS:-0}" != "1" ]]; then
    log "certificates already present in ${CERT_DIR}, keeping them"
    exit 0
fi

mkdir -p "$CERT_DIR"

openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
    -keyout "${CERT_DIR}/parrot-test-ca.key" \
    -out "${CERT_DIR}/parrot-test-ca.crt" \
    -subj "/O=Parrot Benchmark/CN=Parrot Benchmark Test CA" \
    -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
    -addext "keyUsage=critical,keyCertSign,cRLSign" 2>/dev/null

openssl req -new -newkey rsa:2048 -nodes \
    -keyout "${CERT_DIR}/${MAIL_FQDN}.key" \
    -out "${CERT_DIR}/${MAIL_FQDN}.csr" \
    -subj "/O=Parrot Benchmark/CN=${MAIL_FQDN}" 2>/dev/null

# SANs cover every name a client might use: the FQDN, the Docker service name,
# and localhost for the in-container smoke test.
cat > "${CERT_DIR}/leaf.ext" <<EXT
basicConstraints=CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:${MAIL_FQDN},DNS:mail-container,DNS:localhost,IP:127.0.0.1
EXT

openssl x509 -req -in "${CERT_DIR}/${MAIL_FQDN}.csr" \
    -CA "${CERT_DIR}/parrot-test-ca.crt" -CAkey "${CERT_DIR}/parrot-test-ca.key" \
    -set_serial 4242 -days 3650 -sha256 \
    -extfile "${CERT_DIR}/leaf.ext" \
    -out "${CERT_DIR}/${MAIL_FQDN}.crt" 2>/dev/null

# Serve leaf + CA as one file.  The client container shares no filesystem with
# this one and recovers the CA from the TLS handshake itself, which only works
# if the CA is actually sent as part of the chain.
cat "${CERT_DIR}/${MAIL_FQDN}.crt" "${CERT_DIR}/parrot-test-ca.crt" \
    > "${CERT_DIR}/${MAIL_FQDN}.fullchain.crt"

chmod 600 "${CERT_DIR}"/*.key
chmod 644 "${CERT_DIR}"/*.crt

log "issued a CA and a leaf for ${MAIL_FQDN}, valid 10 years"
