#!/usr/bin/env bash
#
# aide-setup.sh - initialise AIDE file-integrity monitoring and schedule a
# daily check. AIDE stores a hashed baseline of the files it watches; on each
# run it reports anything added, removed, or modified - a host-based intrusion
# / tamper detector.
#
# Usage:  sudo ./aide-setup.sh
#
set -euo pipefail

command -v aide >/dev/null || apt-get install -y aide

echo "[*] Building the baseline database ..."
aide --init --config=/etc/aide/aide.conf
mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db

echo "[*] Scheduling a daily check at 03:00 -> /var/log/aide/check.log"
mkdir -p /var/log/aide
CRON="0 3 * * * /usr/bin/aide --check --config=/etc/aide/aide.conf >> /var/log/aide/check.log 2>&1"
( crontab -l 2>/dev/null | grep -v 'aide --check'; echo "$CRON" ) | crontab -

echo "[+] Baseline ready. To accept legitimate changes later:"
echo "    sudo aide --update --config=/etc/aide/aide.conf"
echo "    sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db"
