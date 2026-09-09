#!/usr/bin/env bash
# Engine comes from community-scripts/core; this repo only ships the scripts.
# A local core checkout wins (COMMUNITY_SCRIPTS_CORE_DIR, else a sibling ../core),
# so a fork or branch of core can be tested without editing this file.
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")
# Copyright (c) 2021-2026 community-scripts ORG
# Author: MrNRod
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/micromdm/squirrel | Docs: https://github.com/micromdm/squirrel#readme

APP="Squirrel"
var_tags="${var_tags:-munki;mdm;software}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-1024}"
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

  if [[ ! -d /opt/squirrel ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_info "Checking for Squirrel Updates"
  LATEST_COMMIT=$(git ls-remote https://github.com/micromdm/squirrel.git refs/heads/master | awk '{print $1}')
  CURRENT_COMMIT=$(cat /opt/squirrel_version.txt 2>/dev/null || echo "")
  if [[ -z "${LATEST_COMMIT}" ]]; then
    msg_error "Could not resolve the latest Squirrel commit via git ls-remote"
    exit 1
  fi
  if [[ "${LATEST_COMMIT}" == "${CURRENT_COMMIT}"* ]]; then
    msg_ok "No update required. ${APP} is already up to date"
    exit 0
  fi
  msg_ok "Update available: ${CURRENT_COMMIT} -> ${LATEST_COMMIT:0:8}"

  msg_info "Stopping Service"
  systemctl stop squirrel
  msg_ok "Stopped Service"

  setup_go

  msg_info "Updating Squirrel"
  cd /opt/squirrel
  $STD git fetch --depth 1 origin master
  $STD git reset --hard origin/master
  msg_ok "Updated Squirrel"

  msg_info "Building Squirrel"
  export CGO_ENABLED=0
  $STD go build -o /opt/squirrel/squirrel ./cmd/squirrel
  msg_ok "Built Squirrel"

  git -C /opt/squirrel rev-parse --short HEAD >/opt/squirrel_version.txt

  msg_info "Starting Service"
  systemctl start squirrel
  msg_ok "Started Service"
  msg_ok "Updated Successfully!"
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Munki repo (client SoftwareRepoURL):${CL}"
echo -e "${TAB}${GATEWAY}${BGN}https://${IP}/repo${CL}"
echo -e "${INFO}${YW} Uses a self-signed certificate - accept the browser/client warning once.${CL}"
echo -e "${INFO}${YW} Basic-auth username is 'squirrel'; the password is in:${CL}"
echo -e "${TAB}/etc/squirrel/squirrel.env"
echo -e "${INFO}${YW} The client Authorization header is also printed on every service start:${CL}"
echo -e "${TAB}journalctl -u squirrel -n 20"
