#!/usr/bin/env bash
# Engine comes from community-scripts/core; this repo only ships the scripts.
# A local core checkout wins (COMMUNITY_SCRIPTS_CORE_DIR, else a sibling ../core),
# so a fork or branch of core can be tested without editing this file.
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")
# Copyright (c) 2021-2026 community-scripts ORG
# Author: MrNRod
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/micromdm/nanohub | Docs: https://github.com/micromdm/nanohub/blob/main/docs/operations-guide.md

APP="NanoHUB"
var_tags="${var_tags:-mdm;apple;nanomdm}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-512}"
var_disk="${var_disk:-2}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
#var_arm64="${var_arm64:-no}" # unset = ask the user; set yes/no only when verified
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/nanohub ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  if check_for_gh_release "nanohub" "micromdm/nanohub"; then
    msg_info "Stopping Service"
    systemctl stop nanohub
    msg_ok "Stopped Service"

    ARCH=$(arch_resolve amd64 arm64)
    CLEAN_INSTALL=1 fetch_and_deploy_gh_release "nanohub" "micromdm/nanohub" "prebuild" "latest" "/opt/nanohub" "nanohub-linux-${ARCH}-*.zip"
    mv "/opt/nanohub/nanohub-linux-${ARCH}" /opt/nanohub/nanohub
    chmod +x /opt/nanohub/nanohub

    msg_info "Starting Service"
    systemctl start nanohub
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
echo -e "${INFO}${YW} NanoHUB server (MDM/API endpoints):${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:9004/${CL}"
echo -e "${INFO}${YW} API Basic Auth username:${CL} ${BGN}nanohub${CL}"
echo -e "${INFO}${YW} API key and storage config:${CL} ${BGN}/opt/nanohub_data/nanohub.env${CL}"
