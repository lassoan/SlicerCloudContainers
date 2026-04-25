# 3D Slicer GPU-Accelerated Cloud Container Setup Guide

This guide provides comprehensive instructions for building and deploying the 3D Slicer Docker container with NVIDIA GPU support and noVNC GUI access for the slicercloudapp project.

## Quick Start

```bash
# Build and start
./docker-slicer.sh build
./docker-slicer.sh start

# Access at: http://localhost:6080/vnc.html
```

## System Requirements

### Hardware
- **GPU**: NVIDIA GPU with compute capability 3.0+
- **RAM**: Minimum 8 GB, recommended 16+ GB
- **Storage**: Minimum 15 GB for image (Slicer ~3GB + base ~10GB + dependencies ~2GB)
- **CPU**: Multi-core processor recommended

### Software
- **OS**: Linux or macOS
- **Docker**: 20.10+
- **NVIDIA Container Toolkit**: Required for GPU support
- **NVIDIA Drivers**: Compatible with CUDA 12.2

## Prerequisites Setup

### Linux (Ubuntu 22.04/24.04)

```bash
# 1. Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 2. Install NVIDIA Container Toolkit
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
  sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

# 3. Install host NVIDIA userspace packages (required for nvidia-smi and OpenGL/EGL)
# Choose package versions that match your installed NVIDIA driver major version.
apt-cache search '^nvidia-utils-|^libnvidia-gl-'
# Example for driver major 570:
sudo apt-get install -y nvidia-utils-570 libnvidia-gl-570

# 4. Configure Docker runtime
sudo nvidia-ctk runtime configure --runtime=docker
if command -v systemctl >/dev/null 2>&1; then
  sudo systemctl restart docker
else
  sudo service docker restart
fi

# 5. Add current user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

## Building the Docker Image

```bash
# Copy environment variables
cp .env.local.example .env.local

# Update the variables in .env.local

# Build the container
./docker-slicer.sh build
```

## Running the Container

```bash
./docker-slicer.sh start
```

## Accessing 3D Slicer

### Locally in web browser
1. Open browser: http://localhost:6080/vnc.html
2. Enter password (`VNC_PASSWORD` that was set in the `.env.local` file)
3. Click "Connect"

### Locally using VNC Viewer
1. Download VNC viewer (TigerVNC, RealVNC, etc.)
2. Connect to: `localhost:5901`
3. Password: `VNC_PASSWORD` that was set in the `.env.local` file

### SSH tunnel for remote access
```bash
ssh -L 6080:localhost:6080 user@remote-server
# Then access: http://localhost:6080/vnc.html
```

### Cloudflare tunnel for remote access from anywhere
1. Set `CLOUDFLARE_TUNNEL_TOKEN` and `CLOUDFLARE_TUNNEL_DOMAIN` in `.env.local`
2. Start the container: `./docker-slicer.sh start`
3. Open: `https://<your-domain>/vnc.html`
4. Enter password (`VNC_PASSWORD` that was set in the `.env.local` file)

Example:
```text
https://slicer.example.com/vnc.html
```

## Configuration

### Allocate More GPU Memory

In `docker-compose.yml`:
```yaml
shm_size: 8gb  # Increase from 4gb
```

### Mount Project Data

```bash
# Create data directory
mkdir -p data

# Files placed in ./data will appear at /home/slicer/data
cp myproject.nrrd data/
```

## Verification

### GPU Access
```bash
./docker-slicer.sh gpu-check
# Or manually:
docker exec slicer-app-1 nvidia-smi
```

Expected output shows GPU info with CUDA capabilities.

### Verify GPU Rendering Inside Slicer Python

Use this when GPU volume rendering is slow and you want to confirm whether Slicer is actually using hardware rendering.

In Slicer, open the Python Interactor and run:

