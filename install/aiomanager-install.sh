#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: MrNRod
# License: MIT | https://github.com/community-scripts/DevScripts/raw/main/LICENSE
# Source: https://github.com/Sonicx161/AIOManager

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing AIOManager Dependencies"
$STD apt install -y \
  build-essential \
  python3
msg_ok "Installed AIOManager Dependencies"

NODE_VERSION="22" setup_nodejs

fetch_and_deploy_gh_release "aiomanager" "Sonicx161/AIOManager" "tarball" "latest" "" "" "v"

msg_info "Configuring AIOManager"
mkdir -p /opt/aiomanager_data
chmod 700 /opt/aiomanager_data
cp /opt/aiomanager/.env.example /opt/aiomanager_data/.env
sed -i \
  -e "s|^#DATA_DIR=.*|DATA_DIR=/opt/aiomanager_data|" \
  -e "s|^#CORS_ORIGINS=.*|CORS_ORIGINS=http://${LOCAL_IP}:1610|" \
  /opt/aiomanager_data/.env
chmod 600 /opt/aiomanager_data/.env
msg_ok "Configured AIOManager"

msg_info "Building AIOManager"
cd /opt/aiomanager
$STD npm ci
$STD npm --prefix server ci --omit=dev --ignore-scripts=false --dangerously-allow-all-scripts
$STD node --input-type=module -e 'import Database from "./server/node_modules/better-sqlite3/lib/index.js"; const db = new Database(":memory:"); db.prepare("SELECT 1").get(); db.close();'
$STD npm run build
msg_ok "Built AIOManager"

msg_info "Creating AIOManager Service"
cat <<EOF >/etc/systemd/system/aiomanager.service
[Unit]
Description=AIOManager
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/aiomanager
EnvironmentFile=/opt/aiomanager_data/.env
ExecStart=/usr/bin/node /opt/aiomanager/server/index.js
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now aiomanager
msg_ok "Created AIOManager Service"

motd_ssh
customize
cleanup_lxc
