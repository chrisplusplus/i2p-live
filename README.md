# i2p-live
⚡ One-command, stateless I2P browser environment in Docker

## Overview
`i2p-live` runs a pre-configured I2P router and Firefox ESR in a lightweight Linux desktop accessible from your browser.  
It is designed to be **stateless** — when the container stops, all logs, browsing history, and configs vanish.

No installation or configuration required — **just run and connect**.

---

## Features
- **I2P Router** pre-configured for HTTP proxy (`127.0.0.1:4444`) and SOCKS5 proxy (`127.0.0.1:4447`)
- **Firefox ESR** locked to I2P proxies (no bypass possible)
- **Lightweight desktop** with Fluxbox window manager
- **TigerVNC + noVNC** for in-browser GUI
- **Stateless** — all data in `/tmp`, gone on stop
- **Non-root** runtime for safety
- **One port** to expose: `8080` (noVNC web UI)

---

## Quick Start

### 1. Build
```bash
docker build -t i2p-live .
