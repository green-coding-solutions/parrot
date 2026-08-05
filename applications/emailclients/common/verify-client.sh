#!/usr/bin/env bash
# Replay a recorded client macro in a fresh pair of containers.
#
#   verify-client.sh <client> [archive-folder]
#
# The setup must mirror that client's usage_scenario.yml, or the verification
# stops meaning anything.
set -euo pipefail
cd /home/didi/code/parrot
CLIENT="${1:?usage: verify-client.sh <client> [archive-folder]}"
ARCHIVE="${2:-Archive.2026}"
NET=parrot-replay-net
R=/tmp/repo/applications/emailclients

docker rm -f mail-container window-container >/dev/null 2>&1 || true
docker network rm "$NET" >/dev/null 2>&1 || true
docker network create "$NET" >/dev/null

docker run -d --name mail-container --net "$NET" \
    --network-alias mail-container --network-alias mail.parrot.test \
    ribalba/parrot-mailserver:v1 sleep inf >/dev/null
docker exec mail-container parrot-mailserver-start 2>&1 | grep -E 'all checks passed|FAIL'

# Mirror each scenario's `environment:` block.  KMail's sets XDG_CURRENT_DESKTOP,
# and launch-with-session.sh defaults it to GNOME when it is unset - so leaving it
# out here would replay the client in a different desktop than it was recorded in.
DESKTOP_ENV=()
if [ "$CLIENT" = kmail ]; then DESKTOP_ENV=(-e XDG_CURRENT_DESKTOP=KDE); fi
docker run -d --name window-container --net "$NET" \
    -v /home/didi/code/parrot:/tmp/repo:ro -e RESOLUTION=1440x900 --shm-size=1g \
    "${DESKTOP_ENV[@]}" \
    ribalba/xwindow-server sleep inf >/dev/null

# Per-client setup, mirroring each usage_scenario.yml.
case "$CLIENT" in
  bluemail)
    docker exec window-container bash "$R/common/pin-windows.sh" bluemail 1440 900 BlueMail >/dev/null ;;
  thunderbird|betterbird)
    docker exec window-container bash "$R/common/pin-windows.sh" Mail 1440 900 >/dev/null ;;
  evolution)
    docker exec window-container bash "$R/common/pin-windows.sh" evolution 1440 900 Evolution >/dev/null ;;
  clawsmail)
    # The role confines the main-window rule to the main window; without it Claws'
    # modal password prompt lands at 0,0 behind the mailbox and the run hangs.
    docker exec window-container bash "$R/common/pin-windows.sh" claws-mail 1440 900 Claws-mail mainwindow >/dev/null ;;
  mailspring)
    docker exec window-container bash "$R/common/pin-windows.sh" mailspring 1440 900 Mailspring >/dev/null ;;
  kmail)
    # Same reason as Claws: KMail's dialogs and its composer share the mailbox's
    # WM_CLASS, and only the mailbox carries WM_WINDOW_ROLE "kmail-mainwindow#1".
    docker exec window-container bash "$R/common/pin-windows.sh" kmail 1440 900 kmail2 'kmail-mainwindow.*' >/dev/null ;;
  *)
    docker exec window-container bash "$R/common/pin-windows.sh" >/dev/null ;;
esac
docker exec window-container bash -c 'bash /usr/local/bin/entrypoint.sh >/tmp/ep.log 2>&1'
docker exec window-container bash "$R/common/client-setup.sh" >/dev/null 2>&1 && echo "  client-setup ok"
docker exec window-container bash "$R/${CLIENT}/install.sh" >/dev/null 2>&1 && echo "  install ok"
case "$CLIENT" in
  thunderbird|betterbird)
    docker exec window-container bash "$R/common/seed-mozilla-profile.sh" /root/.thunderbird parrot >/dev/null 2>&1 \
      && echo "  mozilla profile seeded" ;;
  evolution|clawsmail)
    docker exec window-container bash "$R/${CLIENT}/seed-account.sh" >/dev/null 2>&1 && echo "  account seeded" ;;
