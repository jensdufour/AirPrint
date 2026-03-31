# AirPrint Docker  <a href="https://hub.docker.com/r/firilith/airprint/"><img src="https://img.shields.io/docker/pulls/firilith/airprint.svg?style=flat-square&logo=docker" alt="Docker Pulls"></a>

Alpine-based Docker image running CUPS as an AirPrint relay with Canon UFR II V6.20 drivers. The Canon driver is downloaded from Canon CDN at build time.

Uses host networking mode for mDNS/AirPrint discovery.

> For a Proxmox LXC version, see the [`proxmox`](https://github.com/jensdufour/AirPrint/tree/proxmox) branch.

## Compose

```yaml
services:
  airprint:
    image: firilith/airprint:latest
    container_name: airprint
    network_mode: host
    environment:
      - TZ=Europe/Brussels
      - CUPSADMIN=admin
      - CUPSPASSWORD=password
    volumes:
      - /media/config/airprint:/config
      - /media/config/airprint/services:/services
    restart: unless-stopped
```

## Parameters

| Parameter | Description |
|---|---|
| `--net=host` | Required for mDNS/AirPrint discovery |
| `-v /config:/config` | Persistent printer configuration |
| `-v /services:/services` | Avahi service files (auto-generated) |
| `-e CUPSADMIN` | CUPS admin username (default: `admin`) |
| `-e CUPSPASSWORD` | CUPS admin password (default: `password`) |

## Usage

CUPS will be available at `http://localhost:631`. Log in with `CUPSADMIN`/`CUPSPASSWORD` to add printers.

When adding a printer via the CUPS web UI, use `socket://<PRINTER_IP>:9100/?waiteof=false` as the connection URI to avoid duplicate prints on socket connections.

The AirPrint watcher automatically generates Avahi service files with proper URF/TXT records for iOS whenever printers change in CUPS.

## What's Included

- CUPS with Ghostscript and cups-filters
- Avahi for mDNS/AirPrint discovery
- Canon UFR II V6.20 drivers (downloaded from Canon CDN at build time)
- Automatic Avahi service file generation with proper AirPrint TXT records
- Default paper size set to A4

## Files

| File | Purpose |
|---|---|
| `Dockerfile` | Multi-stage build: downloads Canon V6.20 driver, Alpine runtime |
| `cupsd.conf` | Optimized CUPS config (browsing off, performance tuned) |
| `scripts/airprint-generate.py` | Generates Avahi service files with AirPrint TXT records |
| `scripts/printer-update.sh` | Watches for printer changes, regenerates Avahi files |
| `scripts/run_cups.sh` | Container entrypoint: sets up user, dbus, avahi, CUPS |

## Notes

- CUPS doesn't write `printers.conf` immediately when making changes even though they're live. It will take a few moments before the service files update.
- Don't stop the container immediately if you intend to have a persistent configuration for this same reason.
