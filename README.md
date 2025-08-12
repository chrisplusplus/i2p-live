# i2p-live

A ready-to-use **stateless** Docker container for instantly accessing the I2P network using Firefox.  
Supports both **Direct GUI mode** (X11/Wayland) and **VNC/noVNC mode** for in-browser remote access.

All data is stored in `/tmp` inside the container — **nothing is persisted**.  
When the container stops, all logs, browser data, and router keys are wiped.

---

## Features
- Preconfigured **i2pd** router with HTTP proxy (127.0.0.1:4444)
- Firefox pre-set to route all traffic through I2P
- Egress firewall (optional) to block all non-I2P traffic from Firefox
- Two access modes:
  - **Direct GUI mode** – launches Firefox on your host display
  - **VNC/noVNC mode** – run in browser without needing X11
- Zero persistence (stateless) — privacy by default

---

## Build

```bash
git clone https://github.com/YOURNAME/i2p-live.git
cd i2p-live
docker build -t i2p-live .


Run Examples
1. Direct GUI mode (X11 on Linux)

xhost +local:docker   # Allow Docker to use your X11 display
docker run --rm \
  -e DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  -v ${XAUTHORITY:-$HOME/.Xauthority}:/tmp/.Xauthority:ro \
  -e XAUTHORITY=/tmp/.Xauthority \
  --cap-add=NET_ADMIN --cap-add=NET_RAW \
  i2p-live


Firefox will open directly on your desktop with I2P running in the background.
If you omit --cap-add=..., the firewall restriction will be disabled (you’ll get a warning).

2. Direct GUI mode (Wayland)

docker run --rm \
  -e MOZ_ENABLE_WAYLAND=1 \
  -v $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/$WAYLAND_DISPLAY \
  -e WAYLAND_DISPLAY=$WAYLAND_DISPLAY \
  --cap-add=NET_ADMIN --cap-add=NET_RAW \
  i2p-live

3. VNC/noVNC mode (no X11/Wayland required)

docker run --rm -p 8080:8080 -e VNC=1 \
  --cap-add=NET_ADMIN --cap-add=NET_RAW \
  i2p-live


Then open:


http://localhost:8080

This loads the noVNC web UI and connects to the container’s Firefox session.

4. VNC mode with password & custom resolution

docker run --rm -p 8080:8080 \
  -e VNC=1 \
  -e VNC_PASSWORD=mysecret \
  -e RESOLUTION=1440x900 \
  i2p-live

Security Notes
Firewall restriction for Firefox only works if container runs as root and with --cap-add=NET_ADMIN --cap-add=NET_RAW.

Without firewall, Firefox could bypass I2P if settings are changed.

All data is stored in /tmp inside container and wiped on exit.

Quick One-Liner
Start in noVNC mode with firewall:

docker run --rm -p 8080:8080 -e VNC=1 \
  --cap-add=NET_ADMIN --cap-add=NET_RAW \
  i2p-live

Then open http://localhost:8080 and browse I2P.

