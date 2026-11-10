#!/usr/bin/env bash
#
# sign-zone.sh — generate DNSSEC keys (KSK + ZSK) for a zone and sign it.
#
# DNSSEC adds cryptographic signatures to DNS records so a resolver can detect
# tampering (cache poisoning, spoofing). Two keys are used:
#   KSK (Key Signing Key)  — signs the DNSKEY set, anchors the chain of trust.
#   ZSK (Zone Signing Key) — signs the individual records of the zone.
#
# Usage:   sudo ./sign-zone.sh <zone> <zonefile>
# Example: sudo ./sign-zone.sh ssi.edu /etc/bind/db.ssi.edu
#
set -euo pipefail

ZONE="${1:?usage: sign-zone.sh <zone> <zonefile>}"
ZONEFILE="${2:?usage: sign-zone.sh <zone> <zonefile>}"
KEYDIR="/etc/bind/keys/${ZONE}"

mkdir -p "$KEYDIR"
cd "$KEYDIR"

echo "[*] Generating KSK (RSASHA256, 2048-bit) ..."
dnssec-keygen -a RSASHA256 -b 2048 -f KSK -n ZONE "$ZONE"

echo "[*] Generating ZSK (RSASHA256, 2048-bit) ..."
dnssec-keygen -a RSASHA256 -b 2048        -n ZONE "$ZONE"

echo "[*] Signing the zone ..."
# -S  smart-sign: finds the keys above automatically
# -o  origin
dnssec-signzone -A -3 "$(head -c 8 /dev/urandom | xxd -p)" \
    -N INCREMENT -o "$ZONE" -S "$ZONEFILE"

echo
echo "[+] Signed zone written:  ${ZONEFILE}.signed"
echo "[+] Point named.conf.local 'file' at the .signed file and reload BIND."
echo
echo "[i] DS record to hand to the parent zone (chain of trust):"
dnssec-dsfromkey K"${ZONE}".*KSK*.key 2>/dev/null \
  || dnssec-dsfromkey "$(ls K${ZONE}.*.key | head -1)"
