FROM debian:stable-slim

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    I2P_HTTP_PROXY_PORT=4444 \
    I2P_SOCKS_PORT=4447 \
    FIREFOX_ARGS=""

# Minimal runtime for i2pd + Firefox (no VNC)
RUN apt-get update && apt-get install -y --no-install-recommends \
    locales ca-certificates wget curl procps tini iptables \
    netcat-openbsd \
    firefox-esr fonts-dejavu-core \
    i2pd \
    # helpful but small
    xdg-utils \
 && sed -i 's/# \(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen \
 && locale-gen \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# Users
RUN useradd -m -s /bin/bash i2p && \
    useradd -m -s /bin/bash app

# Firefox enterprise policies (lock proxies; no-bypass prefs)
ADD firefox/policies.json /usr/lib/firefox-esr/distribution/policies.json
ADD firefox/user.js       /etc/firefox-esr/user.js

# Entrypoint
ADD entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Stateless intention
VOLUME ["/tmp"]

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
