# 3D Slicer GPU-Accelerated Cloud Container Setup Guide

This guide provides comprehensive instructions for building and deploying the 3D Slicer Docker container with NVIDIA GPU support and noVNC GUI access for the slicercloudapp project.

## Quick Start

```bash
# Make the helper script executable
chmod +x docker-slicer.sh

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
sudo nvidia-ctk runtime configure --runtime=docker
if command -v systemctl >/dev/null 2>&1; then
  sudo systemctl restart docker
else
  sudo service docker restart
fi

# 3. Add current user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

## Building the Docker Image

### Option 1: Docker Compose (Recommended)

```bash
# Copy environment variables
cp .env.local.example .env.local

# Build the image
docker compose build

# Or use the helper script
./docker-slicer.sh build
```

### Option 2: Direct Docker Build

```bash
docker build -t slicer-gui-gpu:latest .
```

### Build Output
Expected output shows downloading Slicer (3-5 minutes) and installing dependencies:
```
Step 1/XX : FROM nvidia/cuda:12.2.2-cudnn8-devel-ubuntu22.04
 ---> [hash]
Step 2/XX : ENV DEBIAN_FRONTEND=noninteractive
 ...
```

## Running the Container

### Option 1: Docker Compose

```bash
# Start container in background
docker compose up -d

# View logs
docker compose logs -f slicer

# Stop container
docker compose down

# Stop and remove all data
docker compose down -v
```

### Option 2: Docker CLI

```bash
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
```

### Option 3: Helper Script

```bash
./docker-slicer.sh start
```

## Accessing 3D Slicer

### Web Browser (Recommended)
1. Open browser: http://localhost:6080/vnc.html
2. Enter password: `slicer123`
3. Click "Connect"

### VNC Viewer
1. Download VNC viewer (TigerVNC, RealVNC, etc.)
2. Connect to: `localhost:5901`
3. Password: `slicer123`

### SSH Tunnel (for remote access)
```bash
ssh -L 6080:localhost:6080 user@remote-server
# Then access: http://localhost:6080/vnc.html
```

## Configuration

### Change VNC Password

Edit the Dockerfile startup script and modify:
```dockerfile
RUN vncpasswd -f <<< "yournewpassword" > /home/slicer/.vnc/passwd
```

Or inside running container:
```bash
docker exec -it slicer-gui-gpu bash
vncpasswd
```

### Adjust Display Resolution

Edit Dockerfile, change:
```dockerfile
Xvfb :99 -screen 0 1920x1080x24 &
```

Common resolutions:
- `1024x768` - Low bandwidth
- `1600x1200` - Balanced
- `2560x1440` - High quality

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

### Container Status
```bash
./docker-slicer.sh status
# Or manually:
docker compose ps
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

## Integration with slicercloudapp

### Backend API Integration

1. **Data Exchange**: Mount project data volume
   ```yaml
   volumes:
     - ./data:/home/slicer/data
   ```

2. **Result Retrieval**: Store outputs in mounted directory

3. **Communication**: Use mounted volume or direct REST API calls

### Directus Integration

Configure Slicer to read/write files that sync with Directus:

```bash
# Mount both data and processing directories
volumes:
  - ./data:/home/slicer/input_data
  - ./results:/home/slicer/results
```

### Kubernetes Deployment (OVH Cloud)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: slicer-gui-gpu-pod
spec:
  containers:
  - name: slicer
    image: slicer-gui-gpu:latest
    ports:
    - containerPort: 6080
    - containerPort: 5901
    resources:
      limits:
        nvidia.com/gpu: 1
        memory: "16Gi"
      requests:
        nvidia.com/gpu: 1
        memory: "8Gi"
    volumeMounts:
    - name: data
      mountPath: /home/slicer/data
  runtimeClassName: nvidia
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: slicer-data-pvc
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

3. **Lower display resolution** for remote connections

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

## Cleanup and Maintenance

### Remove Container Only
```bash
./docker-slicer.sh stop
docker compose rm slicer
```

### Remove Image
```bash
docker rmi slicer-gui-gpu:latest
```

### Complete Cleanup
```bash
./docker-slicer.sh clean
```

### Prune Unused Resources
```bash
docker system prune -a
```

## Performance Benchmarks

On NVIDIA RTX 3090 / 16GB RAM:
- **Startup**: ~15-20 seconds
- **Web UI Load**: ~2-3 seconds
- **GPU Recognition**: Instant
- **Heavy Processing**: Native GPU performance

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
