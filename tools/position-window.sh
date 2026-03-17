#!/usr/bin/env bash
set -euo pipefail

export DISPLAY="${DISPLAY:-:99}"
WINDOW_X="${WINDOW_X:-20}"
WINDOW_Y="${WINDOW_Y:-20}"
WINDOW_WIDTH="${WINDOW_WIDTH:-1400}"
WINDOW_HEIGHT="${WINDOW_HEIGHT:-857}"
APP_WINDOW_CLASS="${APP_WINDOW_CLASS:-gnome-calculator}"
APP_WINDOW_TITLE="${APP_WINDOW_TITLE:-Calculator}"

echo "[position-window] waiting for app window on ${DISPLAY} (class=${APP_WINDOW_CLASS} title=${APP_WINDOW_TITLE})"

window_area() {
  local window_id="$1"
  local geom width height

  geom="$(xdotool getwindowgeometry --shell "$window_id" 2>/dev/null || true)"
  width="$(printf '%s\n' "$geom" | awk -F= '/^WIDTH=/{print $2; exit}')"
  height="$(printf '%s\n' "$geom" | awk -F= '/^HEIGHT=/{print $2; exit}')"

  if [[ ! "$width" =~ ^[0-9]+$ || ! "$height" =~ ^[0-9]+$ ]]; then
    return 1
  fi

  printf '%s\n' "$((width * height))"
}

find_matching_window() {
  local flag="$1"
  local value="$2"
  local window_id area
  local best_id=""
  local best_area=-1

  while IFS= read -r window_id; do
    [[ -n "$window_id" ]] || continue
    area="$(window_area "$window_id" || echo 0)"
    if (( area > best_area )); then
      best_area="$area"
      best_id="$window_id"
    fi
  done < <(xdotool search --onlyvisible "$flag" "$value" 2>/dev/null || true)

  [[ -n "$best_id" ]] || return 1
  printf '%s\n' "$best_id"
}

window_id=""
for _ in $(seq 1 60); do
  if [[ -n "$APP_WINDOW_CLASS" ]]; then
    if window_id="$(find_matching_window --class "$APP_WINDOW_CLASS")"; then
      break
    fi
  fi

  if [[ -n "$APP_WINDOW_TITLE" ]]; then
    if window_id="$(find_matching_window --name "$APP_WINDOW_TITLE")"; then
      break
    fi
  fi

  sleep 0.5
done

if [[ -z "$window_id" ]]; then
  echo "[position-window] app window not found"
  exit 1
fi

echo "[position-window] setting ${WINDOW_WIDTH}x${WINDOW_HEIGHT} at ${WINDOW_X},${WINDOW_Y} for window ${window_id}"
xrandr --fb "${WINDOW_WIDTH}x${WINDOW_HEIGHT}" 2>/dev/null || true
xdotool windowsize "$window_id" "$WINDOW_WIDTH" "$WINDOW_HEIGHT" || true
xdotool windowmove "$window_id" "$WINDOW_X" "$WINDOW_Y" || true

# Give the WM a moment to settle before any follow-up automation.
sleep 0.5
