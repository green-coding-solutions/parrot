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

window_size() {
  # Print the window's current "WIDTHxHEIGHT", or nothing if unreadable.
  local window_id="$1"
  local geom width height

  geom="$(xdotool getwindowgeometry --shell "$window_id" 2>/dev/null || true)"
  width="$(printf '%s\n' "$geom" | awk -F= '/^WIDTH=/{print $2; exit}')"
  height="$(printf '%s\n' "$geom" | awk -F= '/^HEIGHT=/{print $2; exit}')"

  [[ "$width" =~ ^[0-9]+$ && "$height" =~ ^[0-9]+$ ]] || return 1
  printf '%s\n' "${width}x${height}"
}

echo "[position-window] requesting ${WINDOW_WIDTH}x${WINDOW_HEIGHT} at ${WINDOW_X},${WINDOW_Y} for window ${window_id}"
# Use RESOLUTION for the framebuffer so WM decorations (title bar etc.) have
# room above/below the client window and don't cause the WM to clip it.
_fb="${RESOLUTION:-${WINDOW_WIDTH}x${WINDOW_HEIGHT}}"
xrandr --fb "$_fb" 2>/dev/null || true

# Resize, then read the geometry back and retry. xdotool's windowsize sends a
# ConfigureRequest the WM (or the app, via size hints) is free to ignore or
# round, so the request "succeeding" tells us nothing — we must verify. Toolkit
# apps like xpdf (Motif/Xt) advertise resize increments, so the second pass
# uses --usehints, which sizes in those increments and often lands exactly when
# a raw pixel request gets snapped to a different value.
target="${WINDOW_WIDTH}x${WINDOW_HEIGHT}"
actual=""
for attempt in 1 2 3 4; do
  if (( attempt == 1 )); then
    xdotool windowsize "$window_id" "$WINDOW_WIDTH" "$WINDOW_HEIGHT" || true
  else
    xdotool windowsize --usehints "$window_id" "$WINDOW_WIDTH" "$WINDOW_HEIGHT" || true
  fi
  xdotool windowmove "$window_id" "$WINDOW_X" "$WINDOW_Y" || true
  # Give the WM a moment to apply the request before reading it back.
  sleep 0.5
  actual="$(window_size "$window_id" || true)"
  if [[ "$actual" == "$target" ]]; then
    echo "[position-window] window ${window_id} is ${actual}"
    exit 0
  fi
  echo "[position-window] attempt ${attempt}: window is ${actual:-unknown}, wanted ${target} — retrying"
done

echo "[position-window] WARNING: could not size window ${window_id} to ${target}; it is ${actual:-unknown}." >&2
echo "[position-window] WARNING: the window manager or the app likely overrode the request (e.g. resize increments or a maximised/constrained frame)." >&2
echo "[position-window] WARNING: check-image will fail on a size mismatch unless the reference was captured at ${actual:-this size}, or CHECK_SCALE_ON_MISMATCH=1 is set." >&2
# Don't fail the run here: replay.py treats positioning as best-effort
# (check=False), and a loud warning plus the later size-mismatch error is more
# useful than an opaque non-zero exit from this helper.
