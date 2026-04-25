# 3D Slicer GPU Docker Setup - Complete Package

This directory contains everything needed to run 3D Slicer with NVIDIA GPU acceleration and web-based noVNC GUI access.

## Files Overview

### Core Docker Files

- **[Dockerfile](Dockerfile)** - Docker image definition with:
  - NVIDIA CUDA 12.2 base image
  - 3D Slicer 5.10.0 installation
  - TigerVNC server
  - noVNC web interface
  - Xvfb virtual display
  - Automatic startup scripts

- **[docker-compose.yml](docker-compose.yml)** - Docker Compose configuration:
  - Service definition
  - Port mappings (6080 for noVNC, 5901 for VNC)
  - Volume management
  - GPU runtime configuration
  - Resource limits

### Helper Scripts

- **[docker-slicer.sh](docker-slicer.sh)** - Bash script with commands:
  ```bash
  chmod +x docker-slicer.sh
  ./docker-slicer.sh build
  ./docker-slicer.sh start
  ```

- **Makefile**: [Makefile](Makefile) - For Unix-like systems:
  ```bash
  make build
  make start
  make status
  ```

### Configuration Files

- **[.env.example](.env.example)** - Environment variables template:
  - Slicer version
  - VNC settings
  - Display configuration
  - Resource allocation

- **[.dockerignore](.dockerignore)** - Docker build exclusions

### Documentation

- **[DOCKER_README.md](DOCKER_README.md)** - Docker-specific documentation:
  - Prerequisites
  - Installation instructions
  - Usage examples
  - Configuration options
  - Troubleshooting
  - Network access setup

- **[SETUP_GUIDE.md](SETUP_GUIDE.md)** - Complete setup guide:
  - System requirements
  - Prerequisites setup (Linux, macOS)
  - Building instructions
  - Running the container
  - Verification steps
  - Integration with slicercloudapp
  - Kubernetes deployment examples
  - Advanced troubleshooting

- **[architecture.md](architecture.md)** - Project architecture notes

## Quick Start

### Prerequisites Check

```bash
# Verify Docker installation
docker --version

# Verify NVIDIA Container Toolkit / Docker GPU support
docker run --rm --gpus all nvidia/cuda:12.2.2-base-ubuntu22.04 nvidia-smi
```

### 1. Build (First Time Only)

```bash
chmod +x docker-slicer.sh
./docker-slicer.sh build
# Or with Make:
make build
# Or with Docker Compose directly:
docker compose build
```

### 2. Start Container

```bash
./docker-slicer.sh start
# Or:
make start
# Or:
docker compose up -d
```

### 3. Access Slicer

Open browser: **http://localhost:6080/vnc.html**

Enter password: **slicer123**

### 4. Stop Container

```bash
./docker-slicer.sh stop
# Or:
make stop
# Or:
docker compose down
```

## Key Features

✓ **NVIDIA GPU Support**
  - CUDA 12.2 for accelerated computation
  - Compute and graphics rendering
  - GPU memory allocation via shared memory

✓ **Web-Based GUI**
  - noVNC accessible at http://localhost:6080/vnc.html
  - No VNC client installation required
  - Works on any device with a browser

✓ **Cloudflare Tunnel**
  - Secure remote access without port exposure
  - Zero Trust security
  - Free tier available
  - Setup guide: [CLOUDFLARE_TUNNEL.md](CLOUDFLARE_TUNNEL.md)

✓ **Virtual Display**
  - Xvfb virtual X11 server
  - 1920x1080 resolution (configurable)
  - 24-bit color depth

✓ **Data Sharing**
  - Mount local directory as `/home/slicer/data`
  - Easy file transfer between host and container
  - Persistent data storage

✓ **Security**
  - Non-root user (slicer)
  - VNC password protection
  - Configurable access controls

## Port Mappings

| Port | Service | Purpose |
|------|---------|---------|
| 6080 | noVNC HTTP | Web-based GUI |
| 5901 | VNC Server | Direct VNC viewer |

## Access Methods

### 1. Web Browser (Recommended)
- URL: http://localhost:6080/vnc.html
- No client required
- Works on mobile devices

### 2. VNC Viewer
- Address: localhost:5901
- Clients: TigerVNC, RealVNC, TightVNC
- Better performance for local networks

### 3. SSH Tunnel (Remote)
```bash
ssh -L 6080:localhost:6080 user@remote-server
# Then access: http://localhost:6080/vnc.html
```

### 4. Reverse Proxy (Production)
Set up Nginx/Apache with authentication

## Common Commands

### Check Status
```bash
./docker-slicer.sh status
# or
docker compose ps
```

