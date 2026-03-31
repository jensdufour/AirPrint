# AirPrint LXC for Proxmox VE

Debian 12 LXC container running CUPS as an AirPrint relay with Canon UFR II V6.20 drivers. Uses the [community-scripts/ProxmoxVE](https://github.com/community-scripts/ProxmoxVE) framework for container creation and lifecycle management.

## Quick Start

Run on your **Proxmox host** shell:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/jensdufour/AirPrint/proxmox/setup-lxc.sh)"
```

You will be presented with the standard community-scripts menu (Default Install, Advanced Install, etc.). Once the container is created, open the CUPS web UI at `http://<container-ip>:631` to add your printers.

Default CUPS login: `admin` / `admin` (change after first login with `passwd admin`).

## Adding a Printer

Use `socket://` with `waiteof=false` for reliable printing without duplicate jobs:

```bash
lpadmin -p Canon_iR1133 -E \
  -v "socket://<PRINTER_IP>:9100/?waiteof=false" \
  -m "lsb/usr/CNRCUPSIR1133ZK.ppd" \
  -o media=iso_a4_210x297mm

lpadmin -p Canon_iR1133 -o printer-is-shared=true
lpadmin -d Canon_iR1133
systemctl restart cups
```

Replace the printer name, IP, and PPD with your model. List available PPDs with:

```bash
lpinfo --make-and-model "Canon" -m
```

The AirPrint watcher service automatically regenerates Avahi service files when printers change.

## What Gets Installed

- Debian 12 unprivileged LXC (2 CPU, 1024 MB RAM, 4 GB disk)
- CUPS with network access on port 631
- Avahi for mDNS/AirPrint discovery
- Canon UFR II V6.20 drivers (downloaded from Canon CDN at install time)
- Automatic Avahi service file generation with proper URF/TXT records for iOS
- Default paper size set to A4
- cups-browsed disabled for performance

## Files

| File | Runs on | Purpose |
|---|---|---|
| `setup-lxc.sh` | Proxmox host | CT script: sources community-scripts build.func, creates LXC |
| `install.sh` | Inside LXC | Installs CUPS, Avahi, Canon drivers, watcher service |
| `scripts/airprint-generate.py` | Inside LXC | Generates Avahi service files with AirPrint TXT records |