```python
import re
import subprocess

print("=== GPU Binary Check (nvidia-smi) ===")
try:
  out = subprocess.check_output(
    [
      "nvidia-smi",
      "--query-gpu=name,driver_version,utilization.gpu,memory.used",
      "--format=csv,noheader",
    ],
    stderr=subprocess.STDOUT,
    text=True,
  )
  print("nvidia-smi: OK")
  print(out)
except Exception as e:
  print(f"nvidia-smi: FAILED ({e})")

print("=== OpenGL Renderer Check ===")
rw = slicer.app.layoutManager().threeDWidget(0).threeDView().renderWindow()
caps = rw.ReportCapabilities()
for key in [
  "OpenGL vendor string",
  "OpenGL renderer string",
  "OpenGL version string",
]:
  m = re.search(re.escape(key) + r":\s*(.+)", caps)
  print(f"{key}: {m.group(1).strip() if m else 'not found'}")
```

Interpretation:
- Healthy GPU rendering path: `OpenGL vendor string` is `NVIDIA Corporation` and `OpenGL renderer string` is your NVIDIA GPU model.
- Software fallback path: renderer shows `llvmpipe` or vendor is `Mesa`.
- If `nvidia-smi` is missing but `/dev/nvidia*` exists in the container, CUDA device passthrough may exist while rendering still falls back to software.

Optional runtime check while interacting with volume rendering:

```bash
docker exec slicer-app-1 watch -n 1 nvidia-smi
```

Rotate/zoom the 3D view. GPU utilization and memory should increase.

### Container Status
```bash
./docker-slicer.sh status
```

Expected output:
```
NAME           STATUS      PORTS
slicer-gui-gpu   Up X min    0.0.0.0:6080->6080/tcp, 0.0.0.0:5901->5901/tcp
```

### Port Accessibility
```bash
# Check if ports are listening
netstat -tuln | grep -E '6080|5901'
```

## Usage Workflows

### Basic Data Processing

```bash
# 1. Copy data to share
cp dataset.nrrd data/

# 2. Start container
./docker-slicer.sh start

# 3. Access web interface
./docker-slicer.sh open

# 4. In Slicer GUI, open /home/slicer/data/dataset.nrrd

# 5. Process and save results
# Save back to /home/slicer/data/

# 6. Check results on host
ls -la data/
```

### Running Slicer Scripts

```bash
# Run headless Python script
docker exec slicer-app-1 /opt/Slicer/bin/SlicerPython -c "
import slicer
# Your Python code here
"

# Or for .py script
docker cp myscript.py slicer-app-1:/home/slicer/
docker exec slicer-app-1 /opt/Slicer/bin/SlicerPython /home/slicer/myscript.py
```

### Interactive Shell

```bash
./docker-slicer.sh shell

# Inside container:
cd /home/slicer/data
/opt/Slicer/Slicer --version
```

### Cleanup and Maintenance

Runs the helper cleanup command to remove the container and related local Docker artifacts, including the built image.

```bash
./docker-slicer.sh clean
```

## Troubleshooting

### GPU Not Detected

```bash
# Check host GPU
nvidia-smi

# Check container GPU
docker exec slicer-gui-gpu nvidia-smi

# If empty, verify Docker GPU support
docker run --rm --gpus all nvidia/cuda:12.2.2-base-ubuntu22.04 nvidia-smi
```

**Solutions:**
- Reinstall NVIDIA Container Toolkit
- Update NVIDIA drivers
- Restart Docker daemon: `sudo systemctl restart docker` or `sudo service docker restart`

If `nvidia-smi` is missing on host, install matching host userspace packages:

```bash
apt-cache search '^nvidia-utils-|^libnvidia-gl-'
# Example for driver major 570:
sudo apt-get update
sudo apt-get install -y nvidia-utils-570 libnvidia-gl-570
sudo systemctl restart docker
```

If Slicer is still slow after the checks above, run the "Verify GPU Rendering Inside Slicer Python" test. `nvidia-smi` success alone does not guarantee OpenGL hardware rendering inside Slicer.

### Connection Refused