### View Logs
```bash
./docker-slicer.sh logs
# or
docker compose logs -f slicer
```

### Open Shell
```bash
./docker-slicer.sh shell
# or
docker compose exec slicer bash
```

### Verify GPU
```bash
./docker-slicer.sh gpu-check
# or
docker exec slicer-app-1 nvidia-smi
```

## Configuration

### Change VNC Password

1. Inside running container:
   ```bash
   docker exec -it slicer-gui-gpu bash
   vncpasswd
   ```

2. Or edit Dockerfile:
   ```dockerfile
   RUN vncpasswd -f <<< "newpassword" > /home/slicer/.vnc/passwd
   ```

### Adjust Display Resolution

Edit Dockerfile, find line:
```dockerfile
Xvfb :99 -screen 0 1920x1080x24 &
```

Change `1920x1080` to desired size:
- `1024x768` - Low bandwidth
- `1600x1200` - Balanced
- `2560x1440` - High quality

### Share Files

```bash
# Files in ./data are accessible at /home/slicer/data
mkdir -p data
cp myfile.nrrd data/

# Inside Slicer: File > Open > /home/slicer/data/myfile.nrrd
```

### Increase GPU Memory

Edit `docker-compose.yml`:
```yaml
shm_size: 8gb  # Increase from 4gb
```

## Troubleshooting

### GPU Not Detected
```bash
# Check host GPU
nvidia-smi

# Check container GPU
docker exec slicer-gui-gpu nvidia-smi

# If not working:
docker run --rm --gpus all nvidia/cuda:12.2.2-base-ubuntu22.04 nvidia-smi
```

### Can't Connect on Port 6080
```bash
# Check container is running
docker ps | grep slicer

# Check port binding
docker port slicer-gui-gpu

# Restart container
./docker-slicer.sh restart
```

### Slow Remote Access
- Lower display resolution (see Configuration section)
- Increase network bandwidth
- Use VNC viewer instead of web interface
- Check GPU usage: `docker stats`

### Out of Memory
- Increase shm_size in docker-compose.yml
- Check running processes: `docker exec slicer-gui-gpu top`
- Reduce Slicer memory usage via preferences

See [DOCKER_README.md](DOCKER_README.md) for more troubleshooting.

## Integration with slicercloudapp

### Data Pipeline

1. **Input**: Mount data directory
   ```yaml
   volumes:
     - ./data:/home/slicer/data
   ```

2. **Processing**: Run Slicer via GUI or scripts
   ```bash
   docker exec slicer-gui-gpu /opt/Slicer/bin/SlicerPython script.py
   ```

3. **Output**: Results saved to shared volume
   ```bash
   # Retrieve results
   ls -la data/results/
   ```

### Directus Integration

Store input/output paths in Directus:
- Input: `/home/slicer/data/input/` 
- Output: `/home/slicer/data/output/`

### Backend API

```python
# Trigger Slicer processing
POST /api/slicer/process
{
  "input_file": "dataset.nrrd",
  "algorithm": "segmentation",
  "parameters": {...}
}

# Check results
GET /api/slicer/results/job_id
```

## System Requirements

### Minimum
- 8GB RAM
- 20GB disk space
- NVIDIA GPU with compute capability 3.0+
- Docker 20.10+

### Recommended
- 16GB+ RAM
- 50GB disk space
- RTX series GPU
- Latest NVIDIA drivers

## Version Information

- **3D Slicer**: 5.10.0
- **CUDA**: 12.2.2
- **cuDNN**: Latest for CUDA 12.2
- **Ubuntu**: 22.04 LTS
- **Python**: 3.10
- **Docker**: 20.10+
- **NVIDIA Container Toolkit**: Latest

## Support Resources

- [3D Slicer Documentation](https://slicer.readthedocs.io/)
- [3D Slicer Download](https://download.slicer.org/)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/)
- [noVNC GitHub](https://github.com/novnc/noVNC)
- [Docker Documentation](https://docs.docker.com/)

## Advanced Usage

See [SETUP_GUIDE.md](SETUP_GUIDE.md) for:
- Kubernetes deployment on OVH Cloud
- Advanced troubleshooting
- Performance optimization
- Security hardening
- Multi-container orchestration
- Automated processing workflows

## License

3D Slicer: BSD License
Docker configuration: MIT License

---

**For detailed setup instructions**, see [SETUP_GUIDE.md](SETUP_GUIDE.md)

**For Docker-specific information**, see [DOCKER_README.md](DOCKER_README.md)

**For quick commands**, use the provided scripts:
- `./docker-slicer.sh help` - Bash helper script
- `make help` - Makefile
