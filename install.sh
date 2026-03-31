#!/usr/bin/env bash

# Copyright (c) 2024-2026 jensdufour
# Author: Jens Du Four
# License: MIT | https://github.com/jensdufour/AirPrint/raw/master/LICENSE
# Source: https://github.com/jensdufour/AirPrint

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
BL='\033[36m'; GN='\033[32m'; RD='\033[31m'; CL='\033[0m'
msg_info()  { echo -e " ${BL}[INFO]${CL}  $1"; }
msg_ok()    { echo -e " ${GN}[OK]${CL}    $1"; }
msg_error() { echo -e " ${RD}[ERROR]${CL} $1"; }

REPO_URL="https://raw.githubusercontent.com/jensdufour/AirPrint/proxmox"
DRIVER_URL="https://github.com/jensdufour/AirPrint/raw/master/PPD"

# ---------------------------------------------------------------------------
# System update
# ---------------------------------------------------------------------------
msg_info "Updating system"
apt-get update -qq >/dev/null 2>&1
apt-get upgrade -y -qq >/dev/null 2>&1
msg_ok "System updated"

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------
msg_info "Installing dependencies"
apt-get install -y -qq \
  cups \
  cups-filters \
  cups-ipp-utils \
  avahi-daemon \
  dbus \
  ghostscript \
  fonts-freefont-ttf \
  python3 \
  python3-cups \
  inotify-tools \
  libxml2 \
  libglib2.0-0 \
  libjpeg62-turbo \
  libpng16-16 \
  libtiff6 \
  libstdc++6 >/dev/null 2>&1
msg_ok "Dependencies installed"

# cups-browsed continuously scans the network and uses significant resources
msg_info "Disabling cups-browsed"
systemctl disable --now cups-browsed >/dev/null 2>&1 || true
systemctl mask cups-browsed >/dev/null 2>&1 || true
msg_ok "cups-browsed disabled"

# ---------------------------------------------------------------------------
# Default paper size (A4)
# ---------------------------------------------------------------------------
msg_info "Setting default paper size to A4"
echo "a4" > /etc/papersize
msg_ok "Default paper size set to A4"

# ---------------------------------------------------------------------------
# Canon UFR II drivers (V6.20 for Debian 12)
# ---------------------------------------------------------------------------
msg_info "Installing Canon UFR II drivers"
tmpdir=$(mktemp -d)

# Download the V6.20 driver tarball from Canon CDN
CANON_URL="http://gdlp01.c-wss.com/gds/8/0100007658/47/linux-UFRII-drv-v620-m17n-20.tar.gz"
if curl -fsSL -L "$CANON_URL" -o "$tmpdir/canon-ufr2.tar.gz"; then
  tar -xzf "$tmpdir/canon-ufr2.tar.gz" -C "$tmpdir"

  # Install the amd64 package (single .deb contains driver + PPDs)
  DEB_FILE=$(find "$tmpdir" -path '*/x64/Debian/*.deb' -type f | head -1)
  if [ -n "$DEB_FILE" ]; then
    dpkg -i "$DEB_FILE" 2>&1 || true
    apt-get install -f -y >/dev/null 2>&1
  else
    msg_error "Could not find amd64 .deb in Canon tarball"
  fi
else
  msg_error "Could not download Canon driver from Canon CDN"
fi

rm -rf "$tmpdir"

# Verify the filter binary exists
UFR2_FILTER=$(find /usr/lib/cups/filter/ -name '*ufr2*' 2>/dev/null | head -1)
if [ -n "$UFR2_FILTER" ]; then
  msg_ok "Canon UFR II drivers installed (filter: $(basename "$UFR2_FILTER"))"
else
  msg_error "Canon UFR II filter binary not found after install"
  msg_info "Available CUPS filters:"
  ls /usr/lib/cups/filter/ 2>&1
fi

# ---------------------------------------------------------------------------
# CUPS configuration
# ---------------------------------------------------------------------------
msg_info "Configuring CUPS"
cat > /etc/cups/cupsd.conf << 'CUPSCONF'
LogLevel warn
MaxLogSize 0
SystemGroup lpadmin

Listen 0.0.0.0:631
Listen /run/cups/cups.sock

# Disable CUPS browsing; Avahi handles mDNS/AirPrint discovery
Browsing Off

HostNameLookups Off
DNSSDAutoRegister No

DefaultAuthType Basic
WebInterface Yes
ServerAlias *
DefaultEncryption Never

PreserveJobHistory No
PreserveJobFiles No
MaxJobs 100

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

useradd -m -s /bin/bash -G lpadmin admin 2>/dev/null || usermod -aG lpadmin admin
echo "admin:admin" | chpasswd

# Disable socket activation so CUPS runs as a persistent service
systemctl disable --now cups.socket cups.path >/dev/null 2>&1 || true
systemctl enable --now dbus >/dev/null 2>&1
systemctl enable --now cups >/dev/null 2>&1
systemctl enable --now avahi-daemon >/dev/null 2>&1
msg_ok "CUPS configured"

# ---------------------------------------------------------------------------
# AirPrint service generator
# ---------------------------------------------------------------------------
msg_info "Setting up AirPrint service generator"
mkdir -p /opt/airprint
curl -fsSL "$REPO_URL/scripts/airprint-generate.py" \
  -o /opt/airprint/airprint-generate.py
chmod +x /opt/airprint/airprint-generate.py

cat > /opt/airprint/printer-update.sh << 'WATCHER'
#!/bin/sh
# Generate Avahi services for any printers already configured
python3 /opt/airprint/airprint-generate.py -d /etc/avahi/services

# Watch for CUPS printer changes and regenerate
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

systemctl daemon-reload >/dev/null 2>&1
systemctl enable --now airprint-watcher >/dev/null 2>&1
msg_ok "AirPrint service generator configured"

# ---------------------------------------------------------------------------
# Post-install notes
# ---------------------------------------------------------------------------
msg_info "Add your printer with socket:// and waiteof=false to avoid duplicate prints:"
msg_info "  lpadmin -p <NAME> -E -v 'socket://<IP>:9100/?waiteof=false' -m <PPD> -o media=iso_a4_210x297mm"
msg_info "  lpadmin -p <NAME> -o printer-is-shared=true"
msg_info "  lpadmin -d <NAME>"

msg_ok "Installation complete"
