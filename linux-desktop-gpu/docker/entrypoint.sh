#!/usr/bin/env bash
set -euo pipefail

export HOME="${DESKTOP_HOME}"
export DESKTOP_UID_RUNTIME="$(id -u "${DESKTOP_USER}")"
export DESKTOP_GID_RUNTIME="$(id -gn "${DESKTOP_USER}")"
export XDG_RUNTIME_DIR="/run/user/${DESKTOP_UID_RUNTIME}"

mkdir -p "${SYNCTHING_HOME}" "${SYNCTHING_DATA_DIR}" "${XDG_RUNTIME_DIR}" /var/log/supervisor /run

# Only chown small runtime dirs on every boot — never recurse into data volumes
chown "${DESKTOP_USER}:${DESKTOP_GID_RUNTIME}" "${SYNCTHING_HOME}" "${SYNCTHING_DATA_DIR}" "${XDG_RUNTIME_DIR}"
# Fix storage mount-point ownership after bind mount overrides the Dockerfile chown
chown "${DESKTOP_USER}:${DESKTOP_GID_RUNTIME}" /storage 2>/dev/null || true
chmod 700 "${XDG_RUNTIME_DIR}"

# Apply KDE defaults and fix home ownership on first boot only
KDE_STAMP="${DESKTOP_HOME}/.config/.kde-defaults-applied"
if [[ ! -f "${KDE_STAMP}" ]]; then
  cp -rn /opt/container/kde-defaults/. "${DESKTOP_HOME}/"
  # Mark desktop shortcuts as trusted so KDE allows launching them
  chmod +x "${DESKTOP_HOME}/Desktop/"*.desktop 2>/dev/null || true
  chown -R "${DESKTOP_USER}:${DESKTOP_GID_RUNTIME}" "${DESKTOP_HOME}"
  touch "${KDE_STAMP}"
fi

ssh-keygen -A
mkdir -p /run/sshd
sed -i 's/^#*PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#*PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
echo "${DESKTOP_USER}:${SSH_PASSWORD:-${VNC_PASSWORD:-sQof/52335}}" | chpasswd

if [[ -z "${VNC_PASSWORD:-}" ]]; then
  export VNC_PASSWORD="sQof/52335"
fi

x11vnc -storepasswd "${VNC_PASSWORD}" /run/x11vnc.pass >/dev/null
chmod 600 /run/x11vnc.pass

if [[ ! -f "${SYNCTHING_HOME}/config.xml" ]]; then
  su -s /bin/bash -c "HOME='${DESKTOP_HOME}' syncthing generate --home='${SYNCTHING_HOME}'" "${DESKTOP_USER}"
fi

xmlstarlet ed -L \
  -u '/configuration/gui/address' -v "0.0.0.0:${SYNCTHING_GUI_PORT}" \
  -u '/configuration/folder[@id="default"]/@path' -v "${SYNCTHING_DATA_DIR}" \
  "${SYNCTHING_HOME}/config.xml"

# Add cloudflared VNC tunnel to supervisor only when a token is provided
if [[ -n "${CF_VNC_TUNNEL_TOKEN:-}" ]]; then
  cat >> /etc/supervisor/conf.d/supervisord.conf <<EOF

[program:cloudflared-vnc]
command=/usr/local/bin/cloudflared tunnel run --token ${CF_VNC_TUNNEL_TOKEN}
priority=60
autorestart=true
startsecs=5
stdout_logfile=/var/log/supervisor/cloudflared-vnc.log
stderr_logfile=/var/log/supervisor/cloudflared-vnc.err
EOF
fi

# Add cloudflared SSH tunnel to supervisor only when a token is provided
if [[ -n "${CF_SSH_TUNNEL_TOKEN:-}" ]]; then
  cat >> /etc/supervisor/conf.d/supervisord.conf <<EOF

[program:cloudflared-ssh]
command=/usr/local/bin/cloudflared tunnel run --token ${CF_SSH_TUNNEL_TOKEN}
priority=60
autorestart=true
startsecs=5
stdout_logfile=/var/log/supervisor/cloudflared-ssh.log
stderr_logfile=/var/log/supervisor/cloudflared-ssh.err
EOF
fi

exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
