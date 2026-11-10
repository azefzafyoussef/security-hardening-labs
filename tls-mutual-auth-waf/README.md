# TLS, Mutual Authentication & WAF

Turning a plain HTTP server into a hardened HTTPS endpoint: a private CA, a server
certificate, **mutual TLS** on a protected area, removal of obsolete protocols/ciphers,
HSTS, and a **ModSecurity + OWASP Core Rule Set** web application firewall.

## 1. Build the PKI

[`pki/build-pki.sh`](pki/build-pki.sh) creates a root CA and signs a server certificate
and a client certificate from it, so the client cert is trusted by the same CA the
server presents.

```bash
cd pki && ./build-pki.sh 192.168.56.10
openssl verify -CAfile pki-out/ca.crt pki-out/server.crt   # -> server.crt: OK
```

Install the server material and enable the vhost:

```bash
sudo mkdir -p /etc/ssl/lab
sudo cp pki-out/{server.crt,server.key,ca.crt} /etc/ssl/lab/
sudo cp apache/hardened-ssl.conf /etc/apache2/sites-available/
sudo a2enmod ssl headers rewrite && sudo a2ensite hardened-ssl
sudo systemctl reload apache2
```

## 2. TLS handshake & certificate validation

Inspect the negotiated session and verify the chain:

```bash
openssl s_client -connect 192.168.56.10:443 -CAfile /etc/ssl/lab/ca.crt
# New, TLSv1.3, Cipher is TLS_AES_256_GCM_SHA384
# Verify return code: 0 (ok)
```

A certificate is accepted only when the signature chains to a trusted CA, the dates are
current, the CN/SAN matches the host, and it is not revoked (OCSP).

## 3. HTTP → HTTPS redirect + HSTS

Port 80 answers every request with `301 -> https://`. After the first HTTPS response the
`Strict-Transport-Security` header pins the browser to HTTPS for a year:

```bash
curl -sI http://192.168.56.10/        # HTTP/1.1 301 Moved Permanently
openssl s_client -connect 192.168.56.10:443 -quiet </dev/null 2>/dev/null \
  | grep -i strict-transport           # Strict-Transport-Security: max-age=31536000; ...
```

## 4. Disable obsolete protocols & ciphers

`SSLProtocol -all +TLSv1.2 +TLSv1.3` makes the server reject everything older. A TLS 1.0
client is turned away at the handshake:

```bash
openssl s_client -connect 192.168.56.10:443 -tls1
# ... alert protocol version ... New, (NONE), Cipher is (NONE)
```

## 5. Mutual TLS on `/private`

The public site needs no client certificate; `/private` requires one signed by our CA
(`SSLVerifyClient require`). Import `client.p12` into the browser, or test on the CLI:

```bash
# Rejected without a client certificate:
curl -k https://192.168.56.10/private/        # 403 / handshake fails

# Accepted with the client certificate:
curl --cacert pki-out/ca.crt \
     --cert pki-out/client.crt --key pki-out/client.key \
     https://192.168.56.10/private/           # 200 OK
```

## 6. Web Application Firewall (ModSecurity + OWASP CRS)

A WAF is the request-filtering layer in front of the app. Install the engine and the
OWASP Core Rule Set, then turn detection into blocking:

```bash
sudo apt install libapache2-mod-security2
sudo git clone https://github.com/coreruleset/coreruleset /etc/modsecurity-crs
sudo cp /etc/modsecurity-crs/crs-setup.conf.example /etc/modsecurity-crs/crs-setup.conf
# /etc/modsecurity/modsecurity.conf
sudo sed -i 's/^SecRuleEngine .*/SecRuleEngine On/' /etc/modsecurity/modsecurity.conf
sudo systemctl restart apache2
```

Enable the CRS in `security2.conf`:

```apache
<IfModule security2_module>
    SecDataDir /var/cache/modsecurity
    IncludeOptional /etc/modsecurity/*.conf
    IncludeOptional /etc/modsecurity-crs/crs-setup.conf
    IncludeOptional /etc/modsecurity-crs/rules/*.conf
</IfModule>
```

XSS and path-traversal attempts are now blocked (`403`) and logged with the rule id,
timestamp and client IP, while legitimate traffic passes untouched:

```
https://192.168.56.10/?q=<script>alert(1)</script>     -> 403, logged
https://192.168.56.10/../../../../etc/passwd            -> 403, logged
```

## Hardening summary

| Threat | Control in this lab |
|--------|---------------------|
| Eavesdropping / MITM | TLS 1.2+/1.3 only, strong cipher suites, HSTS |
| Downgrade to weak TLS | `SSLProtocol -all +TLSv1.2 +TLSv1.3`, `SSLHonorCipherOrder on` |
| Unauthenticated access to sensitive area | Mutual TLS (`SSLVerifyClient require`) |
| Injection / XSS / path traversal | ModSecurity + OWASP CRS |
| Clickjacking / MIME sniffing | `X-Frame-Options`, `X-Content-Type-Options` |

## Skills demonstrated

PKI and X.509 (CA, CSR, signing, SAN, PKCS#12), Apache TLS configuration, mutual
authentication, protocol/cipher hardening, HSTS and security headers, and WAF deployment
with the OWASP Core Rule Set.
