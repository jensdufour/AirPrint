#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2024-2026 jensdufour
# Author: Jens Du Four
# License: MIT | https://github.com/jensdufour/AirPrint/raw/master/LICENSE
# Source: https://github.com/jensdufour/AirPrint

APP="AirPrint"
var_tags="${var_tags:-printing}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-512}"
var_disk="${var_disk:-4}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -f /opt/airprint/airprint-generate.py ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  msg_info "Updating $APP LXC"
  $STD apt-get update
  $STD apt-get -y upgrade
  curl -fsSL https://raw.githubusercontent.com/jensdufour/AirPrint/master/scripts/airprint-generate.py -o /opt/airprint/airprint-generate.py
  systemctl restart airprint-watcher
  msg_ok "Updated $APP LXC"
  exit
}

start
build_container

# build_container installs base packages and runs the community-scripts
# install script URL which does not exist for this app (external project).
# Run our own install script inside the container instead.
msg_info "Installing AirPrint"
lxc-attach -n "$CTID" -- bash -c "$(curl -fsSL https://raw.githubusercontent.com/jensdufour/AirPrint/proxmox/airprint-install.sh)"
msg_ok "Installed AirPrint"

description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:631${CL}"
