#!/usr/bin/env bash
set -euo pipefail

ref_name="${1:-}"
if [[ -z "$ref_name" ]]; then
  echo "[check-image] Usage: check-image.sh <reference.png>" >&2
  exit 2
fi

case "$ref_name" in
  /*) ref_path="$ref_name" ;;
  *)  ref_path="/recordings/$ref_name" ;;
esac

if [[ ! -f "$ref_path" ]]; then
  echo "[check-image] Reference image not found: $ref_path" >&2
  exit 2
fi

export DISPLAY="${DISPLAY:-:99}"
CHECK_MAX_RMSE="${CHECK_MAX_RMSE:-0.01}"
CHECK_IGNORE_RECT="${CHECK_IGNORE_RECT:-}"
APP_WINDOW_CLASS="${APP_WINDOW_CLASS:-gnome-calculator}"
APP_WINDOW_TITLE="${APP_WINDOW_TITLE:-Calculator}"

find_app_window() {
  local win=""
  if [[ -n "$APP_WINDOW_CLASS" ]]; then
    win="$(xdotool search --onlyvisible --class "$APP_WINDOW_CLASS" 2>/dev/null | head -n1 || true)"
  fi
  if [[ -z "$win" && -n "$APP_WINDOW_TITLE" ]]; then
    win="$(xdotool search --onlyvisible --name "$APP_WINDOW_TITLE" 2>/dev/null | head -n1 || true)"
  fi
  [[ -n "$win" ]] || return 1
  printf '%s\n' "$win"
}

win_id="$(find_app_window)" || {
  echo "[check-image] app window not found (class=${APP_WINDOW_CLASS}, title=${APP_WINDOW_TITLE})" >&2
  exit 2
}

tmp_dir="$(mktemp -d)"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT

actual_raw="$tmp_dir/actual.png"
actual_cmp="$tmp_dir/actual_cmp.png"
ref_cmp="$tmp_dir/ref_cmp.png"

# Capture the current app window image.
import -window "$win_id" "$actual_raw"
cp "$actual_raw" "$actual_cmp"
cp "$ref_path" "$ref_cmp"

ref_size="$(identify -format '%wx%h' "$ref_cmp")"
actual_size="$(identify -format '%wx%h' "$actual_cmp")"
if [[ "$ref_size" != "$actual_size" ]]; then
  echo "[check-image] size mismatch: actual=$actual_size ref=$ref_size" >&2
  exit 1
fi

if [[ -n "$CHECK_IGNORE_RECT" ]]; then
  IFS=';' read -r -a rects <<< "$CHECK_IGNORE_RECT"
  for rect in "${rects[@]}"; do
    [[ -n "$rect" ]] || continue
    IFS=',' read -r x y w h <<< "$rect"
    if [[ -z "${x:-}" || -z "${y:-}" || -z "${w:-}" || -z "${h:-}" ]]; then
      echo "[check-image] invalid CHECK_IGNORE_RECT rectangle: $rect" >&2
      exit 2
    fi
    x2=$((x + w - 1))
    y2=$((y + h - 1))
    mogrify -fill black -draw "rectangle ${x},${y} ${x2},${y2}" "$actual_cmp"
    mogrify -fill black -draw "rectangle ${x},${y} ${x2},${y2}" "$ref_cmp"
  done
fi

metric_out="$(compare -metric RMSE "$actual_cmp" "$ref_cmp" null: 2>&1 >/dev/null || true)"
rmse_norm="$(printf '%s\n' "$metric_out" | sed -n 's/.*(\([0-9.][0-9.]*\)).*/\1/p' | head -n1)"

if [[ -z "$rmse_norm" ]]; then
  echo "[check-image] could not parse compare output: $metric_out" >&2
  exit 2
fi

if awk -v actual="$rmse_norm" -v max="$CHECK_MAX_RMSE" 'BEGIN { exit (actual <= max ? 0 : 1) }'; then
  echo "[check-image] PASS ref=$(basename "$ref_path") rmse=${rmse_norm} max=${CHECK_MAX_RMSE}"
  exit 0
fi

echo "[check-image] FAIL ref=$(basename "$ref_path") rmse=${rmse_norm} max=${CHECK_MAX_RMSE}" >&2
exit 1
