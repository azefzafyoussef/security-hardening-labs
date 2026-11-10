# Signed & Encrypted DNS (BIND9 + DNSSEC + TSIG + DoT)

A hardened DNS infrastructure on BIND9: a primary/secondary pair with **TSIG-authenticated
zone transfers**, **DNSSEC** signing so resolvers can detect tampering, and
**DNS-over-TLS** so queries are encrypted on the wire.

Threats addressed: cache poisoning, DNS spoofing / domain hijacking, man-in-the-middle,
and theft of a zone by an unauthorised transfer.

## Topology

```
          TSIG-authenticated AXFR
 DNSMaster  ───────────────────────▶  DNSSlave
 10.71.105.136                        10.71.105.191
 (signs zones, serves .signed)        (pulls zones with the shared key)
      │
      │  DoT :853 (TLS)         ┌──────────┐
      └──────────────────────── │  Client  │  dig +tls / kdig +tls
                                └──────────┘
```

## 1. Primary & secondary, authenticated transfer (TSIG)

Zone files: [`zones/db.ssi.edu`](zones/db.ssi.edu) (forward) and
[`zones/db.reverse`](zones/db.reverse) (reverse `136.105.71.in-addr.arpa`).

Generate the shared key on the master and copy it to the slave over SSH:

```bash
tsig-keygen -a hmac-sha256 transfer-key | sudo tee /etc/bind/tsig.key
sudo scp /etc/bind/tsig.key root@10.71.105.191:/etc/bind/tsig.key
```

The master only allows transfers to holders of that key
([`config/named.conf.local.master`](config/named.conf.local.master)); the slave uses it
to pull ([`config/named.conf.local.slave`](config/named.conf.local.slave)). Test the
authenticated transfer:

```bash
dig @10.71.105.136 ssi.edu AXFR \
    -y hmac-sha256:transfer-key:<base64-secret>     # 26 records, XFR ok
```

Without the key, the transfer is refused — a zone can no longer be stolen by anyone who
can reach port 53.

## 2. DNSSEC signing (KSK / ZSK)

[`sign-zone.sh`](sign-zone.sh) generates the key pair and signs the zone:

```bash
sudo ./sign-zone.sh ssi.edu /etc/bind/db.ssi.edu
# -> /etc/bind/db.ssi.edu.signed   (+ DS record for the parent)
```

| Key | Role | Size | Rotation |
|-----|------|------|----------|
| **KSK** (Key Signing Key) | Signs the DNSKEY set; anchors the chain of trust | 2048-bit RSA | every 3–5 years |
| **ZSK** (Zone Signing Key) | Signs the zone's records | 2048-bit RSA | every 1–3 years |

Point `named.conf.local` at the `.signed` files, reload, and the client gets signed
answers (`RRSIG`, `DNSKEY`):

```bash
dig @10.71.105.136 ssi.edu DNSKEY      # 256 (ZSK) + 257 (KSK) keys returned
dig +dnssec @10.71.105.136 mail.ssi.edu
```

The **DS record** emitted by the script is handed to the parent zone to extend the chain
of trust upward:

```
ssi.edu. IN DS 5597 8 2 E326034F9ED4313B816AFACB8510EF2ACF7C9CBC14A835970575865D9257DB44
```

## 3. DNS-over-TLS (DoT)

BIND does not terminate TLS here, so nginx is used as a TLS front end: clients speak TLS
on `853`, nginx forwards plain DNS to BIND on `53`
([`dot/nginx-dot.conf`](dot/nginx-dot.conf)).

```bash
sudo openssl req -new -x509 -days 365 -nodes \
    -keyout /etc/nginx/ssl/dot.key -out /etc/nginx/ssl/dot.crt
sudo systemctl restart nginx bind9

# From the client — the query is now inside TLS:
dig +tls -p 853 @10.71.105.136 mail.ssi.edu
kdig +tls @10.71.105.136 mail.ssi.edu
# ;; TLS session (TLS1.2)-(ECDHE-SECP256R1)-(AES-256-GCM)
```

## Hardening summary

| Threat | Control |
|--------|---------|
| Cache poisoning / spoofed answers | DNSSEC signatures (KSK/ZSK, RRSIG) |
| Unauthorised zone transfer (data theft) | TSIG-authenticated AXFR, `allow-transfer { key ... }` |
| Eavesdropping on queries | DNS-over-TLS (port 853) |
| Tampered chain of trust | DS record published to the parent zone |

> All secrets in this repo (TSIG `secret`, keys) are **placeholders**. Generate your own
> with `tsig-keygen` / `dnssec-keygen` and never commit real key material.

## Skills demonstrated

BIND9 authoritative DNS, primary/secondary replication, TSIG, DNSSEC key management and
zone signing, the chain of trust (DS/DNSKEY/RRSIG), and DNS-over-TLS termination.
