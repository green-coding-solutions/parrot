#!/usr/bin/env bash
set -euo pipefail

export DISPLAY="${DISPLAY:-:99}"
export SCREEN_SIZE="${SCREEN_SIZE:-1280x800x24}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-root}"
export LANG="${LANG:-C.UTF-8}"
APP_LOG_FILE="${APP_LOG_FILE:-/tmp/app.log}"
APP_START_BIN="${APP_STARTCOMMAND%% *}"

if [[ -z "$APP_START_BIN" ]]; then
  echo "[entrypoint] APP_STARTCOMMAND is empty"
  exit 2
fi

if ! command -v "$APP_START_BIN" >/dev/null 2>&1; then
  echo "[entrypoint] app start command not found in PATH: ${APP_START_BIN}"
  echo "[entrypoint] APP_STARTCOMMAND=${APP_STARTCOMMAND}"
  exit 127
fi

mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

# Some apps (for example VLC) may be launched as a non-root user while the
# container entrypoint runs as root. Pre-create a per-user runtime dir so
# XDG_RUNTIME_DIR can be reassigned safely.
if id -u vlcuser >/dev/null 2>&1; then
  install -d -m 0700 -o vlcuser -g vlcuser /tmp/runtime-vlcuser
fi

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
  wait "$XVFB_PID"
fi

echo "[entrypoint] starting window manager"
fluxbox >/tmp/fluxbox.log 2>&1 &
FLUXBOX_PID=$!

echo "[entrypoint] starting VNC server on :5900"
x11vnc -display "$DISPLAY" -forever -shared -nopw -listen 0.0.0.0 -xkb >/tmp/x11vnc.log 2>&1 &
X11VNC_PID=$!

echo "[entrypoint] starting noVNC on :6080"
/usr/share/novnc/utils/novnc_proxy --vnc localhost:5900 --listen 6080 >/tmp/novnc.log 2>&1 &
NOVNC_PID=$!

sleep 2

echo "[entrypoint] launching app: ${APP_STARTCOMMAND}"
dbus-run-session -- bash -lc "${APP_STARTCOMMAND}" >"${APP_LOG_FILE}" 2>&1 &
APP_PID=$!

if [[ "${AUTO_POSITION:-1}" == "1" ]]; then
  echo "[entrypoint] applying fixed window geometry"
  /usr/local/bin/position-window.sh || true
fi

cleanup() {
  echo "[entrypoint] stopping background processes"
  kill "$APP_PID" "$NOVNC_PID" "$X11VNC_PID" "$FLUXBOX_PID" "$XVFB_PID" 2>/dev/null || true
}

trap cleanup EXIT INT TERM

wait "$APP_PID"
