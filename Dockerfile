FROM debian:bookworm-slim

LABEL org.opencontainers.image.source="https://github.com/flyzstu/openclaw-docker"
LABEL org.opencontainers.image.description="Pre-built OpenClaw (Clawbot) Docker image using Node 24, Bun, and Homebrew"
LABEL org.opencontainers.image.licenses="MIT"

# Set environment variables
ENV NVM_DIR /usr/local/nvm
ENV NODE_VERSION 24
ENV PATH /usr/local/bin:$PATH

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

# Install pnpm, bun, and OpenClaw via npm (more reliable in Docker)
ARG OPENCLAW_VERSION=latest
RUN if [ "$OPENCLAW_VERSION" = "main" ] || [ -z "$OPENCLAW_VERSION" ]; then \
      npm install -g pnpm bun openclaw@latest; \
    else \
      npm install -g pnpm bun openclaw@${OPENCLAW_VERSION}; \
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

# Create node user and app directory
RUN useradd -m -s /bin/bash node || true && \
    mkdir -p /home/node/.openclaw /home/node/.openclaw/workspace && \
    chown -R node:node /home/node && \
    chown -R node:node /home/linuxbrew/.linuxbrew

USER node
WORKDIR /home/node

ENV NODE_ENV=production
ENV PATH="/usr/local/bin:${PATH}"

# Default command
ENTRYPOINT ["bunx", "openclaw"]
CMD ["gateway"]
