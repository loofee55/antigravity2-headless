FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# 1. Install system runtime dependencies for Electron, backup scripts, and core utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    gnupg \
    git \
    rsync \
    tar \
    gzip \
    procps \
    python3 \
    sqlite3 \
    openssh-client \
    xdg-utils \
    fonts-liberation \
    sudo \
    # Electron / Chromium runtime libraries
    libgtk-3-0 \
    libnss3 \
    libasound2t64 \
    libgbm1 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libxtst6 \
    libxss1 \
    && rm -rf /var/lib/apt/lists/*

# 2. Install Google Chrome Stable for automated browser tool support (/browser MCP)
RUN mkdir -p /etc/apt/keyrings && \
    curl -fSsL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg && \
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update && apt-get install -y --no-install-recommends google-chrome-stable && \
    rm -rf /var/lib/apt/lists/*

# 3. Create non-root user (UID=1000, GID=1000) with home directory at /home/user
RUN groupadd -g 1000 user && \
    useradd -u 1000 -g user -m -d /home/user -s /bin/bash user && \
    echo "user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# 4. Extract Antigravity package into /opt/antigravity
COPY Antigravity.tar.gz /tmp/
RUN tar -xzf /tmp/Antigravity.tar.gz -C /opt/ && \
    rm -rf /opt/antigravity && \
    mv /opt/Antigravity-x64 /opt/antigravity && \
    rm -f /tmp/Antigravity.tar.gz && \
    chown -R user:user /opt/antigravity

USER user
WORKDIR /opt/work

ENV HOME=/home/user \
    TZ=Asia/Ho_Chi_Minh \
    ELECTRON_OZONE_PLATFORM_HINT=headless \
    PATH="/home/user/.gemini/antigravity/bin:/home/user/.local/bin:/opt/antigravity:${PATH}"

# 5. Container healthcheck: verify Antigravity daemon process is alive
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD pgrep -f "/opt/antigravity/antigravity" >/dev/null || exit 1

# Launch Antigravity in headless mode (auto-connects to Remote Control)
CMD ["/opt/antigravity/antigravity", "--no-sandbox"]
