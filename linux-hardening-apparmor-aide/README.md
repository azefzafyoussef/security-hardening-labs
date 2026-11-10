# Linux Host Hardening (AppArmor + OpenSCAP + AIDE)

Three complementary host controls: **AppArmor** confines a process to the files it
actually needs (mandatory access control), **OpenSCAP/OVAL** measures exposure to known
CVEs, and **AIDE** detects tampering through file-integrity monitoring.

## 1. Mandatory access control — AppArmor

AppArmor locks an application to a declared set of resources; anything outside the
profile is denied, so a compromised process cannot read `/etc/shadow` or write outside
its working files.

```bash
sudo aa-status            # module loaded, profiles in enforce/complain/unconfined
ls /etc/apparmor.d/       # profiles live here
```

**Building a profile** (the `aa-genprof` workflow):

```bash
sudo aa-genprof /usr/local/bin/logwriter   # run the app, scan the log, allow/deny each access
sudo aa-complain /usr/local/bin/logwriter  # log violations without blocking (tuning)
sudo aa-logprof                            # fold the logged accesses back into the profile
sudo aa-enforce /usr/local/bin/logwriter   # switch to blocking
```

In **complain** mode a denied write is logged as `apparmor="ALLOWED"` (observed, not
blocked); in **enforce** mode the same access is refused. `aa-logprof` reads those audit
entries and adds the missing rule — e.g. `owner /var/log/logwriter/app.log rw` — so the
app works with the minimum set of permissions.

Example profile: [`profiles/usr.local.bin.logwriter`](profiles/usr.local.bin.logwriter)
— grants the binary `mr` on itself and `rw` only on its own log file, denies the rest.

Check a running process's mode:

```bash
cat /proc/<pid>/attr/current    # /usr/local/bin/logwriter (enforce)
```

## 2. Known-CVE exposure — OpenSCAP + OVAL

[`scripts/cve-scan.sh`](scripts/cve-scan.sh) pulls the official OVAL feed for the host's
Ubuntu release and evaluates every definition against the installed packages:

```bash
sudo ./scripts/cve-scan.sh      # -> cve-report.html
```

A definition evaluating **`true`** means the matching vulnerability is present:

```
Definition oval:com.ubuntu.<rel>:def:100: true     <- vulnerable
Definition oval:com.ubuntu.<rel>:def:63742000000: false
```

The HTML report lists each USN/CVE, severity and the fixed package version to patch to.

## 3. File-integrity monitoring — AIDE

[`scripts/aide-setup.sh`](scripts/aide-setup.sh) builds a hashed baseline of the watched
paths and schedules a daily check:

```bash
sudo ./scripts/aide-setup.sh    # init baseline + cron at 03:00 -> /var/log/aide/check.log
```

Any later add / remove / content change is reported against the baseline (AIDE compares
stored hashes). Legitimate changes are folded into the baseline with
`aide --update` + `mv aide.db.new aide.db`; unexpected changes are an alert to
investigate.

## Hardening summary

| Control | Protects against | Mechanism |
|---------|------------------|-----------|
| AppArmor | A compromised process reaching files it should not | Per-binary MAC profile, least privilege |
| OpenSCAP/OVAL | Running known-vulnerable packages | Automated CVE evaluation vs. the official feed |
| AIDE | Silent tampering / persistence | Hashed baseline + scheduled integrity check |

## Skills demonstrated

Mandatory access control (AppArmor profile authoring, complain→enforce tuning,
`aa-logprof`), vulnerability assessment with OpenSCAP/OVAL, and host-based intrusion
detection with AIDE and cron.
