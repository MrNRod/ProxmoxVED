#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: MrNRod
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/munki/munki | https://github.com/munki/mwa2

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt install -y \
  git \
  nginx
msg_ok "Installed Dependencies"

# 3.11, not 3.12: mwa2's pkgsinfo_extras templatetag still imports distutils,
# which Python 3.12 dropped from the standard library (PEP 632).
PYTHON_VERSION="3.11" setup_uv

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
git -C /srv/munki_repo init -q
git config --global user.email "munki@$(hostname -f 2>/dev/null || hostname)"
git config --global user.name "MunkiWebAdmin2"
git -C /srv/munki_repo add -A
git -C /srv/munki_repo commit -q -m "Initial munki repo skeleton"
msg_ok "Created Munki Repository"

msg_info "Cloning MunkiWebAdmin2"
$STD git clone --branch py3 --depth 1 https://github.com/munki/mwa2.git /opt/munkiwebadmin
MWA2_COMMIT=$(git -C /opt/munkiwebadmin rev-parse --short HEAD)
echo "${MWA2_COMMIT}" >/opt/munkiwebadmin_version.txt
msg_ok "Cloned MunkiWebAdmin2 (${MWA2_COMMIT})"

msg_info "Installing Python Dependencies"
$STD uv venv /opt/munkiwebadmin/.venv
$STD uv pip install --python /opt/munkiwebadmin/.venv/bin/python -r /opt/munkiwebadmin/requirements.txt gunicorn
msg_ok "Installed Python Dependencies"

msg_info "Vendoring Linux makecatalogs (from munki/munki, Apache-2.0)"
# Munki 6+ ships makecatalogs as a macOS-only Swift binary, but the pure-Python
# implementation it replaced (munkilib/admin/makecatalogslib.py and its few
# dependencies) only ever used plistlib, so it still runs fine on Linux.
MUNKI_TAG=$(get_latest_github_release "munki/munki" false)
VENDOR_DIR="/opt/munkiwebadmin/makecatalogs_vendor"
mkdir -p "${VENDOR_DIR}/munkilib/admin" "${VENDOR_DIR}/munkilib/munkirepo"
for f in \
  "munkilib/__init__.py" \
  "munkilib/wrappers.py" \
  "munkilib/admin/__init__.py" \
  "munkilib/admin/common.py" \
  "munkilib/admin/makecatalogslib.py" \
  "munkilib/munkirepo/__init__.py" \
  "munkilib/munkirepo/_baseclasses.py" \
  "munkilib/munkirepo/FileRepo.py"; do
  curl -fsSL "https://raw.githubusercontent.com/munki/munki/${MUNKI_TAG}/code/client/${f}" -o "${VENDOR_DIR}/${f}"
