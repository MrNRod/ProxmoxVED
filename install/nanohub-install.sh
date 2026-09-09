#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: MrNRod
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/micromdm/nanohub | Docs: https://github.com/micromdm/nanohub/blob/main/docs/operations-guide.md

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

ARCH=$(arch_resolve amd64 arm64)
fetch_and_deploy_gh_release "nanohub" "micromdm/nanohub" "prebuild" "latest" "/opt/nanohub" "nanohub-linux-${ARCH}-*.zip"

msg_info "Setting up NanoHUB"
mv "/opt/nanohub/nanohub-linux-${ARCH}" /opt/nanohub/nanohub
chmod +x /opt/nanohub/nanohub
mkdir -p /opt/nanohub_data/db

API_KEY=$(openssl rand -hex 24)
cat <<EOF >/opt/nanohub_data/nanohub.env
NANOHUB_LISTEN=:9004
NANOHUB_API_KEY=${API_KEY}
NANOHUB_STORAGE=file
NANOHUB_STORAGE_DSN=/opt/nanohub_data/db
EOF
msg_ok "Set up NanoHUB"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/nanohub.service
[Unit]
Description=NanoHUB (unified NanoMDM/NanoCMD/KMFDDM server)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/nanohub
EnvironmentFile=/opt/nanohub_data/nanohub.env
ExecStart=/opt/nanohub/nanohub
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now nanohub
msg_ok "Created Service"

motd_ssh
customize
cleanup_lxc
