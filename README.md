# Security Hardening Labs (Blue Team)

Defensive-security labs: building the controls that stop the attacks. Each lab is a
self-contained, reproducible setup with working scripts and configuration — PKI and
mutual-TLS, a signed and encrypted DNS infrastructure, a Windows configuration-audit
tool, and Linux host hardening with mandatory access control and file-integrity
monitoring.

This is the **defensive counterpart** to my offensive work
([`pentest-writeups`](https://github.com/azefzafyoussef/pentest-writeups) and
`binary-exploitation-x86`): the same vulnerability classes, seen from the side of the
engineer who has to remediate them.

## Labs

| # | Lab | What it hardens | Key tech |
|---|-----|-----------------|----------|
| [tls-mutual-auth-waf](tls-mutual-auth-waf/) | **TLS, mutual auth & WAF** | Web traffic: encryption, client identity, weak-protocol removal, request filtering | OpenSSL PKI, Apache SSL, mTLS, HSTS, ModSecurity + OWASP CRS |
| [dnssec-bind9](dnssec-bind9/) | **Signed & encrypted DNS** | DNS integrity and confidentiality: cache poisoning, spoofing, zone-transfer theft | BIND9, DNSSEC (KSK/ZSK), TSIG, DNS-over-TLS |
| [windows-config-audit](windows-config-audit/) | **Windows server config** | Attack surface: cold-audit a server and rate 18 misconfigurations | VBScript collector, risk-rated findings, ANSSI/CIS-style remediation |
| [linux-hardening-apparmor-aide](linux-hardening-apparmor-aide/) | **Linux host** | Process confinement, known-CVE exposure, tamper detection | AppArmor (MAC), OpenSCAP/OVAL, AIDE |

## Approach used across the labs

- **Defence in depth** — every control is one layer: a WAF does not excuse an injectable
  app, mTLS does not excuse a weak cipher suite.
- **Least privilege** — AppArmor profiles grant only the paths a process actually needs;
  firewall and ACL findings are rated by how far they widen access.
- **Risk-rated findings** — a 1 (minor) → 4 (critical) scale, each finding paired with a
  concrete, actionable fix, mirroring a real audit deliverable.
- **Reproducible** — scripts regenerate the PKI, sign the zones, or collect the audit
  from scratch; no manual click-through.

> Lab / training environments on isolated networks. All secrets shown
> (keys, PSKs, passwords) are **placeholders** — regenerate your own.
