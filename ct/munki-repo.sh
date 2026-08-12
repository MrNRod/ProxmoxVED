#!/usr/bin/env bash
# Engine comes from community-scripts/core; this repo only ships the scripts.
# A local core checkout wins (COMMUNITY_SCRIPTS_CORE_DIR, else a sibling ../core),
# so a fork or branch of core can be tested without editing this file.
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")
# Copyright (c) 2021-2026 community-scripts ORG
# Author: MrNRod
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/munki/munki | Docs: https://github.com/munki/munki/wiki

APP="Munki-Repo"
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

  if [[ ! -d /opt/munkiwebadmin ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_info "Checking for MunkiWebAdmin2 Updates"
  LATEST_COMMIT=$(git ls-remote https://github.com/munki/mwa2.git refs/heads/py3 | awk '{print $1}')
  CURRENT_COMMIT=$(cat /opt/munkiwebadmin_version.txt 2>/dev/null || echo "")
  if [[ -z "${LATEST_COMMIT}" ]]; then
    msg_error "Could not resolve the latest MunkiWebAdmin2 commit via git ls-remote"
    exit 1
  fi
  if [[ "${LATEST_COMMIT}" == "${CURRENT_COMMIT}" ]]; then
    msg_ok "No update required. ${APP} is already up to date"
    exit 0
  fi
  msg_ok "Update available: ${CURRENT_COMMIT:0:8} -> ${LATEST_COMMIT:0:8}"

  msg_info "Stopping Service"
  systemctl stop munkiwebadmin
  msg_ok "Stopped Service"

  msg_info "Updating MunkiWebAdmin2"
  # settings.py is gitignored by mwa2, so `git reset --hard` leaves it in
  # place; the sqlite database lives outside the repo in /opt/munkiwebadmin_data.
  cd /opt/munkiwebadmin
  $STD git fetch --depth 1 origin py3
  $STD git reset --hard origin/py3
  msg_ok "Updated MunkiWebAdmin2"

  msg_info "Updating Python Dependencies"
  $STD uv pip install --python /opt/munkiwebadmin/.venv/bin/python -r /opt/munkiwebadmin/requirements.txt gunicorn
  msg_ok "Updated Python Dependencies"

  msg_info "Applying Migrations"
  $STD /opt/munkiwebadmin/.venv/bin/python manage.py migrate --no-input
  $STD /opt/munkiwebadmin/.venv/bin/python manage.py collectstatic --no-input
  msg_ok "Applied Migrations"

  echo "${LATEST_COMMIT}" >/opt/munkiwebadmin_version.txt

  msg_info "Starting Service"
  systemctl start munkiwebadmin
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
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}/repo${CL}"
echo -e "${INFO}${YW} MunkiWebAdmin2 (manifests, pkginfo, catalogs):${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8081/${CL}"
echo -e "${INFO}${YW} Admin login: see the comment at the end of${CL}"
echo -e "${TAB}/opt/munkiwebadmin/munkiwebadmin/settings.py${CL}"
