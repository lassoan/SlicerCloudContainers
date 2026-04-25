FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=all \
    DESKTOP_USER=desktop \
    DESKTOP_UID=1000 \
    DESKTOP_GID=1000 \
    DESKTOP_HOME=/home/desktop \
    VNC_PORT=5900 \
    NOVNC_PORT=6080 \
    SYNCTHING_GUI_PORT=8384 \
    SYNCTHING_HOME=/config/syncthing \
    SYNCTHING_DATA_DIR=/workspace

RUN apt-get update && apt-get install -y --no-install-recommends \
    ark \
    autocutsel \
    breeze \
    openbox \
    curl \
    openssh-server \
    python3-debugpy \
    dbus-x11 \
    dolphin \
    fonts-dejavu-core \
    fonts-hack \
    fonts-noto-core \
    fonts-noto-color-emoji \
    kde-plasma-desktop \
    konsole \
    net-tools \
    novnc \
    plasma-workspace-wallpapers \
    procps \
    python-is-python3 \
    python3.12 \
    python3.12-dev \
    python3.12-tk \
    python3.12-venv \
    python3-pip \
    kde-spectacle \
    supervisor \
    sudo \
    syncthing \
    thonny \
    libegl1 \
    libgles2 \
    libglu1-mesa \
    libxv1 \
    mesa-utils \
    vulkan-tools \
    websockify \
    x11-utils \
    x11vnc \
    xterm \
    xmlstarlet \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
    && apt-get install -y --no-install-recommends gnupg xdg-utils \
    && curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg \
         | gpg --dearmor -o /etc/apt/keyrings/packages.mozilla.org.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.gpg] https://packages.mozilla.org/apt mozilla main" \
         > /etc/apt/sources.list.d/mozilla.list \
    && printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' \
         > /etc/apt/preferences.d/mozilla \
    && apt-get update \
    && apt-get install -y --no-install-recommends firefox \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
      -o /usr/local/bin/cloudflared \
    && chmod +x /usr/local/bin/cloudflared

RUN curl -fsSL https://github.com/VirtualGL/virtualgl/releases/download/3.1.1/virtualgl_3.1.1_amd64.deb \
            -o /tmp/virtualgl.deb \
        && dpkg -i /tmp/virtualgl.deb \
        && rm -f /tmp/virtualgl.deb

RUN existing_group_name="$(getent group ${DESKTOP_GID} | cut -d: -f1 || true)" \
    && if [ -n "${existing_group_name}" ]; then primary_group="${existing_group_name}"; else groupadd --gid ${DESKTOP_GID} ${DESKTOP_USER}; primary_group="${DESKTOP_USER}"; fi \
    && existing_user_name="$(getent passwd ${DESKTOP_UID} | cut -d: -f1 || true)" \
    && if id -u ${DESKTOP_USER} >/dev/null 2>&1; then true; elif [ -n "${existing_user_name}" ]; then useradd --gid "${primary_group}" --create-home --shell /bin/bash ${DESKTOP_USER}; else useradd --uid ${DESKTOP_UID} --gid "${primary_group}" --create-home --shell /bin/bash ${DESKTOP_USER}; fi \
    && usermod -aG sudo ${DESKTOP_USER} \
    && echo "${DESKTOP_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${DESKTOP_USER} \
    && chmod 0440 /etc/sudoers.d/${DESKTOP_USER} \
    && mkdir -p /config/syncthing /workspace /storage /opt/container \
    && primary_group_name="$(id -gn ${DESKTOP_USER})" \
    && chown -R ${DESKTOP_USER}:${primary_group_name} /config /workspace /storage ${DESKTOP_HOME}

COPY docker/entrypoint.sh /opt/container/entrypoint.sh
COPY docker/plasma-session.sh /opt/container/plasma-session.sh
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY docker/kde-defaults/ /opt/container/kde-defaults/

RUN chmod +x /opt/container/entrypoint.sh /opt/container/plasma-session.sh

EXPOSE 6080 8384 22000/tcp 22000/udp 21027/udp

VOLUME ["/config/syncthing", "/workspace", "/storage"]

ENTRYPOINT ["/opt/container/entrypoint.sh"]
