#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: MrNRod
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/micromdm/squirrel

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt install -y git
msg_ok "Installed Dependencies"

setup_go

msg_info "Creating Munki Repository"
mkdir -p /srv/munki_repo/{pkgs,pkgsinfo,catalogs,manifests,icons,client_resources}
cat <<'EOF' >/srv/munki_repo/manifests/site_default
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>catalogs</key>
	<array>
		<string>testing</string>
		<string>production</string>
	</array>
	<key>included_manifests</key>
	<array/>
	<key>managed_installs</key>
	<array/>
	<key>managed_uninstalls</key>
	<array/>
	<key>optional_installs</key>
	<array/>
</dict>
</plist>
EOF
msg_ok "Created Munki Repository"

msg_info "Cloning Squirrel"
# The last tagged release (1.0.2, 2017) predates go.mod and ships a different
# CLI layout, so this builds off the master branch instead (last commit 2021,
# but it's the only version with the modern cmd/squirrel flag set + go modules).
$STD git clone --branch master --depth 1 https://github.com/micromdm/squirrel.git /opt/squirrel
SQUIRREL_COMMIT=$(git -C /opt/squirrel rev-parse --short HEAD)
echo "${SQUIRREL_COMMIT}" >/opt/squirrel_version.txt
msg_ok "Cloned Squirrel (${SQUIRREL_COMMIT})"

msg_info "Building Squirrel"
cd /opt/squirrel
export CGO_ENABLED=0
$STD go build -o /opt/squirrel/squirrel ./cmd/squirrel
msg_ok "Built Squirrel"

msg_info "Generating SSL Certificate"
mkdir -p /etc/squirrel/certs
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout /etc/squirrel/certs/key.pem \
  -out /etc/squirrel/certs/cert.pem \
  -subj "/C=US/ST=State/L=City/O=Squirrel/CN=${LOCAL_IP}" \
  -addext "subjectAltName=IP:${LOCAL_IP},DNS:localhost,IP:127.0.0.1" \
  2>/dev/null
chmod 600 /etc/squirrel/certs/key.pem
chmod 644 /etc/squirrel/certs/cert.pem
msg_ok "Generated SSL Certificate"

msg_info "Configuring Squirrel"
cat <<EOF >/etc/squirrel/squirrel.env
SQUIRREL_BASIC_AUTH=$(openssl rand -base64 18)
EOF
chmod 600 /etc/squirrel/squirrel.env
msg_ok "Configured Squirrel"

msg_info "Creating Service"
cat <<'EOF' >/etc/systemd/system/squirrel.service
[Unit]
Description=Squirrel Munki Server
After=network.target

[Service]
Type=simple
User=root
EnvironmentFile=/etc/squirrel/squirrel.env
WorkingDirectory=/opt/squirrel
ExecStart=/opt/squirrel/squirrel serve -repo=/srv/munki_repo -tls=true -tls-cert=/etc/squirrel/certs/cert.pem -tls-key=/etc/squirrel/certs/key.pem
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now squirrel
msg_ok "Created Service"

motd_ssh
customize
cleanup_lxc
