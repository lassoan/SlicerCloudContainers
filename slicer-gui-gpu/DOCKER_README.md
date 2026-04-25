# 3D Slicer Docker with NVIDIA GPU and noVNC

This Docker setup runs 3D Slicer with NVIDIA GPU acceleration in a container accessible via a web-based noVNC interface.

## Prerequisites

### Required
- **Docker**: Version 20.10+
- **NVIDIA Container Toolkit**: For GPU support in containers
- **NVIDIA GPU**: With compute capability 3.0 or higher
- **NVIDIA Drivers**: Compatible with CUDA 12.2

### Optional
- **Docker Compose**: For easier container management

## Installation

### 1. Setup NVIDIA Container Toolkit (on Linux)

```bash
# Install Docker first if needed
curl -fsSL https://get.docker.com | sh

# Install NVIDIA Container Toolkit (Ubuntu 22.04/24.04+)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
   sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
   sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
   sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

# Configure Docker runtime
sudo nvidia-ctk runtime configure --runtime=docker

# Restart Docker daemon
if command -v systemctl >/dev/null 2>&1; then
   sudo systemctl restart docker
else
   sudo service docker restart
fi

# Verify GPU access
docker run --rm --gpus all nvidia/cuda:12.2.2-base-ubuntu22.04 nvidia-smi
```

If you see `permission denied while trying to connect to the docker API at unix:///var/run/docker.sock`, add your user to the Docker group and re-login:

```bash
sudo usermod -aG docker $USER
newgrp docker
docker run --rm --gpus all nvidia/cuda:12.2.2-base-ubuntu22.04 nvidia-smi
```

You can also run Docker commands with `sudo` as a temporary workaround.

If you get `Unit docker.service not found`, Docker Engine is not running under systemd on that host. Use `sudo service docker restart`, or start Docker Desktop / dockerd directly depending on your environment.

### 2. Build the Docker Image

Using docker compose (recommended):
```bash
docker compose build
```

Or using docker directly:
```bash
docker build -t slicer-gui-gpu:latest .
```

## Usage

### With Docker Compose (Recommended)

```bash
# Start the container
docker compose up -d

# View logs
docker compose logs -f slicer

# Stop the container
docker compose down

# Access the container shell
docker compose exec slicer bash
```

### With Docker CLI

```bash
# Build the image
   docker build -t slicer-gui-gpu:latest .

# Run the container
            docker run -d \
               --name slicer-app-1 \
  --runtime nvidia \
  -e NVIDIA_VISIBLE_DEVICES=all \
  -e NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics \
  -p 6080:6080 \
  -p 5901:5901 \
  -v slicer-home:/home/slicer \
  -v ./data:/home/slicer/data \
  --shm-size=4gb \
slicer-gui-gpu:latest

# View logs
docker logs -f slicer-app-1

# Stop the container
docker stop slicer-app-1
docker rm slicer-app-1
```

## Access 3D Slicer

### Via Web Browser (noVNC)
1. Open your browser and navigate to: `http://localhost:6080/vnc.html`
2. If prompted for a password, enter: `slicer123`
3. You should see the 3D Slicer interface

### Via VNC Client
1. Use any VNC viewer (e.g., TightVNC, RealVNC)
2. Connect to: `localhost:5901`
3. Enter password: `slicer123`

## GUI Features

- **Resolution**: 1920x1080 (24-bit color)
- **Display Server**: Xvfb (virtual framebuffer)
- **VNC Server**: TigerVNC
- **Web Interface**: noVNC over websockets
- **Port 6080**: noVNC HTTP interface
- **Port 5901**: Direct VNC port

## GPU Acceleration

The container automatically uses NVIDIA GPU for:
- CUDA computation
- Graphics rendering (if supported by your GPU)
- ML/AI operations

Verify GPU access inside the container:
```bash
   docker exec slicer-app-1 nvidia-smi
```

## Configuration

### Change VNC Password

Inside the running container:
```bash
   docker exec -it slicer-app-1 bash
vncpasswd
```

Or modify the startup script to use a different default password.

### Adjust Display Resolution

Edit the `Dockerfile` and modify this line:
```dockerfile
Xvfb :99 -screen 0 1920x1080x24 &
```

Change `1920x1080` to your desired resolution.

### Increase GPU Memory

In `docker-compose.yml`:
```yaml
shm_size: 8gb  # Increase from 4gb as needed
```

