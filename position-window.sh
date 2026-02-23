#!/usr/bin/env bash
set -euo pipefail

export DISPLAY="${DISPLAY:-:99}"
WINDOW_X="${WINDOW_X:-20}"
WINDOW_Y="${WINDOW_Y:-20}"
WINDOW_WIDTH="${WINDOW_WIDTH:-420}"
WINDOW_HEIGHT="${WINDOW_HEIGHT:-620}"
APP_WINDOW_CLASS="${APP_WINDOW_CLASS:-gnome-calculator}"
APP_WINDOW_TITLE="${APP_WINDOW_TITLE:-Calculator}"

echo "[position-window] waiting for app window on ${DISPLAY} (class=${APP_WINDOW_CLASS} title=${APP_WINDOW_TITLE})"

window_id=""
for _ in $(seq 1 60); do
  if [[ -n "$APP_WINDOW_CLASS" ]]; then
    if window_id="$(xdotool search --onlyvisible --class "$APP_WINDOW_CLASS" 2>/dev/null | head -n1)"; then
      if [[ -n "$window_id" ]]; then
        break
      fi
    fi
  fi

  if [[ -n "$APP_WINDOW_TITLE" ]]; then
    if window_id="$(xdotool search --onlyvisible --name "$APP_WINDOW_TITLE" 2>/dev/null | head -n1)"; then
      if [[ -n "$window_id" ]]; then
        break
      fi
    fi
  fi

  sleep 0.5
done

if [[ -z "$window_id" ]]; then
  echo "[position-window] app window not found"
  exit 1
fi

echo "[position-window] setting ${WINDOW_WIDTH}x${WINDOW_HEIGHT} at ${WINDOW_X},${WINDOW_Y} for window ${window_id}"
xdotool windowsize "$window_id" "$WINDOW_WIDTH" "$WINDOW_HEIGHT" || true
xdotool windowmove "$window_id" "$WINDOW_X" "$WINDOW_Y" || true

# Give the WM a moment to settle before any follow-up automation.
sleep 0.5
