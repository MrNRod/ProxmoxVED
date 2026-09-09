#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: MrNRod
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/micromdm/scep

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

fetch_and_deploy_gh_release "scep" "micromdm/scep" "prebuild" "latest" "/opt/scep" "scepserver-linux-amd64-*.zip"

msg_info "Setting up SCEP Server"
mv /opt/scep/scepserver-linux-amd64 /opt/scep/scepserver
chmod +x /opt/scep/scepserver
mkdir -p /opt/scep_data

if [[ -z "${var_ca_cn:-}" ]]; then
  read -rp "CA Common Name [MICROMDM SCEP CA]: " var_ca_cn
fi
var_ca_cn="${var_ca_cn:-MICROMDM SCEP CA}"

CA_PASS=$(openssl rand -hex 24)
CHALLENGE_PASS=$(openssl rand -hex 16)

$STD /opt/scep/scepserver ca -init \
  -depot /opt/scep_data/depot \
  -key-password "${CA_PASS}" \
  -common_name "${var_ca_cn}"

cat <<EOF >/opt/scep_data/scep.env
SCEP_HTTP_LISTEN_PORT=8080
SCEP_FILE_DEPOT=/opt/scep_data/depot
SCEP_CA_PASS=${CA_PASS}
SCEP_CHALLENGE_PASSWORD=${CHALLENGE_PASS}
SCEP_CERT_VALID=365
SCEP_CERT_RENEW=14
EOF
msg_ok "Set up SCEP Server"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/scep.service
[Unit]
Description=SCEP Server (micromdm/scep)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/scep
EnvironmentFile=/opt/scep_data/scep.env
ExecStart=/opt/scep/scepserver
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now scep
msg_ok "Created Service"

motd_ssh
customize
cleanup_lxc