### Mount Project Data

Ensure the `./data` directory exists:
```bash
mkdir -p data
```

Files in `./data` will be accessible at `/home/slicer/data` inside the container.

## Troubleshooting

### GPU Not Available
- Verify NVIDIA drivers: `nvidia-smi` on host
- Check NVIDIA Container Toolkit installation
- Verify Docker GPU support: `docker run --rm --gpus all nvidia/cuda:12.2.2-base-ubuntu22.04 nvidia-smi`

### Connection Refused on Port 6080
- Verify container is running: `docker ps`
- Check port mapping: `docker port slicer-gui-gpu`
- Try accessing `http://127.0.0.1:6080` instead of localhost

### Poor Performance
- Increase shared memory: `shm_size` in docker-compose.yml
- Check CPU/GPU usage: `docker stats`
- Verify GPU passthrough: `docker exec slicer-gui-gpu nvidia-smi`

### Display Issues
- Try scaling the browser window
- Clear browser cache and reload
- Restart the container
- Try accessing with a different VNC client

## Performance Optimization

### For Better Performance:
1. **Increase Shared Memory**: Set `shm_size: 8gb` or higher
2. **CPU Limit**: Adjust as needed (no limit by default)
3. **GPU Memory**: Ensure sufficient VRAM
4. **Resolution**: Lower resolution may improve remote viewing speed

### For Production:
1. Change default VNC password
2. Use network isolation/VPN for remote access
3. Enable resource limits in docker-compose.yml
4. Use Read-only volumes where appropriate
5. Run security scans on the Docker image

## Slicer Version

Current version: **5.10.0**

To use a different version, modify the `SLICER_VERSION` environment variable in the Dockerfile:
```dockerfile
ENV SLICER_VERSION=5.9.0
```

Available versions at: https://download.slicer.org/

## Cleanup

Remove all containers and volumes:
```bash
docker compose down -v
```

Remove the built image:
```bash
docker rmi slicer-gui-gpu:latest
```

## Network Access

For remote access over the network:

### Option 1: Direct Port Binding
```bash
docker run -p 0.0.0.0:6080:6080 ...
```

Then access from remote machine: `http://<host-ip>:6080/vnc.html`

### Option 2: Reverse Proxy (Nginx)
```nginx
server {
    listen 80;
    server_name slicer.example.com;

    location / {
        proxy_pass http://localhost:6080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}
```

### Option 3: SSH Tunnel
```bash
ssh -L 6080:localhost:6080 user@remote-host
```

Then access: `http://localhost:6080/vnc.html`

## Cloudflare Tunnel (Recommended for Remote Access)

Cloudflare Tunnel provides **secure remote access without exposing ports** to the internet. It's the recommended method for production deployments and integrations with slicercloudapp.

### Quick Setup

1. **Set up Cloudflare Tunnel** (see [CLOUDFLARE_TUNNEL.md](CLOUDFLARE_TUNNEL.md) for detailed guide)

2. **Add credentials to .env.local**:
   ```bash
   cp .env.local.example .env.local
   ```
   Edit `.env.local`:
   ```env
   CLOUDFLARE_TUNNEL_TOKEN=<your-token>
   CLOUDFLARE_TUNNEL_NAME=slicer-gui-gpu
   CLOUDFLARE_TUNNEL_DOMAIN=slicer.example.com
   ```

3. **Start container**:
   ```bash
   docker compose up -d
   ```

4. **Access via hyperlink**:
   ```
   https://slicer.example.com/vnc.html
   ```

### Benefits

- ✓ No port exposure (Zero Trust)
- ✓ Built-in DDoS protection
- ✓ Free tier available
- ✓ Global edge network
- ✓ Easy to integrate with cloud apps
- ✓ Optional authentication gateway

### Check Tunnel Status

```bash
# Using helper script
./docker-slicer.sh tunnel
# or
make tunnel

# Manual check
docker compose logs slicer | grep -i cloudflare
```

For complete Cloudflare Tunnel setup guide, see: **[CLOUDFLARE_TUNNEL.md](CLOUDFLARE_TUNNEL.md)**

## Resources

- [3D Slicer Download](https://download.slicer.org/)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/)
- [noVNC](https://novnc.com/info.html)
- [3D Slicer Documentation](https://slicer.readthedocs.io/)

## License

This Docker setup follows the same license as 3D Slicer (BSD License).
