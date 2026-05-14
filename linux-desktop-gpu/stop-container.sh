#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="linux-desktop-gpu"

if docker ps -a --format '{{.Names}}' | grep -Fxq "${CONTAINER_NAME}"; then
  docker stop "${CONTAINER_NAME}"
else
  echo "Container '${CONTAINER_NAME}' does not exist."
fi
