# Windows Server Configuration Audit

A **cold configuration audit** of a Windows server: a self-contained collector script
that gathers the security-relevant configuration without any interaction, followed by a
risk-rated analysis of 18 misconfigurations with concrete remediation.

A cold audit works from a snapshot of the configuration (no live access to the running
server), which is exactly how a compliance/hardening review is done in practice.

## 1. Collection

[`scripts/collect-config.vbs`](scripts/collect-config.vbs) is autonomous — it takes no
input, runs from an elevated `cmd`, works on Server 2008+, and writes every artefact into
one timestamped, zipped folder:

```cmd
cscript //nologo collect-config.vbs
:: -> audit_<HOST>_<timestamp>.zip
```

It collects: OS configuration, network configuration, open ports, firewall rules &
profiles, GPO (`gpresult /z`), local groups & users, installed software & updates, all
services + auto-start services, startup apps, running processes, scheduled tasks, SMB
shares & server config, installed roles, the UAC setting, the exported security policy,
the System/Security event logs, and the `SAM`/`SYSTEM` registry hives.

## 2. Risk scale

| Score | Level | Meaning |
|:---:|---|---|
| 4 | **Critical** | Can lead to full compromise of the system or service |
| 3 | **Major** | Limited risk affecting part of the system if exploited |
| 2 | **Medium** | May disclose information usable to exploit worse flaws |
| 1 | **Minor** | Technical info only, no direct impact alone |

## 3. Findings

| # | Finding | Area | Risk | Remediation |
|---|---------|------|:---:|-------------|
| V1 | End-of-life OS (Windows Server 2012 R2) — no security updates | OS config | 4 | Upgrade to a supported release (2019/2022) |
| V2 | Firewall allows MySQL/3306 inbound from any IP (Private+Domain) | Firewall | 3 | Restrict 3306 to the allowed hosts |
| V3 | Firewall allows Firefox inbound (TCP+UDP) from any IP | Firewall | 2 | Restrict to the connections actually needed |
| V4 | HTTP (80) open to the world, no restriction | Firewall | 3 | Limit source IPs, redirect to HTTPS, front with a WAF |
| V5 | RDP (3389 TCP/UDP) open to the world on all profiles | Firewall | 4 | Restrict source IPs, add MFA + account lockout |
| V6 | Teredo (IPv6-over-UDP) allowed in/out on all profiles | Firewall | 4 | Disable/remove Teredo (obsolete) |
| V7 | RDP-Shadow rule enabled only on the Public profile | Firewall | 2 | Extend the rule to Private + Domain |
| V8 | WinRM over plain HTTP (5985), any IP, all profiles | Firewall | 3 | Use HTTPS/5986, limit source IPs, add MFA |
| V9 | Many obsolete/unsupported software packages installed | Software | 2 | Update to supported versions; remove unused software |
| V10 | Enabled account (`test`) created with "password not required" | Event logs | 4 | Require a strong password or disable the account |
| V11 | Event logs oversized, hampering incident detection | Event logs | 1 | Archive/rotate old logs |
| V12 | NetBIOS port 139 open to all (obsolete, vulnerable) | Open ports | 3 | Replace with SMBv2/SMBv3, close 139 |
| V13 | IIS serving HTTP instead of HTTPS | Open ports | 3 | Enforce HTTPS (443), redirect from 80 |
| V14 | Database port 3306 exposed to everyone | Open ports | 3 | Allow only IIS / DBA / developers |
| V15 | Unneeded ports (445, 3389, 5985) open on a web server | Open ports | 3 | Close every port the role does not need |
| V16 | WinRM service running though IIS does not use it | Services | 2 | Uninstall services the role does not need |
| V17 | MySQL 5.7 — old version with known vulnerabilities | Services | 3 | Upgrade to a supported MySQL release |
| V18 | Entire `C:\` root shared over SMB | SMB | 4 | Share only the required directory, never the drive root |

### Themes
- **Attack surface** (V2–V8, V12–V16): the host exposes services and ports it does not
  need, often with no source-IP restriction — close them and scope the firewall to the role.
- **Credential & account hygiene** (V10): an enabled account with no required password is
  an open door.
- **Obsolescence** (V1, V9, V17): unsupported OS and software receive no patches.
- **Over-sharing** (V18): sharing `C:\` turns one SMB flaw into full disk access.

## References

ANSSI web-security recommendations, Microsoft AD DS "events to monitor", CERT-FR
advisories, and the Snyk vulnerability DB were used to rate and justify the findings.

## Skills demonstrated

Scripted evidence collection (VBScript + built-in Windows tooling), configuration-audit
methodology, Windows firewall / service / SMB / GPO analysis, risk rating, and writing a
remediation-focused audit deliverable.