```bash
# Check if container is running
docker ps | grep slicer

# Check port bindings
docker port slicer-gui-gpu

# Restart container
./docker-slicer.sh restart
```

### Slow Performance

1. **Increase shared memory:**
   ```yaml
   shm_size: 8gb
   ```

2. **Check resource usage:**
   ```bash
   docker stats slicer-gui-gpu
   ```

3. **Reduce resolution or web browser window size**

4. **Monitor GPU:**
   ```bash
   docker exec slicer-gui-gpu watch -n 1 nvidia-smi
   ```

### User Permission Issues

```bash
# If files created inside container are inaccessible
docker exec slicer-gui-gpu sudo chown -R 1000:1000 /home/slicer/data
```

### Out of Memory

```bash
# Increase allocation
shm_size: 16gb
```

## Security Considerations

### For Production:

1. **Change default password:**
   ```bash
   docker exec -it slicer-gui-gpu vncpasswd
   ```

2. **Use reverse proxy with authentication:**
   ```nginx
   location /slicer {
       auth_basic "Slicer Access";
       proxy_pass http://localhost:6080;
   }
   ```

3. **Restrict port access:**
   ```bash
   docker run -p 127.0.0.1:6080:6080 ...
   ```

4. **Use VPN/SSH tunnel** for remote access

5. **Run security scan:**
   ```bash
   docker scan slicer-gui-gpu:latest
   ```

## References

