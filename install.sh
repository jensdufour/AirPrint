#!/usr/bin/env bash
# AirPrint relay install script - runs inside LXC
# Downloads Canon UFR II drivers from the master branch PPD folder

set -euo pipefail

REPO="${REPO:-https://raw.githubusercontent.com/jensdufour/AirPrint}"
CUPSADMIN="${CUPSADMIN:-admin}"
CUPSPASSWORD="${CUPSPASSWORD:-password}"

MASTER_URL="$REPO/master"

msg()  { printf "\033[1;34m[INFO]\033[0m  %s\n" "$1"; }
ok()   { printf "\033[1;32m[OK]\033[0m    %s\n" "$1"; }
err()  { printf "\033[1;31m[ERROR]\033[0m %s\n" "$1" >&2; exit 1; }

# ── System packages ──────────────────────────────────────
msg "Updating packages..."
apt-get update -qq
apt-get install -yqq \
  cups \
  cups-filters \
  avahi-daemon \
  python3 \
  python3-cups \
  inotify-tools \
  curl \
  >/dev/null 2>&1
ok "Packages installed."

# ── Canon UFR II drivers ─────────────────────────────────
msg "Installing Canon UFR II drivers..."
DRIVER_URL="$MASTER_URL/PPD"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# Core driver package (required for all Canon UFR II models)
curl -fsSL "$DRIVER_URL/cnrdrvcups-ufr2-uk_5.20-1_amd64.deb" -o "$tmpdir/ufr2-core.deb"
dpkg -i "$tmpdir/ufr2-core.deb" >/dev/null 2>&1 || apt-get install -f -yqq >/dev/null 2>&1

# Model-specific PPD packages
PPD_PACKAGES=(
  cnrcupsiprc710zk_5.20-1_all.deb
  cnrcupsir2425zk_5.20-1_all.deb
  cnrcupsir2625zk_5.10-1_all.deb
  cnrcupsir2635zk_5.10-1_all.deb
  cnrcupsiradv4725zk_5.10-1_all.deb
  cnrcupsiradv4745zk_5.10-1_all.deb
  cnrcupsiradv527zk_5.20-1_all.deb
  cnrcupsiradv6000zk_5.10-1_all.deb
  cnrcupsiradv617zk_5.20-1_all.deb
  cnrcupsiradv6755zk_5.10-1_all.deb
  cnrcupsiradv6780zk_5.10-1_all.deb
  cnrcupsiradv717zk_5.20-1_all.deb
  cnrcupsiradv8705zk_5.10-1_all.deb
  cnrcupsiradv8786zk_5.10-1_all.deb
  cnrcupsiradvc257zk_5.20-1_all.deb
  cnrcupsiradvc3720zk_5.10-1_all.deb
  cnrcupsiradvc3725zk_5.10-1_all.deb
  cnrcupsiradvc477zk_5.20-1_all.deb
  cnrcupsiradvc5735zk_5.10-1_all.deb
  cnrcupsiradvc5750zk_5.10-1_all.deb
  cnrcupsiradvc7765zk_5.10-1_all.deb
  cnrcupsiradvc7780zk_5.10-1_all.deb
  cnrcupsirc3120lzk_5.10-1_all.deb
  cnrcupsirc3120zk_5.10-1_all.deb
  cnrcupsirc3125zk_5.10-1_all.deb
  cnrcupslbp1127czk_5.20-1_all.deb
  cnrcupslbp1238zk_5.20-1_all.deb
  cnrcupslbp222zk_5.10-1_all.deb
  cnrcupslbp223zk_5.10-1_all.deb
  cnrcupslbp225zk_5.10-1_all.deb
  cnrcupslbp226zk_5.10-1_all.deb
  cnrcupslbp227zk_5.10-1_all.deb
  cnrcupslbp228zk_5.10-1_all.deb
  cnrcupsmf1127czk_5.20-1_all.deb
  cnrcupsmf1238zk_5.20-1_all.deb
  cnrcupsx1643pzk_5.20-1_all.deb
)

for pkg in "${PPD_PACKAGES[@]}"; do
  curl -fsSL "$DRIVER_URL/$pkg" -o "$tmpdir/$pkg" 2>/dev/null && \
    dpkg -i "$tmpdir/$pkg" >/dev/null 2>&1 || true
done
apt-get install -f -yqq >/dev/null 2>&1 || true
ok "Canon drivers installed."

