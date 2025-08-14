> ⚡ **Stateless Docker container for instant I2P access with Firefox — GUI or noVNC, privacy-focused, zero persistence.**

# i2p-live

A ready-to-use **stateless** Docker container for instantly accessing the I2P network with Firefox.  
Supports both **Direct GUI mode** (X11/Wayland) and **VNC/noVNC mode** for in-browser remote access.

> **Note:** All data is stored in `/tmp` inside the container — **nothing is persisted**.  
> When the container stops, all logs, browser data, and router keys are wiped.

---

## 🚀 Quick Start (noVNC mode with firewall)

```bash
docker run --rm -p 8080:8080 -e VNC=1 -e I2PD_ARGS="--ssu false --ntcp2 true" i2p-live
```

Then open: [http://localhost:8080](http://localhost:8080)  
Firefox will be running inside the container, already configured for I2P.

---

## Features

- Preconfigured **i2pd** router with HTTP proxy (`127.0.0.1:4444`)
- Firefox pre-set to route all traffic through I2P
- Optional egress firewall to block all non-I2P traffic from Firefox
- Two access modes:
  - **Direct GUI mode** – launches Firefox on your host display
  - **VNC/noVNC mode** – use in-browser without X11
- Zero persistence — privacy by default

---

## Build

```bash
git clone https://github.com/chrisplusplus/i2p-live.git
cd i2p-live
docker build -t i2p-live .
```

---

## Run Examples

### 1. Direct GUI Mode (X11 on Linux)

```bash
xhost +local:docker   # Allow Docker to use your X11 display

docker run --rm \
  -e DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  -v ${XAUTHORITY:-$HOME/.Xauthority}:/tmp/.Xauthority:ro \
  -e XAUTHORITY=/tmp/.Xauthority \
  --cap-add=NET_ADMIN --cap-add=NET_RAW \
  i2p-live
```

Firefox will open directly on your desktop with I2P running in the background.  
If you omit `--cap-add=...`, the firewall restriction will be disabled (you’ll get a warning).

---

### 2. Direct GUI Mode (Wayland)

```bash
docker run --rm \
  -e MOZ_ENABLE_WAYLAND=1 \
  -v $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/$WAYLAND_DISPLAY \
  -e WAYLAND_DISPLAY=$WAYLAND_DISPLAY \
  --cap-add=NET_ADMIN --cap-add=NET_RAW \
  i2p-live
```

---

### 3. VNC/noVNC Mode (No X11/Wayland Required)

If your network blocks UDP, run TCP-only:
```bash
docker run --rm -p 8080:8080 -e VNC=1 -e I2PD_ARGS="--ssu false --ntcp2 true" i2p-live
```

Then open:  
[http://localhost:8080](http://localhost:8080)  
This loads the noVNC web UI and connects to the container’s Firefox session.

---

### 4. VNC Mode with Password & Custom Resolution

```bash
docker run --rm -p 8080:8080 \
  -e VNC=1 \
  -e VNC_PASSWORD=mysecret \
  -e RESOLUTION=1440x900 \
  i2p-live
```

---

## Security Notes

- The firewall restriction only works if the container runs as **root** with:
  ```
  --cap-add=NET_ADMIN --cap-add=NET_RAW
  ```
- Without the firewall, Firefox **could bypass I2P** if settings are changed.
- All data is stored in `/tmp` inside the container and wiped when it exits.

---

## 💰 Donations

If you find this project useful and want to support development, you can donate using Monero (XMR):

```
8AfYtu2AoSWcs9bKZEfPFTdiamJm4HE1tFwFCR1r2FDPFstZ5b7DHBgZYP8W3V44D5HrWH54nCvM1dLcKVC75XMWHhaTxmf
```
*(Privacy-focused, no middlemen, no tracking)*
