#!/usr/bin/env bash
_CS_DEFAULT_URL="https://raw.githubusercontent.com/community-scripts/DevScripts/main"
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")
# Copyright (c) 2021-2026 community-scripts ORG
# Author: MrNRod
# License: MIT | https://github.com/community-scripts/DevScripts/raw/main/LICENSE
# Source: https://github.com/Sonicx161/AIOManager

APP="AIOManager"
var_tags="${var_tags:-media;streaming;stremio}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_arm64="${var_arm64:-yes}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/aiomanager ]]; then
    msg_error "No AIOManager Installation Found!"
    exit
  fi

  if check_for_gh_release "aiomanager" "Sonicx161/AIOManager" "" "" "v"; then
    msg_info "Stopping AIOManager"
    systemctl stop aiomanager
    msg_ok "Stopped AIOManager"

    CLEAN_INSTALL=1 fetch_and_deploy_gh_release "aiomanager" "Sonicx161/AIOManager" "tarball" "latest" "" "" "v"

    NODE_VERSION="22" setup_nodejs

    msg_info "Building AIOManager"
    cd /opt/aiomanager
    $STD npm ci
    $STD npm --prefix server ci --omit=dev
    $STD npm run build
    msg_ok "Built AIOManager"

    msg_info "Starting AIOManager"
    systemctl start aiomanager
    msg_ok "Started AIOManager"
    msg_ok "Updated AIOManager successfully!"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}AIOManager setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access AIOManager using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:1610${CL}"
echo -e "${INFO}${YW} Use an HTTPS reverse proxy for AIOManager browser encryption.${CL}"