esac
docker exec window-container bash "$R/common/seed-profile.sh" "$R/${CLIENT}" /root 2>&1 | sed 's/^/  /'
# KMail's seed runs AFTER the profile is restored - it edits two files that
# profile carries - and after entrypoint.sh, which has already run above.
if [ "$CLIENT" = kmail ]; then
  docker exec -e DISPLAY=:99 window-container bash "$R/kmail/seed-account.sh" 2>&1 | sed 's/^/  /'
fi

# Regions to blank before comparing, in the same "x,y,w,h;..." form the
# scenarios use.  Must match that client's usage_scenario.yml, or this harness is
# checking something the benchmark does not.
case "$CLIENT" in
  # Evolution's "To Do" side bar lists the next seven days from the wall clock,
  # so it stops matching the day after the recording was made.
  evolution)  IGNORE_RECT="1251,130,189,770" ;;
  # The two messages the scenario sends are delivered straight back into the inbox
  # and render with a wall-clock time - in the list for the top two rows, and again
  # beside the reply in the reading pane.  Every other client pays a few hundred
  # pixels for that; Mailspring's rows are 85 px tall, which is what put its checks
  # 15 and 16 at 0.153 against a 0.2 threshold.
  mailspring) IGNORE_RECT="560,72,90,108;960,848,85,24" ;;
  *)          IGNORE_RECT="" ;;
esac

echo "=== replay ==="
set +e
docker exec -e DISPLAY=:99 -e CHECK_IGNORE_RECT="$IGNORE_RECT" window-container \
    python3 /usr/local/bin/replay.py "$R/${CLIENT}/${CLIENT}.parrot" \
    > /tmp/${CLIENT}-out.log 2>/tmp/${CLIENT}-err.log
rc=$?
set -e
echo "  replay exit code: $rc"
echo "  passed: $(grep -c 'PASS ref=' /tmp/${CLIENT}-err.log)  failed: $(grep -ci 'FAIL ref=' /tmp/${CLIENT}-err.log)"
# A check that passes at 0.195 against a 0.2 threshold has not really passed, and
# the pass count cannot tell you that.  Worst three first.
# `|| true` on every one of these, and it is not cosmetic.  The script runs under
# `set -euo pipefail`, so a grep that legitimately matches nothing kills it - and
# because these lines sit ABOVE the mailbox check, the run then ends without ever
# printing the mailbox.  That happened for betterbird, whose notes do not match
# the label pattern: 17/17 passed, and the one thing this project insists on
# checking was silently skipped.
echo "--- worst RMSE ---"
{ grep -oE '(PASS|FAIL) ref=[^ ]+ rmse=[0-9.e-]+' /tmp/${CLIENT}-err.log \
  | sort -t= -k3 -g -r | head -3 | sed 's/^/  /'; } || true
echo "--- labels ---"
{ grep -oE '\* [A-Za-z0-9 ]+$' /tmp/${CLIENT}-out.log | head -4 | sed 's/^/  /'; } || true
echo "--- mailbox (expect INBOX 2100, ${ARCHIVE} 1, Trash 0, Sent 942) ---"
docker exec mail-container bash -c \
  "for m in INBOX ${ARCHIVE} Trash Sent; do printf '  %-14s %s\n' \"\$m\" \"\$(doveadm mailbox status -u parrot messages \"\$m\" 2>/dev/null|sed 's/.*messages=//')\"; done"
# Counts alone hide a delete that only set \\Deleted and a trash that was never
# expunged - both of which have shipped in this project before.
echo "--- flags ---"
docker exec mail-container bash -c \
  "printf '  %-14s %s\n' 'Trash DELETED' \"\$(doveadm search -u parrot MAILBOX Trash DELETED | wc -l)\"
   printf '  %-14s %s\n' 'INBOX DELETED' \"\$(doveadm search -u parrot MAILBOX INBOX DELETED | wc -l)\"
   printf '  %-14s %s\n' 'INBOX FLAGGED' \"\$(doveadm search -u parrot MAILBOX INBOX FLAGGED | wc -l)\"
   printf '  %-14s %s\n' 'INBOX UNSEEN'  \"\$(doveadm search -u parrot MAILBOX INBOX UNSEEN | wc -l)\""
echo "=== VERIFICATION COMPLETE ==="
