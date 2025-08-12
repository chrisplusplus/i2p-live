# i2p-live
⚡ One-command, stateless I2P browser environment in Docker

---

## Overview
`i2p-live` runs a pre-configured I2P router and Firefox ESR in a lightweight Linux desktop,  
accessible through your host’s browser via **noVNC**.

It is designed to be **stateless** — when the container stops, all logs, browsing history,  
and configuration vanish.

With this setup, **Firefox is launched directly inside the container** at startup,  
already locked to the I2P network.

---

## Features
- **I2P Router** pre-configured for:
  - HTTP proxy → `127.0.0.1:4444`
  - SOCKS5 proxy → `127.0.0.1:4447`
- **Firefox ESR** launched automatically to the I2P Router Console
- **Proxy locked** — Firefox cannot bypass I2P
- **Lightweight desktop** (Fluxbox) for minimal overhead
- **TigerVNC + noVNC** for in-browser GUI
- **Stateless** — all data in `/tmp`, gone on stop
- **Non-root** runtime for safety
- **One exposed port**: `8080` (noVNC web UI)

---

## Build

Clone or download this repository, then:

```bash
docker build -t i2p-live .

---

## Run
docker run --rm -p 8080:8080 i2p-live

- Open your Browser to http://localhost:8080
- You’ll see a desktop with Firefox already open to http://127.0.0.1:7657/

## Example: custom resolution
```bash
docker run --rm -e RESOLUTION=1600x900 -p 8080:8080 i2p-live


##
