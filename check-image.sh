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
keep_tmp_dir=0
cleanup() {
  if [[ "$keep_tmp_dir" -eq 0 ]]; then
    rm -rf "$tmp_dir"
  fi
}
trap cleanup EXIT

actual_raw="$tmp_dir/actual.png"
actual_cmp="$tmp_dir/actual_cmp.png"
ref_cmp="$tmp_dir/ref_cmp.png"
ref_copy="$tmp_dir/reference.png"
diff_img="$tmp_dir/diff-highlight.png"
overlay_img="$tmp_dir/diff-overlay.png"
mask_img="$tmp_dir/diff-mask.png"

preserve_failure_artifacts() {
  local reason="${1:-unknown}"
  keep_tmp_dir=1

  [[ -f "$actual_raw" ]] || true
  if [[ -f "$ref_path" && ! -f "$ref_copy" ]]; then
    cp "$ref_path" "$ref_copy" 2>/dev/null || true
  fi

  {
    echo "reason=$reason"
    echo "ref_path=$ref_path"
    echo "actual_raw=$actual_raw"
    echo "reference_copy=$ref_copy"
    [[ -n "${ref_size:-}" ]] && echo "ref_size=$ref_size"
    [[ -n "${actual_size:-}" ]] && echo "actual_size=$actual_size"
    [[ -n "${rmse_norm:-}" ]] && echo "rmse=$rmse_norm"
    echo "max_rmse=$CHECK_MAX_RMSE"
    [[ -n "$CHECK_IGNORE_RECT" ]] && echo "ignore_rect=$CHECK_IGNORE_RECT"
  } >"$tmp_dir/check-failure.txt"

  if [[ -f "$actual_cmp" && -f "$ref_cmp" ]]; then
    compare -highlight-color Red -lowlight-color Black \
      "$ref_cmp" "$actual_cmp" "$diff_img" >/dev/null 2>&1 || true
    convert "$ref_cmp" "$actual_cmp" -compose difference -composite \
      -colorspace gray -threshold 0 "$mask_img" >/dev/null 2>&1 || true
    if [[ -f "$mask_img" ]]; then
      convert "$mask_img" -transparent black -fill 'rgba(255,0,0,0.55)' -opaque white \
        "$tmp_dir/diff-mask-overlay.png" >/dev/null 2>&1 || true
      if [[ -f "$tmp_dir/diff-mask-overlay.png" ]]; then
        composite "$tmp_dir/diff-mask-overlay.png" "$actual_raw" "$overlay_img" >/dev/null 2>&1 || true
      fi
    fi
  fi

  echo "[check-image] Saved failure artifacts to $tmp_dir" >&2
  if [[ -f "$overlay_img" ]]; then
    echo "[check-image] Overlay highlight: $overlay_img" >&2
  elif [[ -f "$diff_img" ]]; then
    echo "[check-image] Diff highlight image: $diff_img" >&2
  fi
}

# Capture the current app window image.
import -window "$win_id" "$actual_raw"
cp "$actual_raw" "$actual_cmp"
cp "$ref_path" "$ref_cmp"
cp "$ref_path" "$ref_copy"

ref_size="$(identify -format '%wx%h' "$ref_cmp")"
actual_size="$(identify -format '%wx%h' "$actual_cmp")"
if [[ "$ref_size" != "$actual_size" ]]; then
  preserve_failure_artifacts "size-mismatch"
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
# ImageMagick may emit the normalized RMSE in scientific notation (e.g. 2.85668e-05).
rmse_norm="$(printf '%s\n' "$metric_out" | sed -n 's/.*(\([^)]*\)).*/\1/p' | head -n1)"

if [[ -z "$rmse_norm" ]]; then
  echo "[check-image] could not parse compare output: $metric_out" >&2
  exit 2
fi

if awk -v actual="$rmse_norm" -v max="$CHECK_MAX_RMSE" 'BEGIN { exit (actual <= max ? 0 : 1) }'; then
  echo "[check-image] PASS ref=$(basename "$ref_path") rmse=${rmse_norm} max=${CHECK_MAX_RMSE}"
  exit 0
fi

preserve_failure_artifacts "rmse-exceeded"
echo "[check-image] FAIL ref=$(basename "$ref_path") rmse=${rmse_norm} max=${CHECK_MAX_RMSE}" >&2
exit 1
