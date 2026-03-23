# AirPrint LXC for Proxmox VE

One-liner to create a Debian 12 LXC container running CUPS as an AirPrint relay with Canon UFR II drivers. Uses the [community-scripts/ProxmoxVE](https://github.com/community-scripts/ProxmoxVE) framework for container creation, interactive setup, and lifecycle management.

## Quick Start

Run on your **Proxmox host** shell:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/jensdufour/AirPrint/proxmox/setup-lxc.sh)"
```

You will be presented with the standard community-scripts menu (Default Install, Advanced Install, etc.). Once the container is created, open the CUPS web UI at `http://<container-ip>:631` to add your printers.

Default CUPS login: `admin` / `admin` (change after first login).

## What gets installed

- Debian 12 unprivileged LXC (via community-scripts framework)
- CUPS with network access on port 631
- Avahi for mDNS/AirPrint discovery
- Canon UFR II drivers (all models from the main branch PPD folder)
- Automatic Avahi service file generation when printers change
- Auto-login on console, MOTD with container info

## Files

| File | Runs on | Purpose |
|---|---|---|
| `setup-lxc.sh` | Proxmox host | CT script: sources community-scripts build.func, creates LXC |
| `airprint-install.sh` | Inside LXC | Installs CUPS, Avahi, Canon drivers, watcher service |
