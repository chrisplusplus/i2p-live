# i2p-live
⚡ One-command, stateless I2P browser environment in Docker — **no VNC**.  
Firefox launches directly on your host display (X11 or Wayland).

---

## Overview
`i2p-live` runs the **i2pd** router and a proxy-locked **Firefox ESR**.  
It is **stateless**: all data lives in `/tmp` and vanishes when the container stops.  

This variant does **not** use VNC/noVNC — Firefox draws directly to your host’s display.  
**Linux hosts only** (X11 or Wayland). macOS/Windows require extra X/Wayland tooling.

---

## Features
- **i2pd (C++ I2P router)** defaults:
  - HTTP proxy → `127.0.0.1:4444`
  - SOCKS5 proxy → `127.0.0.1:4447`
  - Web console → `http://127.0.0.1:7070/`
- **Firefox ESR** auto-launches to the i2pd console
- **Proxy locked** — Firefox cannot bypass I2P (enterprise policies)
- **Optional firewall** — locks Firefox to `localhost` only (requires Docker capabilities)
- **Stateless** — all configs/logs/history vanish when container stops
- Supports both:
  - **Root mode** (firewall possible)
  - **Non-root mode** (simpler X11 permissions, no firewall)

---

## Build
```bash
docker build -t i2p-live .

Run Examples
IMPORTANT: You must set a GUI environment or the container will refuse to start.

X11: Set DISPLAY and mount /tmp/.X11-unix (plus .Xauthority in root mode)

Wayland: Set MOZ_ENABLE_WAYLAND=1 and mount your Wayland socket

Tip: For X11, run xhost +si:localuser:$(whoami) once per session.


1. Root mode (default, allows firewall)
# X11
xhost +si:localuser:$(whoami)
docker run --rm \
  -e DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  -v ${XAUTHORITY:-$HOME/.Xauthority}:/tmp/.Xauthority:ro \
  -e XAUTHORITY=/tmp/.Xauthority \
  i2p-live


# Wayland
docker run --rm \
  -e MOZ_ENABLE_WAYLAND=1 \
  -e WAYLAND_DISPLAY \
  -v $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/$WAYLAND_DISPLAY \
  -e XDG_RUNTIME_DIR=/tmp \
  --device /dev/dri \
  i2p-live


2. Root mode with firewall enabled
# Restricts Firefox to localhost only — prevents proxy bypass.

xhost +si:localuser:$(whoami)
docker run --rm \
  --cap-add=NET_ADMIN --cap-add=NET_RAW \
  -e DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  -v ${XAUTHORITY:-$HOME/.Xauthority}:/tmp/.Xauthority:ro \
  -e XAUTHORITY=/tmp/.Xauthority \
  i2p-live

3. Non-root mode (no firewall, simpler X11)
xhost +si:localuser:$(whoami)
docker run --rm \
  --user $(id -u):$(id -g) \
  -e DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  -v ${XAUTHORITY:-$HOME/.Xauthority}:/tmp/.Xauthority:ro \
  -e XAUTHORITY=/tmp/.Xauthority \
  i2p-live

4. Non-root mode on Wayland
docker run --rm \
  --user $(id -u):$(id -g) \
  -e MOZ_ENABLE_WAYLAND=1 \
  -e WAYLAND_DISPLAY \
  -v $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/$WAYLAND_DISPLAY \
  -e XDG_RUNTIME_DIR=/tmp \
  --device /dev/dri \
  i2p-live

5. Kiosk mode (root mode, X11)
xhost +si:localuser:$(whoami)
docker run --rm \
  -e DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  -v ${XAUTHORITY:-$HOME/.Xauthority}:/tmp/.Xauthority:ro \
  -e XAUTHORITY=/tmp/.Xauthority \
  -e FIREFOX_ARGS="--kiosk" \
  i2p-live

Security Notes
Firefox’s proxy is locked via enterprise policies; bypass list is empty.

DoH/TRR, DNS prefetch, and QUIC disabled.

WebRTC disabled to prevent IP leaks.

Optional firewall (--cap-add=NET_ADMIN --cap-add=NET_RAW) restricts Firefox user to localhost.

i2pd router user (i2p) has full outbound access for peer traffic.



