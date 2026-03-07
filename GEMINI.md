# OpenClaw Docker (Clawbot) - Instructional Context

This project provides a pre-built and automated Docker packaging for [OpenClaw](https://github.com/openclaw/openclaw), an AI assistant platform. It ensures that the Docker image is always up-to-date with the latest OpenClaw releases.

## Project Overview

- **Purpose**: Simplify the deployment and maintenance of OpenClaw using Docker.
- **Main Technologies**:
  - **Docker & Docker Compose**: For containerization and service orchestration.
  - **Node.js (v22)**: The runtime for OpenClaw.
  - **Bun & pnpm**: Used for building OpenClaw and managing dependencies.
  - **Homebrew**: Included in the image to support first-party OpenClaw skills.
  - **GitHub Actions**: Automates daily builds and tracks upstream releases.

## Architecture & Services

The project defines two primary services in `docker-compose.yml`:
1.  **openclaw-gateway**: The main AI assistant service, running the OpenClaw gateway and dashboard.
2.  **openclaw-cli**: A utility service for running CLI commands like `onboard` for initial setup.
3.  **socat-proxy**: A helper service to manage port mapping (specifically for the dashboard).

## Building and Running

### Installation
The project provides one-line installation scripts:
- **Linux / macOS**: `bash <(curl -fsSL https://raw.githubusercontent.com/phioranex/openclaw-docker/main/install.sh)`
- **Windows (PowerShell)**: `irm https://raw.githubusercontent.com/phioranex/openclaw-docker/main/install.ps1 | iex`

### Manual Commands
- **Build Image Locally**:
  ```bash
  docker build -t openclaw-docker .
  ```
- **Initial Setup (Onboarding)**:
  ```bash
  docker compose run --rm openclaw-cli onboard
  ```
- **Start Services**:
  ```bash
  docker compose up -d openclaw-gateway
  ```
- **Stop Services**:
  ```bash
  docker compose down
  ```

## Development & Automation

### CI/CD Workflows
- **`build-image.yml`**: Builds the Docker image and pushes it to GitHub Container Registry (GHCR). It can be triggered manually or by other workflows.
- **`openclaw-release-tracker.yml`**: Runs every 6 hours to check for new releases in the upstream [OpenClaw repository](https://github.com/openclaw/openclaw). If a new release is detected, it updates `.last-openclaw-version` and triggers `build-image.yml`.

### Key Files
- `Dockerfile`: Multi-stage build that clones the latest OpenClaw, installs dependencies with `pnpm`, builds the UI and backend, and sets up a production-ready environment with Homebrew support.
- `docker-compose.yml`: Defines the environment, volumes, and ports for running OpenClaw.
- `install.sh` / `install.ps1`: Shell and PowerShell scripts that automate prerequisite checks, directory creation, and initial setup.
- `.last-openclaw-version`: A state file used by the release tracker to avoid redundant builds.

## Deployment Conventions
- **Persistence**: Configuration and workspace data are stored in `~/.openclaw` on the host, mapped to `/home/node/.openclaw` in the container.
- **User Mapping**: The container runs as the `node` user (UID 1000). The installation scripts handle permissions to ensure the host user can manage files in `~/.openclaw`.
- **Ports**: Gateway API and Dashboard are exposed on port `18789` (internally) and `18790` (via proxy).