# ── CUPS admin user ──────────────────────────────────────
msg "Configuring CUPS admin..."
if ! id "$CUPSADMIN" >/dev/null 2>&1; then
  useradd -r -G lpadmin -M "$CUPSADMIN"
fi
echo "$CUPSADMIN:$CUPSPASSWORD" | chpasswd
ok "Admin user '$CUPSADMIN' configured."

# ── CUPS configuration ───────────────────────────────────
msg "Configuring CUPS..."
cat > /etc/cups/cupsd.conf << 'CUPSCONF'
LogLevel warn
MaxLogSize 0

Listen 0.0.0.0:631
Listen /run/cups/cups.sock

Browsing On
BrowseLocalProtocols dnssd

DefaultAuthType Basic
WebInterface Yes
ServerAlias *
DefaultEncryption Never

<Location />
  Order allow,deny
  Allow All
</Location>

<Location /admin>
  Order allow,deny
  Allow All
  Require user @SYSTEM
</Location>

<Location /admin/conf>
  AuthType Default
  Require user @SYSTEM
  Order allow,deny
  Allow All
</Location>

<Location /admin/log>
  AuthType Default
  Require user @SYSTEM
  Order allow,deny
  Allow All
</Location>

<Policy default>
  JobPrivateAccess default
  JobPrivateValues default
  SubscriptionPrivateAccess default
  SubscriptionPrivateValues default

  <Limit Create-Job Print-Job Print-URI Validate-Job>
    Order deny,allow
  </Limit>

  <Limit Send-Document Send-URI Hold-Job Release-Job Restart-Job Purge-Jobs Set-Job-Attributes Create-Job-Subscription Renew-Subscription Cancel-Subscription Get-Notifications Reprocess-Job Cancel-Current-Job Suspend-Current-Job Resume-Job Cancel-My-Jobs Close-Job CUPS-Move-Job CUPS-Get-Document>
    Require user @OWNER @SYSTEM
    Order deny,allow
  </Limit>

  <Limit CUPS-Add-Modify-Printer CUPS-Delete-Printer CUPS-Add-Modify-Class CUPS-Delete-Class CUPS-Set-Default CUPS-Get-Devices>
    AuthType Default
    Require user @SYSTEM
    Order deny,allow
  </Limit>

  <Limit Pause-Printer Resume-Printer Enable-Printer Disable-Printer Pause-Printer-After-Current-Job Hold-New-Jobs Release-Held-New-Jobs Deactivate-Printer Activate-Printer Restart-Printer Shutdown-Printer Startup-Printer Promote-Job Schedule-Job-After Cancel-Jobs CUPS-Accept-Jobs CUPS-Reject-Jobs>
    AuthType Default
    Require user @SYSTEM
    Order deny,allow
  </Limit>

  <Limit Cancel-Job CUPS-Authenticate-Job>
    Require user @OWNER @SYSTEM
    Order deny,allow
  </Limit>

  <Limit All>
    Order deny,allow
  </Limit>
</Policy>
CUPSCONF
ok "CUPS configured."

# ── AirPrint generator script ────────────────────────────
msg "Installing AirPrint service generator..."
mkdir -p /opt/airprint

curl -fsSL "$MASTER_URL/scripts/airprint-generate.py" -o /opt/airprint/airprint-generate.py
chmod +x /opt/airprint/airprint-generate.py

# ── Printer watcher service ──────────────────────────────
cat > /opt/airprint/printer-update.sh << 'WATCHER'
#!/bin/sh
inotifywait -m -e close_write,moved_to,create /etc/cups |
while read -r directory events filename; do
    if [ "$filename" = "printers.conf" ]; then
        rm -f /etc/avahi/services/AirPrint-*.service
        python3 /opt/airprint/airprint-generate.py -d /etc/avahi/services
    fi
done
WATCHER
chmod +x /opt/airprint/printer-update.sh

cat > /etc/systemd/system/airprint-watcher.service << 'UNIT'
[Unit]
Description=AirPrint Avahi service file generator
After=cups.service avahi-daemon.service
Requires=cups.service

[Service]
Type=simple
ExecStart=/opt/airprint/printer-update.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

ok "AirPrint watcher installed."

# ── Enable and start services ────────────────────────────
msg "Starting services..."
systemctl enable --now cups >/dev/null 2>&1
systemctl enable --now avahi-daemon >/dev/null 2>&1
systemctl enable --now airprint-watcher >/dev/null 2>&1
ok "All services running."

echo ""
ok "AirPrint relay installation complete."
