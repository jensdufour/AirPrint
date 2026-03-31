#!/bin/sh
# Generate Avahi services for any printers already configured
python3 /opt/airprint/airprint-generate.py -d /services

inotifywait -m -e close_write,moved_to,create /etc/cups |
while read -r directory events filename; do
    if [ "$filename" = "printers.conf" ]; then
        rm -f /services/AirPrint-*.service
        python3 /opt/airprint/airprint-generate.py -d /services
        cp /etc/cups/printers.conf /config/printers.conf
    fi
done
