#!/usr/bin/env bash
# Engine comes from community-scripts/core; this repo only ships the scripts.
# A local core checkout wins (COMMUNITY_SCRIPTS_CORE_DIR, else a sibling ../core),
# so a fork or branch of core can be tested without editing this file.
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")
# Copyright (c) 2021-2026 community-scripts ORG
# Author: MrNRod
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/micromdm/scep

APP="SCEP"
var_tags="${var_tags:-mdm;apple;pki;scep}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-256}"
var_disk="${var_disk:-2}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_arm64="${var_arm64:-no}" # no upstream linux-arm64 release asset (only linux-amd64 and 32-bit linux-arm)
var_unprivileged="${var_unprivileged:-1}"

# Common Name for the generated SCEP CA certificate. Exported so the install
# script (running inside the container) can see it.
export var_ca_cn="${var_ca_cn:-}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/scep ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  if check_for_gh_release "scep" "micromdm/scep"; then
    msg_info "Stopping Service"
    systemctl stop scep
    msg_ok "Stopped Service"

    CLEAN_INSTALL=1 fetch_and_deploy_gh_release "scep" "micromdm/scep" "prebuild" "latest" "/opt/scep" "scepserver-linux-amd64-*.zip"
    mv /opt/scep/scepserver-linux-amd64 /opt/scep/scepserver
    chmod +x /opt/scep/scepserver

    msg_info "Starting Service"
    systemctl start scep
    msg_ok "Started Service"
    msg_ok "Updated successfully!"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} SCEP endpoint (point NanoHUB/-ca and enrollment profiles here):${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8080/scep${CL}"
echo -e "${INFO}${YW} CA certificate (feed to NanoHUB's -ca / NANOHUB_CA):${CL} ${BGN}/opt/scep_data/depot/ca.pem${CL}"
echo -e "${INFO}${YW} CA key password and enrollment challenge password:${CL} ${BGN}/opt/scep_data/scep.env${CL}"
