# Parrot recording v2
# Website benchmark, MEASURED phase 2: scroll down for 5 s.
#
# See ../firefox/scroll.parrot. The macro is identical apart from the window
# metadata, which is the point: both browsers get the same 25 wheel-down ticks
# 200 ms apart, driven by the same X server through the same code path.
#
# A wheel tick is still not the same DISTANCE in Chrome as it is in Firefox.
# This phase compares five seconds of scrolling, not a fixed number of pixels.

startcommand = bash /tmp/repo/websites/common/launch-browser.sh chrome /tmp/parrot-profile-measure about:blank
windowtitle  =
windowclass  = parrot-chrome

log Scroll down: 25 wheel-down ticks over 5 s
mousemove 720 500
label scroll_down
wait 0.19
mousedown 5
wait 0.01
mouseup 5
loop scroll_down 25
log Scroll complete: 5 s of scrolling
