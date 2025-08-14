#!/usr/bin/env bash
set -euo pipefail

I2P_HTTP_PROXY_PORT="${I2P_HTTP_PROXY_PORT:-4444}"
I2P_SOCKS_PORT="${I2P_SOCKS_PORT:-4447}"
FIREFOX_ARGS="${FIREFOX_ARGS:-}"
RESOLUTION="${RESOLUTION:-1280x800}"
VNC="${VNC:-0}"
VNC_PASSWORD="${VNC_PASSWORD:-}"
I2PD_ARGS="${I2PD_ARGS:-}"   # <-- add extra i2pd flags at runtime, e.g. "--ssu false --ntcp2 true"
NOVNC_WEB="/usr/share/novnc"

echo "[*] boot: stateless workspace in /tmp"

# Root vs non-root detection
is_root=0
if [ "$(id -u)" -eq 0 ]; then is_root=1; fi

# ---- Prepare homes (root vs non-root) ----
if [ "$is_root" -eq 1 ]; then
  APP_USER="app"; I2P_USER="i2p"
  APP_HOME="/tmp/home-app"; I2P_HOME="/tmp/home-i2p"; I2P_DATA="/tmp/i2p"
  rm -rf "$APP_HOME" "$I2P_HOME" "$I2P_DATA" 2>/dev/null || true
  mkdir -p "$APP_HOME/.config" "$APP_HOME/.mozilla" "$APP_HOME/.vnc" "$I2P_HOME" "$I2P_DATA"
  chown -R "${APP_USER}:${APP_USER}" "$APP_HOME"
  chown -R "${I2P_USER}:${I2P_USER}" "$I2P_HOME" "$I2P_DATA"
else
  APP_HOME="/tmp/home-$(id -u)"
  I2P_HOME="$APP_HOME"
  I2P_DATA="/tmp/i2p-$(id -u)"
  mkdir -p "$APP_HOME/.config" "$APP_HOME/.mozilla" "$APP_HOME/.vnc" "$I2P_DATA"
fi

# ---- Start i2pd (stateless) with logging ----
echo "[*] starting i2pd router (logging to /tmp/i2p/i2pd.log)"
I2P_LOG="/tmp/i2p/i2pd.log"
mkdir -p "$(dirname "$I2P_LOG")"

if [ "$is_root" -eq 1 ]; then
  [ -e /var/lib/i2pd ] && rm -rf /var/lib/i2pd
  ln -s "$I2P_DATA" /var/lib/i2pd
  su -s /bin/bash -c "HOME='$I2P_HOME' i2pd \
      --daemon \
      --datadir='$I2P_DATA' \
      --log=file --logfile='$I2P_LOG' \
      --http.address=127.0.0.1 --http.port=7070" "$I2P_USER"
else
  HOME="$I2P_HOME" i2pd \
      --daemon \
      --datadir="$I2P_DATA" \
      --log=file --logfile="$I2P_LOG" \
      --http.address=127.0.0.1 --http.port=7070
fi

echo "[*] i2pd router starting…"
echo "[*] NOTE: I2P needs time to bootstrap (~1–3 minutes on first run)."
echo "[*] You can watch progress at: http://127.0.0.1:7070/ (I2P Router Console)"


# Wait for HTTP proxy to be up
echo "[*] waiting for I2P HTTP proxy on 127.0.0.1:${I2P_HTTP_PROXY_PORT}"
for _ in {1..60}; do
  if nc -z 127.0.0.1 "${I2P_HTTP_PROXY_PORT}" 2>/dev/null; then break; fi
  sleep 1
done

# Wait for bootstrap: enough router infos in netDb + web console reachable
echo "[*] waiting for I2P bootstrap (netDb peers)"
for _ in {1..120}; do
  PEERS=0
  if [ -d "$I2P_DATA/netDb" ]; then
    # count files quickly; if netDb grows, we're bootstrapping
    PEERS=$(find "$I2P_DATA/netDb" -type f 2>/dev/null | wc -l || echo 0)
  fi
  if [ "$PEERS" -ge 20 ] && nc -z 127.0.0.1 7070 2>/dev/null; then
    echo "[*] bootstrap ok: ${PEERS} netDb entries"
    break
  fi
  sleep 1
done

# ---- Optional firewall (root only): lock Firefox to 127.0.0.1 ----
if [ "$is_root" -eq 1 ]; then
  echo "[*] applying egress firewall for Firefox user 'app' (localhost-only)"
  set +e
  iptables -F OUTPUT >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    iptables -A OUTPUT -m owner --uid-owner app -d 127.0.0.1 -j ACCEPT >/dev/null 2>&1
    iptables -A OUTPUT -m owner --uid-owner app -j REJECT >/dev/null 2>&1
    iptables -A OUTPUT -m owner --uid-owner i2p -j ACCEPT >/dev/null 2>&1
  else
    echo "[!] WARNING: iptables not available (add --cap-add=NET_ADMIN --cap-add=NET_RAW to enable)."
  fi
  set -e
else
  echo "[*] NOTE: non-root mode; firewall not applied."
fi

