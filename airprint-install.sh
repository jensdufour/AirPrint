#!/usr/bin/env bash

# Copyright (c) 2024-2026 jensdufour
# Author: Jens Du Four
# License: MIT | https://github.com/jensdufour/AirPrint/raw/master/LICENSE
# Source: https://github.com/jensdufour/AirPrint

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

GH_DL="https://github.com/jensdufour/AirPrint/raw/master"
REPO_MASTER="https://raw.githubusercontent.com/jensdufour/AirPrint/master"

msg_info "Installing Dependencies"
$STD apt-get install -y \
  cups \
  cups-filters \
  avahi-daemon \
  dbus \
  python3 \
  python3-cups \
  inotify-tools
msg_ok "Installed Dependencies"

msg_info "Installing Canon UFR II Drivers"
DRIVER_URL="$GH_DL/PPD"
tmpdir=$(mktemp -d)

curl -fsSL -L "$DRIVER_URL/cnrdrvcups-ufr2-uk_5.20-1_amd64.deb" -o "$tmpdir/ufr2-core.deb"
$STD dpkg -i "$tmpdir/ufr2-core.deb" || $STD apt-get install -f -y

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
  curl -fsSL -L "$DRIVER_URL/$pkg" -o "$tmpdir/$pkg" 2>/dev/null &&
    $STD dpkg -i "$tmpdir/$pkg" || true
done
$STD apt-get install -f -y || true
rm -rf "$tmpdir"
msg_ok "Installed Canon UFR II Drivers"

msg_info "Configuring CUPS"
cat > /etc/cups/cupsd.conf << 'CUPSCONF'
LogLevel warn
MaxLogSize 0
SystemGroup lpadmin

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

useradd -m -s /bin/bash -G lpadmin admin 2>/dev/null || usermod -aG lpadmin admin
echo "admin:admin" | chpasswd
systemctl enable -q --now dbus
systemctl enable -q --now cups
systemctl enable -q --now avahi-daemon
msg_ok "Configured CUPS"

msg_info "Installing AirPrint Service Generator"
mkdir -p /opt/airprint
curl -fsSL "$REPO_MASTER/scripts/airprint-generate.py" -o /opt/airprint/airprint-generate.py
chmod +x /opt/airprint/airprint-generate.py

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

systemctl enable -q --now airprint-watcher
msg_ok "Installed AirPrint Service Generator"

motd_ssh
customize
cleanup_lxc
