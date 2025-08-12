#!/usr/bin/env bash
set -euo pipefail

RESOLUTION="${RESOLUTION:-1280x800}"
I2P_HTTP_PROXY_PORT="${I2P_HTTP_PROXY_PORT:-4444}"
I2P_SOCKS_PORT="${I2P_SOCKS_PORT:-4447}"
DISPLAY="${DISPLAY:-:0}"
NOVNC_DIR="${NOVNC_DIR:-/usr/share/novnc}"
VNC_PASSWORD="${VNC_PASSWORD:-}"

echo "[*] boot: stateless workspace in /tmp"
rm -rf /tmp/home-app /tmp/home-i2p /tmp/i2p /tmp/.X* || true
mkdir -p /tmp/home-app /tmp/home-app/.vnc /tmp/home-app/.config /tmp/home-app/.mozilla \
         /tmp/home-i2p /tmp/i2p
chown -R app:app /tmp/home-app
chown -R i2p:i2p /tmp/home-i2p /tmp/i2p

cat > /tmp/home-app/.vnc/xstartup <<'XEOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XDG_RUNTIME_DIR=/tmp/xdg-app
mkdir -p "$XDG_RUNTIME_DIR"
fluxbox &
while true; do
  firefox-esr http://127.0.0.1:7657/ || true
  sleep 3
done
XEOF
chmod +x /tmp/home-app/.vnc/xstartup
chown app:app /tmp/home-app/.vnc/xstartup

if [ -n "$VNC_PASSWORD" ]; then
  echo "$VNC_PASSWORD" | su - app -c "vncpasswd -f > /tmp/home-app/.vnc/passwd"
  chmod 600 /tmp/home-app/.vnc/passwd
  chown app:app /tmp/home-app/.vnc/passwd
  VNC_SEC="--SecurityTypes VncAuth"
else
  VNC_SEC="--SecurityTypes None"
fi

echo "[*] starting i2p router"
export HOME=/tmp/home-i2p
chown -R i2p:i2p /tmp/home-i2p /tmp/i2p
if [ -d /var/lib/i2p ]; then
  rm -rf /var/lib/i2p
  ln -s /tmp/i2p /var/lib/i2p
fi
if [ ! -f /tmp/i2p/router.config ]; then
cat > /tmp/i2p/router.config <<RCFG
# minimal router config; rest is auto-generated
RCFG
fi
su -s /bin/bash -c "HOME=/tmp/home-i2p i2prouter start" i2p

echo "[*] waiting for I2P HTTP proxy on 127.0.0.1:${I2P_HTTP_PROXY_PORT}"
for i in {1..60}; do
  if nc -z 127.0.0.1 "${I2P_HTTP_PROXY_PORT}" 2>/dev/null; then
    break
  fi
  sleep 1
done

echo "[*] applying egress firewall for user 'app'"
iptables -F OUTPUT || true
iptables -A OUTPUT -m owner --uid-owner app -d 127.0.0.1 -j ACCEPT
iptables -A OUTPUT -m owner --uid-owner app -j REJECT
iptables -A OUTPUT -m owner --uid-owner i2p -j ACCEPT || true

echo "[*] starting TigerVNC on ${DISPLAY} @ ${RESOLUTION}"
su - app -c "vncserver ${DISPLAY} -localhost yes ${VNC_SEC} -geometry ${RESOLUTION}"

echo "[*] starting noVNC on :8080 → forwarding to VNC :5900"
websockify --web "${NOVNC_DIR}" 0.0.0.0:8080 localhost:5900 &

echo "[*] ready. open:  http://localhost:8080"
tail -F /tmp/home-app/.vnc/*:*.log
