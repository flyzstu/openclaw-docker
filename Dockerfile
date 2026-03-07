FROM debian:bookworm-slim

LABEL org.opencontainers.image.source="https://github.com/flyzstu/openclaw-docker"
LABEL org.opencontainers.image.description="Pre-built OpenClaw (Clawbot) Docker image using Node 24, Bun, and Homebrew"
LABEL org.opencontainers.image.licenses="MIT"

# Set environment variables for NVM and Node
ENV NVM_DIR /usr/local/nvm
ENV NODE_VERSION 24
# Set Bun environment variables - move to a common location
ENV BUN_INSTALL /usr/local
ENV PATH $BUN_INSTALL/bin:$PATH

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    ca-certificates \
    unzip \
    build-essential \
    procps \
    file \
    sudo \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install NVM and Node 24
RUN mkdir -p $NVM_DIR && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash && \
    . $NVM_DIR/nvm.sh && \
    nvm install $NODE_VERSION && \
    nvm use $NODE_VERSION && \
    nvm alias default $NODE_VERSION && \
    # Link node/npm/npx to /usr/local/bin for global access
    NODE_PATH=$(. $NVM_DIR/nvm.sh && nvm which $NODE_VERSION) && \
    NODE_BIN_DIR=$(dirname $NODE_PATH) && \
    for bin in $NODE_BIN_DIR/*; do ln -sf $bin /usr/local/bin/$(basename $bin); done

# Install pnpm and bun globally via npm
RUN npm install -g pnpm bun

# Create node user early to set permissions
RUN useradd -m -s /bin/bash node || true

# Pre-create Bun cache and config directories for node user
RUN mkdir -p /home/node/.bun/bin /home/node/.openclaw /home/node/.openclaw/workspace && \
    chown -R node:node /home/node

# Install OpenClaw via npm
ARG OPENCLAW_VERSION=latest
RUN if [ "$OPENCLAW_VERSION" = "main" ] || [ -z "$OPENCLAW_VERSION" ]; then \
      npm install -g openclaw@latest; \
    else \
      npm install -g openclaw@${OPENCLAW_VERSION}; \
    fi

# Install Homebrew (required for first-party skills)
RUN useradd -m -s /bin/bash linuxbrew && \
    echo 'linuxbrew ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    mkdir -p /home/linuxbrew/.linuxbrew && \
    chown -R linuxbrew:linuxbrew /home/linuxbrew/.linuxbrew
RUN mkdir -p /home/linuxbrew/.linuxbrew/Homebrew && \
    git clone --depth 1 https://github.com/Homebrew/brew /home/linuxbrew/.linuxbrew/Homebrew && \
    chown -R linuxbrew:linuxbrew /home/linuxbrew/.linuxbrew && \
    ln -s /home/linuxbrew/.linuxbrew/Homebrew/bin/brew /home/linuxbrew/.linuxbrew/bin/brew || true && \
    mkdir -p /home/linuxbrew/.linuxbrew/bin && \
    ln -s /home/linuxbrew/.linuxbrew/Homebrew/bin/brew /home/linuxbrew/.linuxbrew/bin/brew

# Set up Homebrew environment
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"
ENV HOMEBREW_NO_AUTO_UPDATE=1
ENV HOMEBREW_NO_INSTALL_CLEANUP=1

# Ensure node user can run globally installed bins and has access to its home
RUN chown -R node:node /usr/local/lib/node_modules || true && \
    chown -R node:node /home/linuxbrew/.linuxbrew 2>/dev/null || true

USER node
WORKDIR /home/node

ENV NODE_ENV=production
# Ensure /usr/local/bin is first in PATH for the node user
ENV PATH="/usr/local/bin:${PATH}"
# Set Bun's installation directory for the node user to its home to avoid permission issues with bunx cache
ENV BUN_INSTALL="/home/node/.bun"
ENV PATH="/home/node/.bun/bin:${PATH}"

# Default command
# Using --bun flag to ensure it runs with bun runtime if possible, or just bunx
ENTRYPOINT ["bunx", "openclaw"]
CMD ["gateway"]
