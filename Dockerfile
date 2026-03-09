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
    zsh \
    wget \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -m -s /bin/zsh node \
    && echo "node ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && su node -c "curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh | bash"
# 2. Switch to node user and setup Node.js + OpenClaw
USER node
WORKDIR /home/node

# 3. Install NVM, Node 24, and OpenClaw in a single layer
RUN NVM_VERSION=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | jq -r '.tag_name') \
    && curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash \
    && . $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm use $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && npm install -g openclaw@latest

# 4. Install oh-my-zsh and plugins
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
    && git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting \
    && git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions \
    && git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-completions \
    && git clone https://github.com/zsh-users/zsh-history-substring-search ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-history-substring-search

# 5. Configure oh-my-zsh with plugins
RUN sed -i 's/plugins=(git)/plugins=(zsh-completions zsh-syntax-highlighting zsh-autosuggestions zsh-history-substring-search)/' ~/.zshrc \
    && sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="half-life"/' ~/.zshrc \
    && echo 'export ZSH_HISTORY_SIZE=100000' >> ~/.zshrc \
    && echo 'setopt HIST_IGNORE_DUPS' >> ~/.zshrc \
    && echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.zshrc \
    && echo 'autoload -Uz compinit' >> ~/.zshrc \
    && echo 'compinit' >> ~/.zshrc

# 6. Set runtime environment
ENV NODE_ENV=production

# Set default shell to zsh
ENV SHELL=/bin/zsh

CMD ["/bin/zsh", "-c", ". ~/.zshrc; source $NVM_DIR/nvm.sh && npx openclaw gateway run --verbose"]
