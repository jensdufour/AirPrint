# AirPrint LXC for Proxmox VE

One-liner to create a Debian 12 LXC container running CUPS as an AirPrint relay with Canon UFR II drivers.

## Quick Start

Run on your **Proxmox host** shell:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/jensdufour/AirPrint/proxmox/setup-lxc.sh)"
```

The interactive prompt will ask for container settings (ID, RAM, storage, CUPS credentials). Once done, open the CUPS web UI at `http://<container-ip>:631` to add your printers.

## What gets installed

- Debian 12 unprivileged LXC
- CUPS with network access
- Avahi for mDNS/AirPrint discovery
- Canon UFR II drivers (all models from the main branch PPD folder)
- Automatic Avahi service file generation when printers change

## Files

| File | Runs on | Purpose |
|---|---|---|
| `setup-lxc.sh` | Proxmox host | Creates the LXC, starts it, triggers install |
| `install.sh` | Inside LXC | Installs CUPS, Avahi, Canon drivers, watcher service |
