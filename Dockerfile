FROM debian:bookworm-slim

# Labels
LABEL org.opencontainers.image.source="https://github.com/flyzstu/openclaw-docker"
LABEL org.opencontainers.image.description="Pre-built OpenClaw (Clawbot) Docker image using Node 24 and Homebrew (user-centric build)"
LABEL org.opencontainers.image.licenses="MIT"

# Avoid interactive prompts during apt install
ENV DEBIAN_FRONTEND=noninteractive

# Set environment variables for the build process
ENV NVM_DIR=/home/node/.nvm \
    NODE_VERSION=24 \
    HOMEBREW_PREFIX=/home/linuxbrew/.linuxbrew \
    HOMEBREW_NO_AUTO_UPDATE=1 \
    HOMEBREW_NO_INSTALL_CLEANUP=1

# Pre-configure PATH
ENV PATH=/home/linuxbrew/.linuxbrew/bin:/home/node/.nvm/versions/node/v24/bin:${PATH}

# 1. Install system dependencies, create users, and setup Homebrew in a single layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    unzip \
    build-essential \
    procps \
    file \
    sudo \
    jq \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -m -s /bin/bash node \
    && echo "node ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && useradd -m -s /bin/bash linuxbrew \
    && echo "linuxbrew ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && mkdir -p /home/linuxbrew/.linuxbrew \
    && chown -R linuxbrew:linuxbrew /home/linuxbrew/.linuxbrew \
    && su linuxbrew -c "curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh | bash" \
    && chmod -R a+rx /home/linuxbrew/.linuxbrew

# 2. Switch to node user and setup Node.js + OpenClaw
USER node
WORKDIR /home/node

# 3. Install NVM, Node 24, and OpenClaw in a single layer
ARG OPENCLAW_VERSION=latest
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash \
    && . $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm use $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && if [ "$OPENCLAW_VERSION" = "main" ] || [ -z "$OPENCLAW_VERSION" ]; then \
        npm install -g openclaw@latest; \
    else \
        npm install -g openclaw@${OPENCLAW_VERSION}; \
    fi \
    && mkdir -p /home/node/.openclaw

# 4. Set runtime environment
ENV NODE_ENV=production

CMD ["npx", "openclaw", "gateway", "run", "--verbose"]
