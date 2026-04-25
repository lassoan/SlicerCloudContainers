# Linux Desktop GPU

This container provides a full KDE desktop environment over noVNC, with NVIDIA GPU passthrough support similar to `slicer-gui-gpu`.

## What Is Included

- KDE Plasma desktop via VNC + noVNC
- Syncthing for workspace synchronization
- Optional Cloudflare tunnel support for remote VNC and SSH access
- NVIDIA GPU runtime support (`--gpus all`)
- VirtualGL (`vglrun`) for GPU-accelerated OpenGL applications inside the desktop

## Prerequisites

- Docker Engine running
- NVIDIA drivers installed on the host (`nvidia-smi` works on host)
- NVIDIA Container Toolkit configured for Docker

Quick validation:

```bash
docker run --rm --gpus all nvidia/cuda:12.2.2-base-ubuntu22.04 nvidia-smi
```

## Configure

1. Copy the template:

```bash
cp .env.local.example .env.local
```

2. Edit `.env.local` and set at least:

- `VNC_PASSWORD`
- `SSH_PASSWORD`
- `STORAGE_DIR`

Optional:

- `CF_VNC_TUNNEL_TOKEN`
- `CF_SSH_TUNNEL_TOKEN`
- `NVIDIA_VISIBLE_DEVICES` (default: `all`)
- `NVIDIA_DRIVER_CAPABILITIES` (default: `all`)

## Run

```bash
./start-container.sh
```

Stop:

```bash
./stop-container.sh
```

## GPU Usage Inside Desktop

Most desktop apps work normally. For OpenGL-intensive apps, run with VirtualGL inside the container shell:

```bash
vglrun -d egl <your-app>
```

Example checks inside the container:

```bash
nvidia-smi
glxinfo | grep -E "OpenGL vendor|OpenGL renderer"
vglrun -d egl glxinfo | grep -E "OpenGL vendor|OpenGL renderer"
```

## Notes

- noVNC and Syncthing are intentionally not published on localhost by default in `start-container.sh`; use your configured Cloudflare tunnel or update script port mappings as needed.
- Persistent data lives under `STORAGE_DIR`.
