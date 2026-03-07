FROM debian:bookworm-slim

# Labels
LABEL org.opencontainers.image.source="https://github.com/flyzstu/openclaw-docker"
LABEL org.opencontainers.image.description="Pre-built OpenClaw (Clawbot) Docker image using Node 24, Bun, and Homebrew (user-centric build)"
LABEL org.opencontainers.image.licenses="MIT"

# Avoid interactive prompts during apt install
ENV DEBIAN_FRONTEND=noninteractive

# 1. Install system dependencies and sudo
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

# 2. Create node user and add to sudoers
RUN useradd -m -s /bin/bash node && \
    echo "node ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# 3. Create linuxbrew user for Homebrew support
RUN useradd -m -s /bin/bash linuxbrew && \
    echo "linuxbrew ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set environment variables for the build process
ENV NVM_DIR /home/node/.nvm
ENV NODE_VERSION 24
ENV BUN_INSTALL /home/node/.bun
# Pre-configure PATH so subsequent steps can find tools
ENV PATH $BUN_INSTALL/bin:$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH

# 4. Switch to node user for installation
USER node
WORKDIR /home/node

# 5. Install NVM and Node 24 as node user
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash && \
    . $NVM_DIR/nvm.sh && \
    nvm install $NODE_VERSION && \
    nvm use $NODE_VERSION && \
    nvm alias default $NODE_VERSION

# 6. Install pnpm and Bun as node user
RUN . $NVM_DIR/nvm.sh && \
    npm install -g pnpm && \
    curl -fsSL https://bun.sh/install | bash

# 7. Install OpenClaw via npm as node user
ARG OPENCLAW_VERSION=latest
RUN . $NVM_DIR/nvm.sh && \
    if [ "$OPENCLAW_VERSION" = "main" ] || [ -z "$OPENCLAW_VERSION" ]; then \
      npm install -g openclaw@latest; \
    else \
      npm install -g openclaw@${OPENCLAW_VERSION}; \
    fi

# 8. Setup Homebrew (using linuxbrew user)
USER root
RUN mkdir -p /home/linuxbrew/.linuxbrew && \
    chown -R linuxbrew:linuxbrew /home/linuxbrew/.linuxbrew
RUN sudo -u linuxbrew bash -c "mkdir -p /home/linuxbrew/.linuxbrew/Homebrew && \
    git clone --depth 1 https://github.com/Homebrew/brew /home/linuxbrew/.linuxbrew/Homebrew && \
    mkdir -p /home/linuxbrew/.linuxbrew/bin && \
    ln -s /home/linuxbrew/.linuxbrew/Homebrew/bin/brew /home/linuxbrew/.linuxbrew/bin/brew"

# Final system preparation
RUN mkdir -p /home/node/.openclaw /home/node/.openclaw/workspace && \
    chown -R node:node /home/node/.openclaw

# Switch back to node user for runtime
USER node
WORKDIR /home/node

# Set runtime environment variables
ENV NODE_ENV=production
ENV HOMEBREW_NO_AUTO_UPDATE=1
ENV HOMEBREW_NO_INSTALL_CLEANUP=1
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/node/.bun/bin:/home/node/.nvm/versions/node/v24/bin:${PATH}"

# Default command
ENTRYPOINT ["bunx", "openclaw"]
CMD ["gateway"]