# ---- Mode select: VNC or Direct GUI ----
if [ "$VNC" = "1" ]; then
  # ========== VNC / noVNC MODE ==========
  echo "[*] VNC mode: starting vncserver (:1) and websockify/noVNC (:8080)"

  # xstartup keeps session alive
  XSTART="${APP_HOME}/.vnc/xstartup"
  cat > "$XSTART" <<'SH'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec fluxbox
SH
  chmod +x "$XSTART"

  # vnc config (xstartup controls the session)
  VNC_CFG="${APP_HOME}/.vnc/config"
  {
    echo "geometry=${RESOLUTION}"
    echo "localhost"
  } > "$VNC_CFG"

  # optional VNC password
  if [ -n "$VNC_PASSWORD" ]; then
    if [ "$is_root" -eq 1 ]; then
      su -s /bin/bash -c "HOME='${APP_HOME}' sh -c 'printf %s \"${VNC_PASSWORD}\" | vncpasswd -f > ${APP_HOME}/.vnc/passwd'" app
      chown app:app "${APP_HOME}/.vnc/passwd"
    else
      HOME="${APP_HOME}" sh -c "printf %s \"${VNC_PASSWORD}\" | vncpasswd -f > ${APP_HOME}/.vnc/passwd"
    fi
    chmod 600 "${APP_HOME}/.vnc/passwd"
    echo "securitytypes=vncauth" >> "$VNC_CFG"
    echo "passwdfile=${APP_HOME}/.vnc/passwd" >> "$VNC_CFG"
  else
    echo "securitytypes=none" >> "$VNC_CFG"
  fi

  # start vncserver (HOME must be APP_HOME)
  if [ "$is_root" -eq 1 ]; then
    chown -R app:app "${APP_HOME}/.vnc"
    su -s /bin/bash -c "HOME='${APP_HOME}' vncserver :1 -geometry ${RESOLUTION}" app >/tmp/vncserver.log 2>&1 || true
  else
    HOME="${APP_HOME}" vncserver :1 -geometry "${RESOLUTION}" >/tmp/vncserver.log 2>&1 || true
  fi

  # wait for :5901 to come up (use nc instead of ss/iproute2)
  for _ in {1..20}; do
    if nc -z 127.0.0.1 5901 2>/dev/null; then break; fi
    sleep 0.5
  done
  if ! nc -z 127.0.0.1 5901 2>/dev/null; then
    echo "[!] ERROR: vncserver failed to start (no listener on :5901). Dumping log:"
    cat /tmp/vncserver.log || true
    echo "[!] i2pd log tail:"
    tail -n 120 "$I2P_LOG" || true
    exit 1
  fi

  # start Firefox inside the VNC display
  if [ "$is_root" -eq 1 ]; then
    su -s /bin/bash -c "HOME='${APP_HOME}' DISPLAY=':1' XDG_RUNTIME_DIR=/tmp firefox-esr 'http://127.0.0.1:7070/' ${FIREFOX_ARGS}" app >/tmp/firefox.log 2>&1 &
  else
    DISPLAY=':1' XDG_RUNTIME_DIR=/tmp HOME="${APP_HOME}" firefox-esr 'http://127.0.0.1:7070/' ${FIREFOX_ARGS:-} >/tmp/firefox.log 2>&1 &
  fi

  # Make "/" redirect to working noVNC URL
  mkdir -p "${NOVNC_WEB}"
  cat > "${NOVNC_WEB}/index.html" <<'HTML'
<!doctype html><meta charset="utf-8"><title>noVNC</title>
<script>
  const h = location.hostname || 'localhost';
  const p = location.port || '8080';
  location.replace(`/vnc.html?host=${h}&port=${p}&autoconnect=1`);
</script>
HTML

  # Serve noVNC and proxy WS to 5901
  websockify --web "${NOVNC_WEB}" 0.0.0.0:8080 localhost:5901 >/tmp/novnc.log 2>&1 &

  echo "[*] ready. open:  http://localhost:8080"
  # Keep container alive with live logs
  tail -F /tmp/vncserver.log /tmp/firefox.log /tmp/novnc.log "$I2P_LOG"
  exit 0
else
  # ========== DIRECT GUI MODE (X11/Wayland) ==========
  if [ -z "${DISPLAY:-}" ] && [ -z "${MOZ_ENABLE_WAYLAND:-}" ]; then
    cat <<'EOM'
[!] ERROR: No GUI detected and VNC mode is off.
    - Set VNC=1 to use in-browser desktop on port 8080
      e.g. docker run --rm -p 8080:8080 -e VNC=1 i2p-live
    - Or set DISPLAY (X11) or MOZ_ENABLE_WAYLAND=1 (Wayland) and bind the socket.
EOM
    exit 1
  fi

  echo "[*] launching Firefox (direct GUI mode) → http://127.0.0.1:7070/"
  export HOME="$APP_HOME"
  export XDG_RUNTIME_DIR="/tmp"
  if [ "$is_root" -eq 1 ]; then
    exec su -s /bin/bash -c 'firefox-esr "http://127.0.0.1:7070/" $FIREFOX_ARGS' app
  else
    exec firefox-esr "http://127.0.0.1:7070/" ${FIREFOX_ARGS:-}
  fi
fi
