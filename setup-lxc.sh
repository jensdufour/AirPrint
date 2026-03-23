#!/usr/bin/env bash
# Setup AirPrint relay LXC on Proxmox VE
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/jensdufour/AirPrint/proxmox/setup-lxc.sh)"

set -euo pipefail

REPO_BASE="https://raw.githubusercontent.com/jensdufour/AirPrint"
REPO_PROXMOX="$REPO_BASE/proxmox"
REPO_MASTER="$REPO_BASE/master"

# ── Defaults ──────────────────────────────────────────────
CT_ID=""
HOSTNAME="airprint"
DISK_SIZE="4"
RAM="512"
CORES="1"
STORAGE="local-lvm"
BRIDGE="vmbr0"
IP_CONFIG="dhcp"
CUPSADMIN="admin"
CUPSPASSWORD=""

# ── Colors ────────────────────────────────────────────────
msg()  { printf "\033[1;34m[INFO]\033[0m  %s\n" "$1"; }
ok()   { printf "\033[1;32m[OK]\033[0m    %s\n" "$1"; }
err()  { printf "\033[1;31m[ERROR]\033[0m %s\n" "$1" >&2; exit 1; }

# ── Checks ────────────────────────────────────────────────
command -v pveversion >/dev/null 2>&1 || err "This script must be run on a Proxmox VE host."
command -v pct >/dev/null 2>&1 || err "pct command not found."

# ── Pick next free CT ID ──────────────────────────────────
next_id() {
  local id
  id=$(pvesh get /cluster/nextid 2>/dev/null) || id="100"
  echo "$id"
}

# ── Interactive setup ─────────────────────────────────────
echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║      AirPrint LXC Setup Script       ║"
echo "  ╚══════════════════════════════════════╝"
echo ""

CT_ID=$(next_id)
read -rp "Container ID [$CT_ID]: " input && CT_ID="${input:-$CT_ID}"
read -rp "Hostname [$HOSTNAME]: " input && HOSTNAME="${input:-$HOSTNAME}"
read -rp "Disk size in GB [$DISK_SIZE]: " input && DISK_SIZE="${input:-$DISK_SIZE}"
read -rp "RAM in MB [$RAM]: " input && RAM="${input:-$RAM}"
read -rp "CPU cores [$CORES]: " input && CORES="${input:-$CORES}"
read -rp "Storage [$STORAGE]: " input && STORAGE="${input:-$STORAGE}"
read -rp "Network bridge [$BRIDGE]: " input && BRIDGE="${input:-$BRIDGE}"
read -rp "IP address (CIDR) or 'dhcp' [$IP_CONFIG]: " input && IP_CONFIG="${input:-$IP_CONFIG}"

if [ "$IP_CONFIG" != "dhcp" ]; then
  GW_DEFAULT=$(echo "$IP_CONFIG" | sed 's|/.*||; s|\.[0-9]*$|.1|')
  read -rp "Gateway [$GW_DEFAULT]: " input && GATEWAY="${input:-$GW_DEFAULT}"
fi

read -rp "CUPS admin username [$CUPSADMIN]: " input && CUPSADMIN="${input:-$CUPSADMIN}"

CUPSPASSWORD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)
msg "Generated CUPS admin password (shown at the end)."

# ── Download Debian 12 template ──────────────────────────
TEMPLATE="debian-12-standard"
TEMPLATE_FILE=$(pveam list local 2>/dev/null | grep "$TEMPLATE" | tail -1 | awk '{print $1}')

if [ -z "$TEMPLATE_FILE" ]; then
  msg "Downloading Debian 12 template..."
  pveam update >/dev/null 2>&1
  TEMPLATE_DL=$(pveam available --section system 2>/dev/null | grep "$TEMPLATE" | tail -1 | awk '{print $2}')
  [ -z "$TEMPLATE_DL" ] && err "Could not find Debian 12 template."
  pveam download local "$TEMPLATE_DL" >/dev/null 2>&1
  TEMPLATE_FILE="local:vztmpl/$TEMPLATE_DL"
  ok "Template downloaded."
else
  ok "Template found: $TEMPLATE_FILE"
fi

# ── Create LXC ───────────────────────────────────────────
msg "Creating LXC $CT_ID ($HOSTNAME)..."

pct create "$CT_ID" "$TEMPLATE_FILE" \
  --hostname "$HOSTNAME" \
  --memory "$RAM" \
  --cores "$CORES" \
  --rootfs "$STORAGE:$DISK_SIZE" \
  --net0 "name=eth0,bridge=$BRIDGE,$([ "$IP_CONFIG" = "dhcp" ] && echo 'ip=dhcp' || echo "ip=$IP_CONFIG,gw=$GATEWAY")" \
  --unprivileged 1 \
  --features nesting=1 \
  --onboot 1 \
  --start 0

ok "LXC $CT_ID created."

# ── Start and wait for network ───────────────────────────
msg "Starting LXC..."
pct start "$CT_ID"
sleep 5

# Wait for network
for i in $(seq 1 30); do
  if pct exec "$CT_ID" -- ping -c1 -W1 deb.debian.org >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

pct exec "$CT_ID" -- ping -c1 -W3 deb.debian.org >/dev/null 2>&1 || err "LXC has no network connectivity."
ok "Network is up."

# ── Run install script inside LXC ────────────────────────
msg "Running install script inside LXC..."
pct exec "$CT_ID" -- bash -c "
  export CUPSADMIN='$CUPSADMIN'
  export CUPSPASSWORD='$CUPSPASSWORD'
  export REPO_PROXMOX='$REPO_PROXMOX'
  export REPO_MASTER='$REPO_MASTER'
  bash <(curl -fsSL '$REPO_PROXMOX/install.sh')
"

# ── Get IP and print summary ─────────────────────────────
IP=$(pct exec "$CT_ID" -- hostname -I 2>/dev/null | awk '{print $1}')

echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║         Setup Complete               ║"
echo "  ╚══════════════════════════════════════╝"
echo ""
echo "  LXC ID:     $CT_ID"
echo "  Hostname:   $HOSTNAME"
echo "  IP:         ${IP:-unknown}"
echo "  CUPS UI:    http://${IP:-<ip>}:631"
echo "  Admin user: $CUPSADMIN"
echo "  Admin pass: $CUPSPASSWORD"
echo ""
ok "AirPrint relay is running. Add printers via the CUPS web UI."
ok "Save the password above, it will not be shown again."
