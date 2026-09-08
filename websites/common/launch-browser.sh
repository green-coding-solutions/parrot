#!/usr/bin/env bash
# The single place where either browser's command line is written.
#
#   launch-browser.sh <firefox|chrome> <profile-dir> [url]
#
# Called from three places, which is exactly why it exists: the startcommand of
# every .parrot macro in this group, and common/warmup.sh. A flag that differs
# between the warmup instance and the measured instance would be a confound
# nobody would think to look for, so there is one command line and both use it.
#
# It execs the browser, so the process replay.py launched IS the browser and
# nothing is left holding the pipe.
set -euo pipefail

BROWSER="${1:-}"
PROFILE="${2:-}"
URL="${3:-about:blank}"

if [[ -z "$BROWSER" || -z "$PROFILE" ]]; then
    echo "usage: launch-browser.sh <firefox|chrome> <profile-dir> [url]" >&2
    exit 2
fi

PROXY_HOST="${PARROT_PROXY_HOST:-squid}"
PROXY_PORT="${PARROT_PROXY_PORT:-3128}"

case "$BROWSER" in
firefox)
    # The proxy, the home page and the rest of the configuration are in the
    # profile's user.js, written by setup-profile.sh - Firefox has no command
    # line for any of it.
    #
    # --no-remote --new-instance: without them a second Firefox started while
    # the first is up hands its URL to the running instance and exits, so the
    # warmup instance and the measured instance would silently become one
    # browser sharing one cache.
    exec firefox --profile "$PROFILE" --no-remote --new-instance "$URL"
    ;;

chrome)
    # --no-sandbox: the container runs as root and Chrome's setuid sandbox
    #   refuses to start under it. This is the standard Chrome-in-docker flag.
    # --homepage: what Alt+Home navigates to in the measured phase. Chrome
    #   also sets homepage-is-not-the-new-tab-page when this switch is present,
    #   which is why the home key does not land on the new tab page.
    # --disable-background-networking and friends: component updates, the
    #   safe-browsing list, the field-trial fetch and sync all issue requests on
    #   their own schedule. Through the proxy they would be part of whatever
    #   window happened to be measured.
    # --password-store=basic --use-mock-keychain: there is no keyring daemon
    #   here, and without these Chrome spends its startup looking for one.
    # --disable-infobars: Chrome for Testing paints a permanent banner reading
    #   "Chrome for Testing ... is only for automated testing" across the top of
    #   the content area. It is 55 px of viewport that the browser under test
    #   would not have on a desktop, and it pushes every page down by that much.
    #   --test-type does NOT remove it; this does. Both were measured here.
    # No --window-size or --window-position: geometry belongs to the window
    #   manager in this repository. common/pin-windows.sh gives the window
    #   1440x900 at 0,0 with no decorations, and Chrome's own flags produced
    #   1439x899, which is a difference nobody wants to explain later.
    # --class: WM_CLASS, and it is not cosmetic. Left alone, Chrome derives its
    #   res_name from the binary and the profile directory and maps as
    #   "chromium-browser (/tmp/parrot-profile-measure)" - read off a running
    #   window here. Both pin-windows.sh and replay.py find the window by class,
    #   so without this the class the macros name would have to embed a
    #   filesystem path, and would change the moment the profile moved.
    exec google-chrome \
        --class=parrot-chrome \
        --user-data-dir="$PROFILE" \
        --proxy-server="http://${PROXY_HOST}:${PROXY_PORT}" \
        --homepage="${PARROT_URL:-about:blank}" \
        --no-sandbox \
        --no-first-run \
        --no-default-browser-check \
        --no-service-autorun \
        --disable-background-networking \
        --disable-component-update \
        --disable-sync \
        --disable-search-engine-choice-screen \
        --metrics-recording-only \
        --password-store=basic \
        --use-mock-keychain \
        --disable-infobars \
        "$URL"
    ;;

*)
    echo "[launch-browser] unknown browser: $BROWSER (expected firefox or chrome)" >&2
    exit 2
    ;;
esac
