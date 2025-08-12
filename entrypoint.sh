#!/usr/bin/env bash
set -euo pipefail

I2P_HTTP_PROXY_PORT="${I2P_HTTP_PROXY_PORT:-4444}"
I2P_SOCKS_PORT="${I2P_SOCKS_PORT:-4447}"
FIREFOX_ARGS="${FIREFOX_ARGS:-}"

echo "[*] boot: stateless workspace in /tmp"

# --- require GUI env (X11 or Wayland) ---
if [ -z "${DISPLAY:-}" ] && [ -z "${MOZ_ENABLE_WAYLAND:-}" ]; then
  echo "[!] ERROR: No GUI environment detected."
  echo "    Set DISPLAY for X11, or MOZ_ENABLE_WAYLAND=1 for Wayland. Exiting."
  exit 1
fi

is_root=0
if [ "$(id -u)" -eq 0 ]; then is_root=1; fi

if [ "$is_root" -eq 1 ]; then
  # ---------- ROOT MODE ----------
  APP_USER="app"
  I2P_USER="i2p"
  APP_HOME="/tmp/home-app"
  I2P_HOME="/tmp/home-i2p"
  I2P_DATA="/tmp/i2p"

  rm -rf "$APP_HOME" "$I2P_HOME" "$I2P_DATA" 2>/dev/null || true
  mkdir -p "$APP_HOME/.config" "$APP_HOME/.mozilla" "$I2P_HOME" "$I2P_DATA"
  chown -R "${APP_USER}:${APP_USER}" "$APP_HOME"
  chown -R "${I2P_USER}:${I2P_USER}" "$I2P_HOME" "$I2P_DATA"

  echo "[*] starting i2pd router (root mode)"
  # Point distro data dir to /tmp (stateless)
  [ -e /var/lib/i2pd ] && rm -rf /var/lib/i2pd
  ln -s "$I2P_DATA" /var/lib/i2pd

  su -s /bin/bash -c "HOME=$I2P_HOME i2pd --daemon" "$I2P_USER"

  echo "[*] waiting for I2P HTTP proxy on 127.0.0.1:${I2P_HTTP_PROXY_PORT}"
  for _ in {1..60}; do
    if nc -z 127.0.0.1 "${I2P_HTTP_PROXY_PORT}" 2>/dev/null; then break; fi
    sleep 1
  done

  echo "[*] applying egress firewall for user '${APP_USER}' (localhost-only)"
  set +e
  iptables -F OUTPUT >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    iptables -A OUTPUT -m owner --uid-owner "${APP_USER}" -d 127.0.0.1 -j ACCEPT >/dev/null 2>&1
    iptables -A OUTPUT -m owner --uid-owner "${APP_USER}" -j REJECT >/dev/null 2>&1
    iptables -A OUTPUT -m owner --uid-owner "${I2P_USER}" -j ACCEPT >/dev/null 2>&1
  else
    cat <<'WARN'

========================================================================
WARNING: Could not apply container firewall (iptables).
Run with:  --cap-add=NET_ADMIN --cap-add=NET_RAW
========================================================================
WARN
  fi
  set -e

  echo "[*] launching Firefox (i2pd console http://127.0.0.1:7070/)"
  export HOME="$APP_HOME"
  export XDG_RUNTIME_DIR="/tmp"
  exec su -s /bin/bash -c 'firefox-esr "http://127.0.0.1:7070/" $FIREFOX_ARGS' "$APP_USER"

else
  # ---------- NON-ROOT MODE (e.g., --user UID:GID) ----------
  UID_HOME="/tmp/home-$(id -u)"
  UID_I2P="/tmp/i2p-$(id -u)"

  mkdir -p "$UID_HOME/.config" "$UID_HOME/.mozilla" "$UID_I2P"

  echo "[*] starting i2pd router (non-root mode, datadir=$UID_I2P)"
  # Do NOT touch /var/lib/i2pd here
  HOME="$UID_HOME" i2pd --daemon --datadir="$UID_I2P"

  echo "[*] waiting for I2P HTTP proxy on 127.0.0.1:${I2P_HTTP_PROXY_PORT}"
  for _ in {1..60}; do
    if nc -z 127.0.0.1 "${I2P_HTTP_PROXY_PORT}" 2>/dev/null; then break; fi
    sleep 1
  done

  echo "[*] NOTE: running as non-root; firewall not applied."
  echo "          (use root + --cap-add=NET_ADMIN --cap-add=NET_RAW to enable)"

  echo "[*] launching Firefox (i2pd console http://127.0.0.1:7070/)"
  export HOME="$UID_HOME"
  export XDG_RUNTIME_DIR="/tmp"
  exec firefox-esr "http://127.0.0.1:7070/" ${FIREFOX_ARGS:-}
fi
