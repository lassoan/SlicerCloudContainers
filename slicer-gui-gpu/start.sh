#!/bin/bash
set -e

CLOUDFLARE_PID=""

if [ -z "${VNC_PASSWORD}" ]; then
    echo "ERROR: VNC_PASSWORD is not set. Set it in the .env file."
    exit 1
fi
mkdir -p /home/slicer/.vnc
printf '%s\n' "${VNC_PASSWORD}" | vncpasswd -f > /home/slicer/.vnc/passwd
chmod 600 /home/slicer/.vnc/passwd

cleanup_stale_vnc_display() {
  local display_num="1"
  local lock_file="/tmp/.X${display_num}-lock"
  local socket_file="/tmp/.X11-unix/X${display_num}"

  if [ -f "${lock_file}" ]; then
    local lock_pid
    lock_pid=$(cat "${lock_file}" 2>/dev/null | tr -d '[:space:]')
    if [ -n "${lock_pid}" ] && kill -0 "${lock_pid}" 2>/dev/null; then
      echo "VNC display :${display_num} appears active (pid ${lock_pid})"
    else
      echo "Removing stale VNC lock/socket for display :${display_num}"
      rm -f "${lock_file}" "${socket_file}"
    fi
  elif [ -S "${socket_file}" ]; then
    echo "Removing stale VNC socket for display :${display_num}"
    rm -f "${socket_file}"
  fi
}

cleanup_stale_vnc_display

# Use environment variables for display dimensions, with fallback defaults
DISPLAY_WIDTH=${DISPLAY_WIDTH:-1920}
DISPLAY_HEIGHT=${DISPLAY_HEIGHT:-1080}
GEOMETRY="${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}"

echo "Starting VNC server on :1 with geometry ${GEOMETRY}..."
Xtigervnc :1 -geometry "${GEOMETRY}" -depth 24 \
    -rfbport 5901 -rfbauth /home/slicer/.vnc/passwd \
    -localhost no -desktop Slicer &
VNC_PID=$!
sleep 2

if ! kill -0 "$VNC_PID" 2>/dev/null; then
  echo "ERROR: Xtigervnc failed to start"
  ls -la /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true
  exit 1
fi

export DISPLAY=:1
xsetroot -solid grey || true

# Prime EWMH geometry to current framebuffer before launching Qt app.
/usr/local/bin/fix-screen-geometry.sh >/dev/null 2>&1 || true

echo ""
echo "=== GPU Diagnostics ==="
echo "--- nvidia-smi ---"
nvidia-smi 2>&1 || echo "nvidia-smi failed"
echo "--- NVIDIA EGL driver ---"
ls /usr/lib/x86_64-linux-gnu/libEGL_nvidia* 2>/dev/null \
    && echo "NVIDIA EGL: present" \
    || echo "NVIDIA EGL: NOT found — GPU rendering will fall back to software"
echo "--- OpenGL (software path, expected: llvmpipe) ---"
glxinfo 2>&1 | grep -E "OpenGL renderer" || echo "glxinfo failed"
echo "--- OpenGL via VirtualGL EGL (should show NVIDIA) ---"
vglrun -d egl glxinfo 2>&1 | grep -E "OpenGL renderer|OpenGL vendor" || echo "vglrun EGL check failed"
echo "--- NVIDIA env ---"
echo "  NVIDIA_VISIBLE_DEVICES=${NVIDIA_VISIBLE_DEVICES}"
echo "  NVIDIA_DRIVER_CAPABILITIES=${NVIDIA_DRIVER_CAPABILITIES}"
echo "======================="
echo ""

# Root page: redirect directly to vnc.html — loading noVNC inside an iframe causes
# it to read wrong viewport dimensions, sending a broken SetDesktopSize on connect.
cat > /opt/novnc/index.html << 'HTML'
<!DOCTYPE html>
<html>
<head>
  <meta http-equiv="refresh" content="0;url=vnc.html?autoconnect=1&reconnect=1&resize=remote&show_dot=1">
  <title>Slicer</title>
</head>
<body></body>
</html>
HTML

echo "Starting noVNC on port 6080..."
python3 -m websockify --web /opt/novnc 6080 localhost:5901 &
NOVNC_PID=$!

if [ -n "${CLOUDFLARE_TUNNEL_TOKEN}" ]; then
    echo "Starting Cloudflare Tunnel..."
    cloudflared tunnel run --token "${CLOUDFLARE_TUNNEL_TOKEN}" &
    CLOUDFLARE_PID=$!
    sleep 2