- [3D Slicer Documentation](https://slicer.readthedocs.io/)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/)
- [noVNC GitHub](https://github.com/novnc/noVNC)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)

## Support

For issues:
1. Check logs: `./docker-slicer.sh logs`
2. Verify GPU: `./docker-slicer.sh gpu-check`
3. Check status: `./docker-slicer.sh status`
4. Consult troubleshooting section above

## 2. Docker Runtime Reference

## Service Endpoints

- noVNC web UI: http://localhost:6080/vnc.html
- Direct VNC: localhost:5901

## Runtime Configuration Summary

- Container name: `slicer-app-1`
- GPU runtime: `nvidia`
- Required env: `NVIDIA_VISIBLE_DEVICES`, `NVIDIA_DRIVER_CAPABILITIES`, `VNC_PASSWORD`
- Persistent volume: `slicer-home` -> `/home/slicer`
- Bind mount: `./data` -> `/home/slicer/data`
- Shared memory: `--shm-size=4gb` (increase if needed)

Authoritative values are in [docker-compose.yml](docker-compose.yml) and [.env.local.example](.env.local.example).

## Docker-Centric Diagnostics

```bash
# Container health and port mapping
docker compose ps
docker port slicer-app-1

# GPU visibility in container
docker exec slicer-app-1 nvidia-smi

# Runtime and GPU request check
docker inspect slicer-app-1 --format 'Runtime={{.HostConfig.Runtime}} DeviceRequests={{json .HostConfig.DeviceRequests}}'

# Live resource usage
docker stats slicer-app-1
```

If Slicer is slow even when `nvidia-smi` works, run the Slicer OpenGL renderer check in this README.

## Remote Access Patterns

### SSH tunnel

```bash
ssh -L 6080:localhost:6080 user@remote-host
```

Then open http://localhost:6080/vnc.html.

### Reverse proxy

Put a reverse proxy in front of port 6080 and keep websocket upgrade headers enabled.

### Cloudflare Tunnel

Use the Cloudflare section in this README for full configuration.

Quick status check:

```bash
./docker-slicer.sh tunnel
docker compose logs slicer | grep -i cloudflare
```

# Cloudflare Tunnel Setup Guide

Cloudflare Tunnel provides secure, encrypted access to your 3D Slicer instance without exposing ports directly to the internet. It's ideal for remote access and integrations with the slicercloudapp.

## Prerequisites

1. **Cloudflare Account**: Free or paid plan (free tier works)
2. **Domain**: Domain must be pointed to Cloudflare nameservers
3. **Docker Compose**: Already installed
4. **Tunnel Credentials**: Generated from Cloudflare dashboard

## Step 1: Create Cloudflare Account & Add Domain

1. Go to [Cloudflare](https://dash.cloudflare.com)
2. Sign up or log in
3. Add your domain
4. Cloudflare will provide nameservers to update at your registrar
5. Wait for nameserver propagation (up to 48 hours)

## Step 2: Create a Tunnel

### Via Cloudflare Dashboard (Recommended for Beginners)

1. Go to **Cloudflare Dashboard** → **Access** (Zero Trust) → **Tunnels**
2. Click **Create tunnel**
3. Choose connector type: **Cloudflared**
4. Name your tunnel: `slicer-gui-gpu` (or your preferred name)
5. Click **Save tunnel**
6. Skip the "Install connector" section (we use Docker)
7. Copy your **Tunnel ID**
8. Go to **Public Hostnames** and skip for now

### Via Cloudflare API (Advanced)

```bash
# Authenticate
cloudflared tunnel login

# Create tunnel
cloudflared tunnel create slicer-gui-gpu

# Get credentials
cat ~/.cloudflared/*.json
```

## Step 3: Get Your Tunnel Token

### Method 1: From Dashboard

1. In **Access** → **Tunnels**, select your tunnel
2. Click **Configure**
3. Copy the **Tunnel Token** from "Tunnel settings"

### Method 2: From CLI

```bash
# List tunnels
cloudflared tunnel list

# Show credentials
cat ~/.cloudflared/tunnel_id.json | jq .
```

## Step 4: Configure Environment Variables

Copy and edit `.env.local`:

```bash
cp .env.local.example .env.local
```

Edit `.env.local`:

```env
# Cloudflare Tunnel Configuration
CLOUDFLARE_TUNNEL_TOKEN=eyJhIjoiMTIzNDU2NaaaaaaaaaaaaaaaaaaaaaaaaaaaSIsInQiOiJ2MiJ9
CLOUDFLARE_TUNNEL_NAME=slicer-gui-gpu
CLOUDFLARE_TUNNEL_DOMAIN=slicer.example.com
```

**Where:**
- `CLOUDFLARE_TUNNEL_TOKEN`: Your tunnel token from Cloudflare dashboard
- `CLOUDFLARE_TUNNEL_NAME`: The name you gave the tunnel
- `CLOUDFLARE_TUNNEL_DOMAIN`: Your domain/subdomain (must be in Cloudflare DNS)

## Step 5: Configure DNS in Cloudflare

1. Go to **Cloudflare Dashboard** → **DNS**
2. Click **Add record**
3. Create CNAME record:
   - **Type**: CNAME
   - **Name**: `slicer` (or your subdomain)
   - **Target**: `tunnel-id.cfargotunnel.com`
   - **Proxy status**: Proxied (orange cloud)
4. Click **Save**

Or create A record:
   - **Type**: A
   - **Name**: `slicer.example.com`
   - **IPv4 Address**: `192.0.2.1` (any placeholder)
   - **Proxy status**: Proxied

## Step 6: Configure Tunnel Routing (Dashboard Method)

1. Go to **Access** → **Tunnels** → Select your tunnel
2. Click **Configure**
3. Go to **Public Hostnames**
4. Click **Add public hostname**
5. Fill in:
   - **Subdomain**: `slicer`
   - **Domain**: `example.com`
   - **Service**: HTTP
   - **URL**: `http://localhost:6080`
6. Click **Save**

## Step 7: Start Container with Cloudflare Tunnel

```bash
./docker-slicer.sh start
```

## Step 8: Verify Connection

1. Check logs:
   ```bash
   docker compose logs -f slicer
   ```

2. Look for success message:
   ```
   Starting Cloudflare Tunnel...
   INFO Registered tunnel connection connTunnelID=abc123...
   ```

3. Access your Slicer instance:
   ```
   https://slicer.example.com/vnc.html
   ```

## Testing & Troubleshooting

### Verify Tunnel Status

```bash
# Check if tunnel is running
docker compose exec slicer ps aux | grep cloudflared

# View tunnel logs
docker compose logs slicer | grep -i cloudflare
```

### Test Connection

```bash
# Local access still works
curl http://localhost:6080/

# From another machine
curl https://slicer.example.com/vnc.html
```

### Common Issues

#### "Error: 'cert.json' not found"
- **Solution**: Ensure `CLOUDFLARE_TUNNEL_TOKEN` is set correctly in `.env.local`
- Tokens should NOT be wrapped in quotes
- Check token format (should start with `eyJ`)

#### "Tunnel not authorized"
- **Solution**: Regenerate token from Cloudflare dashboard
- Clear old token: `rm .env.local && cp .env.local.example .env.local`
- Re-enter new token

#### "Connection refused on tunnel"
- **Solution**: Verify DNS is proxied (orange cloud) in Cloudflare dashboard
- Verify service URL is correct: `http://localhost:6080`
- Tunnel name and domain must match configuration

#### "404 Not Found"
- **Solution**: Check DNS record matches your configuration
- Verify subdomain matches tunnel config
- Ensure proxy is enabled for DNS record

## Advanced Configuration

### Custom Tunnel Configuration

Edit `.cloudflared/config.yml` inside container:

```bash
docker compose exec slicer bash
cat /home/slicer/.cloudflared/config.yml
```

### SSL/TLS Settings

In Cloudflare dashboard:
1. Go to **SSL/TLS** → **Overview**
2. Set minimum TLS version: **1.2**
3. Enable **HSTS** for additional security:
   - Max Age: `31536000`
   - Include subdomains: ✓

### Access Control (Cloudflare Teams)

Add authentication to your tunnel:

1. Go to **Access** → **Applications**
2. Click **Add application**
3. Select **Self-hosted** application
4. Set domain: `slicer.example.com`
5. Add authentication policy (Email, Single Sign-On, etc.)
6. Assign to tunnel

## Security Best Practices

1. **Enable Cloudflare Access** (Zero Trust):
   - Add authentication gateway
   - Require email verification
   - Implement SSO

2. **Rotate Tunnel Token**:
   ```bash
   # In Cloudflare dashboard: Tunnels → Select tunnel → Regenerate token
   ```

3. **Monitor Access**:
   - Check Cloudflare Analytics & Logs
   - Set up alerts for unusual activity

4. **Use Headers for Security**:
   In Cloudflare Dashboard → **Rules** → **Transform Rules**:
   ```
   Add header: X-Custom-Header = security-token
   ```

## Monitoring & Analytics

### In Cloudflare Dashboard

1. **Analytics & Logs**: View all requests to your tunnel
2. **Security**: Check blocked threats
3. **Performance**: Monitor latency and bandwidth

### Custom Logging

```bash
# View container logs with tunnel activity
docker compose logs -f slicer | grep -E "cloudflare|Tunnel"
```

## Cleanup

### Disable Tunnel (Keep Configuration)

```bash
# Just don't set CLOUDFLARE_TUNNEL_TOKEN
CLOUDFLARE_TUNNEL_TOKEN=
docker compose up -d
```

### Remove Tunnel (Delete Everything)

1. **In Cloudflare Dashboard**:
   - Go to **Access** → **Tunnels**
   - Select your tunnel
   - Click **Delete**

2. **Locally**:
   ```bash
   rm .cloudflared/
   ```

## References

- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Cloudflare Zero Trust](https://www.cloudflare.com/products/zero-trust/)
- [Cloudflare API Reference](https://developers.cloudflare.com/api/)

## Support

For issues:
1. Check Cloudflare dashboard for tunnel status
2. Review container logs: `docker compose logs slicer`
3. Verify DNS propagation: `nslookup slicer.example.com`
4. Test tunnel locally first: `curl http://localhost:6080`
