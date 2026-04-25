#!/bin/bash
# Quick reference for docker-slicer commands

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Use .env.local automatically when present so compose picks up local overrides.
COMPOSE_ENV_ARGS=()
if [[ -f .env.local ]]; then
    COMPOSE_ENV_ARGS+=(--env-file .env.local)
fi

docker_compose() {
    docker compose "${COMPOSE_ENV_ARGS[@]}" "$@"
}

# Help function
show_help() {
    echo "Docker Slicer Quick Commands"
    echo "============================"
    echo ""
    echo "Usage: ./docker-slicer.sh [command]"
    echo ""
    echo "Commands:"
    echo "  build       - Build the Docker image"
    echo "  start       - Start the container"
    echo "  stop        - Stop the running container"
    echo "  restart     - Restart the container"
    echo "  status      - Show container status and access info"
    echo "  logs        - Show container logs (follow)"
    echo "  shell       - Open a bash shell in the container"
    echo "  clean       - Remove container and image"
    echo "  gpu-check   - Check GPU and Vulkan availability in container"
    echo "  geom-check  - Show X11 screen/workarea geometry in container"
    echo "  open        - Open noVNC in browser (requires xdg-open)"
    echo "  ip          - Get container IP address"
    echo "  tunnel      - Show Cloudflare Tunnel status"
    echo ""
}

# Build function
build_image() {
    echo -e "${BLUE}Building Docker image...${NC}"
    docker_compose build
}

# Start function
start_container() {
    echo -e "${BLUE}Starting Slicer container...${NC}"
    docker_compose up -d
    echo -e "${GREEN}✓ Container started${NC}"
    show_access_info
}

# Stop function
stop_container() {
    echo -e "${BLUE}Stopping Slicer container...${NC}"
    docker_compose down
    echo -e "${GREEN}✓ Container stopped${NC}"
}

# Restart function
restart_container() {
    echo -e "${BLUE}Restarting Slicer container...${NC}"
    docker_compose restart
    echo -e "${GREEN}✓ Container restarted${NC}"
    show_access_info
}

# Status function
show_status() {
    echo -e "${BLUE}Container Status:${NC}"
    docker_compose ps
    echo ""
    show_access_info
}

# Logs function
show_logs() {
    echo -e "${BLUE}Following container logs (Ctrl+C to exit):${NC}"
    docker_compose logs -f slicer
}

# Shell function
open_shell() {
    echo -e "${BLUE}Opening bash shell in container...${NC}"
    docker_compose exec slicer bash
}

# Clean function
clean_all() {
    echo -e "${RED}WARNING: This will remove the container and image${NC}"
    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Removing containers...${NC}"
        docker_compose down -v
        echo -e "${BLUE}Removing image...${NC}"
        docker rmi slicer-gui-gpu:latest 2>/dev/null || true
        echo -e "${GREEN}✓ Cleanup complete${NC}"
    fi
}

# GPU check function
check_gpu() {
    echo -e "${BLUE}Checking GPU and Vulkan in container...${NC}"
    docker_compose exec slicer bash -lc '
        set +e

        echo "=== NVIDIA GPU Check ==="
        if command -v nvidia-smi >/dev/null 2>&1; then
            nvidia-smi -L || nvidia-smi
        else
            echo "[WARN] nvidia-smi not found in container"
        fi

        echo
        echo "=== Vulkan Check ==="
        if command -v vulkaninfo >/dev/null 2>&1; then
            vulkaninfo --summary 2>/dev/null | sed -n "1,120p"
            if [ "$?" -eq 0 ]; then
                echo "[OK] vulkaninfo completed"
            else
                echo "[FAIL] vulkaninfo failed"
            fi
        else
            echo "[WARN] vulkaninfo not found (install vulkan-tools to run full Vulkan test)"

            if ldconfig -p 2>/dev/null | grep -qi libvulkan; then
                echo "[OK] Vulkan loader library detected"
            else
                echo "[FAIL] Vulkan loader library not detected"
            fi

            if [ -f /etc/vulkan/icd.d/nvidia_icd.json ] || ls /usr/share/vulkan/icd.d/*.json >/dev/null 2>&1; then
                echo "[OK] Vulkan ICD manifest detected"
            else
                echo "[FAIL] Vulkan ICD manifest not detected"
            fi
        fi
    '
}

# Geometry check function
check_geometry() {
    echo -e "${BLUE}Checking X11 geometry in container...${NC}"
    docker_compose exec slicer bash -lc '
        set +e
        export DISPLAY=:1

        # Ensure EWMH geometry atoms are populated before reporting.
        if [ -x /usr/local/bin/fix-screen-geometry.sh ]; then
            /usr/local/bin/fix-screen-geometry.sh >/dev/null 2>&1 || true
        fi

        echo "=== RANDR Current Size ==="
        xrandr 2>/dev/null | grep -m1 "current" || echo "[WARN] xrandr output not available"

        echo
        echo "=== EWMH Root Properties ==="
        if command -v xprop >/dev/null 2>&1; then
            xprop -root _NET_WORKAREA 2>/dev/null || echo "[WARN] _NET_WORKAREA not set"
            xprop -root _NET_DESKTOP_GEOMETRY 2>/dev/null || echo "[WARN] _NET_DESKTOP_GEOMETRY not set"
            xprop -root _NET_DESKTOP_VIEWPORT 2>/dev/null || echo "[WARN] _NET_DESKTOP_VIEWPORT not set"
            xprop -root _NET_CURRENT_DESKTOP 2>/dev/null || echo "[WARN] _NET_CURRENT_DESKTOP not set"
        else
            echo "[WARN] xprop not found in container"
        fi
    '
}

# Open in browser
open_browser() {
    if command -v xdg-open &> /dev/null; then
        echo -e "${BLUE}Opening noVNC in browser...${NC}"
        xdg-open http://localhost:6080/vnc.html
    elif command -v open &> /dev/null; then
        echo -e "${BLUE}Opening noVNC in browser...${NC}"
        open http://localhost:6080/vnc.html
    else
        echo -e "${RED}Could not open browser. Visit: http://localhost:6080/vnc.html${NC}"
    fi
}

# Get IP function
get_ip() {
    echo -e "${BLUE}Container IP Address:${NC}"
    docker_compose exec slicer hostname -I
}

# Tunnel status function
tunnel_status() {
    echo -e "${BLUE}Cloudflare Tunnel Status:${NC}"
    if docker_compose logs slicer 2>/dev/null | grep -q "Cloudflare Tunnel"; then
        docker_compose logs slicer 2>/dev/null | grep -i "cloudflare\|tunnel" | tail -5
    else
        echo "Cloudflare Tunnel not configured or no recent activity"
    fi
}

# Show access info
show_access_info() {
    echo ""
    echo -e "${GREEN}=== Slicer Access Information ===${NC}"
    echo -e "Web Interface (noVNC): http://localhost:6080/vnc.html"
    echo -e "VNC Port: localhost:5901"
    echo -e "VNC Password: set via VNC_PASSWORD in .env"
    echo ""
}

# Main script logic
case "$1" in
    build)
        build_image
        ;;
    start)
        start_container
        ;;
    stop)
        stop_container
        ;;
    restart)
        restart_container
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    shell)
        open_shell
        ;;
    clean)
        clean_all
        ;;
    gpu-check)
        check_gpu
        ;;
    geom-check)
        check_geometry
        ;;
    open)
        open_browser
        ;;
    ip)
        get_ip
        ;;
    tunnel)
        tunnel_status
        ;;
    *)
        show_help
        exit 1
        ;;
esac