fi

echo "Starting 3D Slicer..."
if command -v vglrun &>/dev/null; then
    echo "  GPU acceleration: VirtualGL EGL"
    vglrun -d egl /opt/Slicer/Slicer --no-splash &
else
    echo "  WARNING: vglrun not found, using software rendering"
    /opt/Slicer/Slicer --no-splash &
fi
SLICER_PID=$!

# Initial resize: blocks until Slicer's window appears, then immediately fills the display.
# This covers the gap between Slicer opening and the poll loop's next tick.
(
  WIN=$(xdotool search --sync --class "Slicer" 2>/dev/null \
        || xdotool search --sync --name "Slicer" 2>/dev/null)
  WIN=$(echo "$WIN" | head -1)
  if [ -n "$WIN" ]; then
    SIZE=$(xrandr 2>/dev/null \
        | grep -m1 'current' \
        | grep -oP 'current \K\d+ x \d+' \
        | tr -d ' ')
    W=$(echo "$SIZE" | cut -dx -f1)
    H=$(echo "$SIZE" | cut -dx -f2)
    echo "[initial-resize] Slicer window appeared (wid=$WIN), resizing to ${W}x${H}"
    xdotool windowmove "$WIN" 0 0
    xdotool windowsize "$WIN" "$W" "$H"
  fi
) &

# Keep Slicer filling the display — runs continuously so it reacts to remote resizes.
# APPLIED_SIZE is only updated when xdotool actually finds and resizes the window,
# so the loop keeps retrying until Slicer opens.
(
  APPLIED_SIZE=""
  RETRY_COUNT=0
  while true; do
    # Extract only the "current NxN" dimensions — \K drops everything before the match
    SIZE=$(xrandr 2>/dev/null \
        | grep -m1 'current' \
        | grep -oP 'current \K\d+ x \d+' \
        | tr -d ' ')          # → "1920x1080"

    if [ -n "$SIZE" ] && [ "$SIZE" != "$APPLIED_SIZE" ]; then
      W=$(echo "$SIZE" | cut -dx -f1)
      H=$(echo "$SIZE" | cut -dx -f2)

      # Try every likely identifier for Slicer's window
      WIN=""
      for PATTERN in "Slicer" "slicer" "3D Slicer"; do
        WIN=$(xdotool search --onlyvisible --class "$PATTERN" 2>/dev/null | head -1)
        [ -n "$WIN" ] && { break; }
        WIN=$(xdotool search --onlyvisible --name "$PATTERN" 2>/dev/null | head -1)
        [ -n "$WIN" ] && { break; }
      done

      if [ -n "$WIN" ]; then
        echo "[resize] Resizing wid=$WIN to ${W}x${H}"
        xdotool windowmove "$WIN" 0 0
        xdotool windowsize "$WIN" "$W" "$H"
        # Sync X11 screen geometry to fix popup positioning issues
        # This ensures Qt applications refresh their geometry cache
        /usr/local/bin/fix-screen-geometry.sh >/dev/null 2>&1 &
        APPLIED_SIZE="$SIZE"
        RETRY_COUNT=0
      else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        # Keep logs concise: print only the first miss and every 10 retries after that.
        if [ "$RETRY_COUNT" -eq 1 ] || [ $((RETRY_COUNT % 10)) -eq 0 ]; then
          echo "[resize] Waiting for Slicer window to apply ${W}x${H} (retry ${RETRY_COUNT})"
        fi
      fi
    fi
    sleep 1
  done
) &
RESIZE_PID=$!

cleanup() {
    echo "Shutting down..."
    [ -n "$CLOUDFLARE_PID" ] && kill $CLOUDFLARE_PID 2>/dev/null || true
    kill $RESIZE_PID 2>/dev/null || true
    kill $SLICER_PID 2>/dev/null || true
    kill $NOVNC_PID 2>/dev/null || true
    kill $VNC_PID 2>/dev/null || true
    exit 0
}
trap cleanup SIGINT SIGTERM

echo ""
echo "========================================"
echo "3D Slicer with noVNC is running!"
echo "========================================"
echo ""
echo "Local Access:"
echo "  Web browser: http://localhost:6080"
echo "  VNC Port: 5901"
[ -n "${CLOUDFLARE_TUNNEL_TOKEN}" ] && echo "  Cloudflare Tunnel: Active" || echo "  Cloudflare Tunnel: Not configured"
echo ""
echo "Waiting for processes..."
wait
