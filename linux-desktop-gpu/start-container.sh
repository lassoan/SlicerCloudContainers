#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="linux-desktop-gpu"
CONTAINER_NAME="linux-desktop-gpu"

if [[ ! -f "${SCRIPT_DIR}/.env.local" ]]; then
  echo "ERROR: Missing env file: ${SCRIPT_DIR}/.env.local"
  echo "Define container environment variables and STORAGE_DIR in .env.local before running this script."
  exit 1
fi

env_storage="$(grep -m1 '^STORAGE_DIR=' "${SCRIPT_DIR}/.env.local" | cut -d= -f2- || true)"
env_storage="${env_storage%$'\r'}"
if [[ -z "${env_storage}" ]]; then
  echo "ERROR: STORAGE_DIR is not set in ${SCRIPT_DIR}/.env.local"
  exit 1
fi
STORAGE_DIR="${env_storage}"

ensure_docker_engine() {
  if docker context inspect desktop-linux >/dev/null 2>&1; then
    docker context use desktop-linux >/dev/null 2>&1 || true
  fi

  local waited=0
  until docker version >/dev/null 2>&1; do
    if (( waited >= 120 )); then
      echo "ERROR: Docker engine did not become ready within 120 seconds."
      echo "Start your Docker engine and rerun this script."
      echo "If needed, run: docker context use desktop-linux"
      return 1
    fi

    if (( waited == 0 )); then
      echo "Docker daemon is not available yet. Waiting for it to start..."
    fi

    sleep 2
    waited=$((waited + 2))
  done
}

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: Docker CLI was not found in PATH."
  echo "Install Docker and reopen the terminal before running this script."
  exit 1
fi

ensure_docker_engine

mkdir -p \
  "${STORAGE_DIR}/config/syncthing" \
  "${STORAGE_DIR}/workspace" \
  "${STORAGE_DIR}/data"

docker build -t "${IMAGE_NAME}" "${SCRIPT_DIR}"

docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true

docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart unless-stopped \
  --gpus all \
  --shm-size=4g \
  --env-file "${SCRIPT_DIR}/.env.local" \
  -v "${STORAGE_DIR}/config:/config" \
  -v "${STORAGE_DIR}/workspace:/workspace" \
  -v "${STORAGE_DIR}/data:/data" \
  "${IMAGE_NAME}"

echo "noVNC desktop is not exposed on localhost; access it through the Cloudflare tunnel."
echo "Syncthing UI is not exposed on localhost; open it inside the container session."
