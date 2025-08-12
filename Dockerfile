FROM debian:stable-slim

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    RESOLUTION=1280x800 \
    VNC_PASSWORD= \
    DISPLAY=:0 \
    I2P_HTTP_PROXY_PORT=4444 \
    I2P_SOCKS_PORT=4447

# Basic deps + GUI stack + Firefox + I2P + noVNC + VNC
RUN apt-get update && apt-get install -y --no-install-recommends \
    locales ca-certificates wget curl procps tini iptables \
    xauth x11-xserver-utils dbus-x11 \
    fluxbox firefox-esr \
    tigervnc-standalone-server \
    novnc websockify \
    fonts-dejavu-core \
    i2p i2p-router && \
    sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && locale-gen && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Users
RUN useradd -m -s /bin/bash i2p && \
    useradd -m -s /bin/bash app

# Firefox enterprise policies
ADD firefox/policies.json /usr/lib/firefox-esr/distribution/policies.json
ADD firefox/user.js       /etc/firefox-esr/user.js

# Entrypoint
ADD entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENV NOVNC_DIR=/usr/share/novnc

VOLUME ["/tmp"]

EXPOSE 8080
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
