#!/bin/sh
set -e

CUPSADMIN="${CUPSADMIN:-admin}"
CUPSPASSWORD="${CUPSPASSWORD:-password}"

# Create admin user if not exists
if ! id "$CUPSADMIN" >/dev/null 2>&1; then
    addgroup -S lpadmin 2>/dev/null || true
    adduser -S -G lpadmin -H "$CUPSADMIN"
fi
echo "$CUPSADMIN:$CUPSPASSWORD" | chpasswd

# Set up persistent config
mkdir -p /config/ppd /services
rm -rf /etc/cups/ppd
ln -sf /config/ppd /etc/cups/ppd

if [ ! -f /config/printers.conf ]; then
    touch /config/printers.conf
fi
cp /config/printers.conf /etc/cups/printers.conf

# Start dbus if not already running (allows use of host dbus via volume mount)
if [ ! -S /run/dbus/system_bus_socket ]; then
    mkdir -p /run/dbus
    rm -f /run/dbus/pid
    dbus-daemon --system
fi

# Point Avahi services to the /services volume and start
rm -rf /etc/avahi/services
ln -sf /services /etc/avahi/services
avahi-daemon -D

# Watch for printer config changes in background
/opt/airprint/printer-update.sh &

exec cupsd -f