done
cat <<'EOF' >"${VENDOR_DIR}/makecatalogs_linux.py"
#!/opt/munkiwebadmin/.venv/bin/python3
"""Linux driver for munki's vendored makecatalogslib.

MunkiWebAdmin2 shells out to MAKECATALOGS_PATH as: makecatalogs <repo_dir>
and streams its stdout, so this mirrors that CLI contract.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from munkilib.admin.common import AttributeDict
from munkilib.admin.makecatalogslib import makecatalogs
from munkilib.munkirepo import connect


def main():
    if len(sys.argv) < 2:
        print("Usage: makecatalogs_linux.py <repo_path>", file=sys.stderr)
        return 1
    repo_url = "file://" + os.path.abspath(sys.argv[1])
    repo = connect(repo_url, "FileRepo")
    options = AttributeDict(force=False, skip_payload_check=False)
    errors = makecatalogs(repo, options, output_fn=lambda msg: print(msg, flush=True))
    for error in errors:
        print(error, flush=True)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
EOF
chmod +x "${VENDOR_DIR}/makecatalogs_linux.py"
msg_ok "Vendored Linux makecatalogs (munki ${MUNKI_TAG})"

msg_info "Configuring MunkiWebAdmin2"
mkdir -p /opt/munkiwebadmin_data
SECRET_KEY=$(openssl rand -hex 50)
cp /opt/munkiwebadmin/munkiwebadmin/settings_template.py /opt/munkiwebadmin/munkiwebadmin/settings.py
sed -i \
  -e "s|^SECRET_KEY = .*|SECRET_KEY = '${SECRET_KEY}'|" \
  -e "s|^DEBUG = True|DEBUG = False|" \
  -e "s|^ALLOWED_HOSTS = \[\]|ALLOWED_HOSTS = ['*']|" \
  -e "s|^        'NAME': os.path.join(BASE_DIR, 'db.sqlite3'),|        'NAME': '/opt/munkiwebadmin_data/db.sqlite3',|" \
  -e "s|^MUNKI_REPO_DIR = .*|MUNKI_REPO_DIR = '/srv/munki_repo'|" \
  -e "s|^MAKECATALOGS_PATH = .*|MAKECATALOGS_PATH = '${VENDOR_DIR}/makecatalogs_linux.py'|" \
  -e "s|^#GIT_PATH = '/usr/bin/git'|GIT_PATH = '/usr/bin/git'|" \
  /opt/munkiwebadmin/munkiwebadmin/settings.py

cd /opt/munkiwebadmin
$STD /opt/munkiwebadmin/.venv/bin/python manage.py migrate --no-input
$STD /opt/munkiwebadmin/.venv/bin/python manage.py collectstatic --no-input

ADMIN_PASS=$(openssl rand -base64 18)
DJANGO_SUPERUSER_USERNAME=admin DJANGO_SUPERUSER_PASSWORD="${ADMIN_PASS}" DJANGO_SUPERUSER_EMAIL="admin@example.com" \
  $STD /opt/munkiwebadmin/.venv/bin/python manage.py createsuperuser --no-input
cat <<EOF >>/opt/munkiwebadmin/munkiwebadmin/settings.py

# Initial admin login created by the install script; change the password
# after first login. This file is gitignored by mwa2 and untouched by updates.
# Username: admin
# Password: ${ADMIN_PASS}
EOF
msg_ok "Configured MunkiWebAdmin2"

msg_info "Creating Service"
cat <<'EOF' >/etc/systemd/system/munkiwebadmin.service
[Unit]
Description=MunkiWebAdmin2 (gunicorn)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/munkiwebadmin
ExecStart=/opt/munkiwebadmin/.venv/bin/gunicorn --workers 2 --timeout 600 --bind 127.0.0.1:8090 munkiwebadmin.wsgi:application
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now munkiwebadmin
msg_ok "Created Service"

msg_info "Configuring Nginx"
cat <<'EOF' >/etc/nginx/sites-available/munki-repo.conf
server {
  listen 80 default_server;
  server_name _;

  location = / {
    default_type text/plain;
    return 200 "Munki repo. Point ManagedInstalls SoftwareRepoURL at http://<this-ip>/repo\nWeb admin: http://<this-ip>:8081/\n";
  }

  location = /repo {
    return 301 /repo/;
  }

  location /repo/ {
    alias /srv/munki_repo/;
  }
}

server {
  listen 8081 default_server;
  server_name _;

  client_max_body_size 200M;

  location /static/ {
    alias /opt/munkiwebadmin/munkiwebadmin/collected_static/;
  }

  location /media/ {
    alias /srv/munki_repo/icons/;
  }

  location / {
    proxy_pass http://127.0.0.1:8090;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    # mwa2's "Rebuild catalogs" view blocks synchronously in-request until
    # makecatalogs exits, with no streaming; nginx's 60s default read timeout
    # would otherwise cut the connection mid-rebuild (matches gunicorn's own
    # --timeout 600 in munkiwebadmin.service).
    proxy_connect_timeout 300s;
    proxy_send_timeout 600s;
    proxy_read_timeout 600s;
  }
}
EOF
ln -sf /etc/nginx/sites-available/munki-repo.conf /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
$STD nginx -t
systemctl enable -q --now nginx
systemctl reload nginx
msg_ok "Configured Nginx"

motd_ssh
customize
cleanup_lxc
