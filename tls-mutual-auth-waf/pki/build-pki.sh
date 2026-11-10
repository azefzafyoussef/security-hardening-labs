#!/usr/bin/env bash
#
# build-pki.sh — create a small CA, a server certificate, and a client certificate
# for mutual-TLS testing. Everything is self-signed under a CA we control, so the
# client certificate is trusted by the same CA the server presents.
#
# Usage:   ./build-pki.sh [SERVER_CN]
# Example: ./build-pki.sh 192.168.56.10
#
set -euo pipefail

SERVER_CN="${1:-localhost}"
OUT="pki-out"
DAYS_CA=3650
DAYS_LEAF=365
SUBJ_BASE="/C=FR/ST=Lab/L=Lab/O=Hardening-Lab"

mkdir -p "$OUT"
cd "$OUT"

echo "[*] 1/4  Certificate Authority"
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out ca.key
openssl req -x509 -new -nodes -key ca.key -sha256 -days "$DAYS_CA" \
    -subj "${SUBJ_BASE}/CN=Hardening-Lab Root CA" -out ca.crt

echo "[*] 2/4  Server key + CSR (CN=${SERVER_CN})"
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out server.key
openssl req -new -key server.key \
    -subj "${SUBJ_BASE}/CN=${SERVER_CN}" -out server.csr

# SAN extension so modern browsers accept the cert
cat > server.ext <<EOF
subjectAltName = DNS:${SERVER_CN}, IP:${SERVER_CN}
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
EOF

echo "[*] 3/4  Sign server certificate with the CA"
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
    -sha256 -days "$DAYS_LEAF" -extfile server.ext -out server.crt

echo "[*] 4/4  Client key + certificate (for mutual TLS)"
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out client.key
openssl req -new -key client.key \
    -subj "${SUBJ_BASE}/CN=lab-client" -out client.csr
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
    -sha256 -days "$DAYS_LEAF" -out client.crt
# PKCS#12 bundle to import into a browser's certificate store
openssl pkcs12 -export -inkey client.key -in client.crt -certfile ca.crt \
    -passout pass: -out client.p12

echo
echo "[+] Done. Files in $(pwd):"
echo "    ca.crt      -> SSLCACertificateFile (and browser trust store)"
echo "    server.crt  -> SSLCertificateFile"
echo "    server.key  -> SSLCertificateKeyFile"
echo "    client.p12  -> import into the browser to pass mutual-TLS"
echo
echo "[i] Verify the chain:   openssl verify -CAfile ca.crt server.crt"
