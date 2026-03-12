#!/usr/bin/env bash
# Sets up the virtual display environment (Xvfb + window manager).
# Starts all processes in the background and exits so that the Green Metrics
# Tool can proceed to the flow commands.  The app itself is launched by
# replay.py via the #APP startcommand stored in the .🦜 recording file.
set -euo pipefail

export DISPLAY="${DISPLAY:-:99}"
export SCREEN_SIZE="${SCREEN_SIZE:-1440x900x24}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-root}"
export LANG="${LANG:-C.UTF-8}"

mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

display_num="${DISPLAY#:}"
display_num="${display_num%%.*}"
if [[ "$display_num" =~ ^[0-9]+$ ]]; then
  rm -f "/tmp/.X${display_num}-lock" "/tmp/.X11-unix/X${display_num}" 2>/dev/null || true
fi

echo "[entrypoint] starting Xvfb on ${DISPLAY} (${SCREEN_SIZE})"
Xvfb "$DISPLAY" -screen 0 "$SCREEN_SIZE" -ac +extension RANDR &
XVFB_PID=$!
sleep 1
if ! kill -0 "$XVFB_PID" 2>/dev/null; then
  echo "[entrypoint] Xvfb failed to start on ${DISPLAY}"
  exit 1
fi

echo "[entrypoint] starting window manager"
fluxbox >/tmp/fluxbox.log 2>&1 &
sleep 0.5

# VNC and noVNC are optional; set DEBUG=1 to enable them for live inspection.
if [[ "${DEBUG:-0}" == "1" ]]; then
  echo "[entrypoint] starting VNC server on :5900"
  x11vnc -display "$DISPLAY" -forever -shared -nopw -listen 0.0.0.0 -xkb >/tmp/x11vnc.log 2>&1 &
  echo "[entrypoint] starting noVNC on :6080"
  /usr/share/novnc/utils/novnc_proxy --vnc localhost:5900 --listen 6080 >/tmp/novnc.log 2>&1 &
fi

echo "[entrypoint] display environment ready on ${DISPLAY}"
