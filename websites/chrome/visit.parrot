# Parrot recording v2
# Website benchmark, MEASURED phase 1: load the page and idle for 5 s.
#
# See ../firefox/visit.parrot for the reasoning; it applies unchanged. The only
# difference between the two browsers is how the home page gets set: Firefox
# reads it from the profile written by common/setup-profile.sh, Chrome takes it
# from --homepage on the command line in common/launch-browser.sh, because
# Chrome protects that preference with a MAC and reverts values it did not write
# itself.
#
# Alt+Home is Chrome's "open your home page in the current tab", and passing
# --homepage also makes Chrome treat the home page as something other than the
# new tab page, so the key lands on the URL rather than on the NTP.

startcommand = bash /tmp/repo/websites/common/launch-browser.sh chrome /tmp/parrot-profile-measure about:blank
windowtitle  =
windowclass  = parrot-chrome

log Visit page: navigate to the page under test and idle for 5 s
wait 0.1
keydown Alt_L
wait 0.05
keydown Home
wait 0.05
keyup Home
wait 0.05
keyup Alt_L
wait 5
log Page loaded and idled: 5 s after the navigation was started
