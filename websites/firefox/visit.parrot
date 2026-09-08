# Parrot recording v2
# Website benchmark, MEASURED phase 1: load the page and idle for 5 s.
#
# The equivalent of the template's
#     page_result = await page.goto("__GMT_VAR_PAGE__");
#     sleep __GMT_VAR_SLEEP__
# in templates/website/usage_scenario_cached.yml.
#
# Alt+Home is Firefox's "go to your home page", and the home page is
# __GMT_VAR_PAGE__ - common/setup-profile.sh wrote it into the profile before the
# browser started. That is how a static macro navigates to a URL it cannot know:
# the URL is in the profile, not in the keystrokes.
#
# It is a plain navigation, NOT a reload, and that distinction is the whole
# point of the group. A reload (Ctrl+R, Ctrl+Shift+R) sends Cache-Control
# upstream and the squid config in greencoding/squid_reverse_proxy carries no
# `ignore-reload`, so a reload would go to the origin and the cache this
# scenario exists to use would be bypassed.
#
# The browser is already running when this starts - websites/firefox/start.parrot
# ran in a hidden step - so no browser start-up is inside this phase.

startcommand = bash /tmp/repo/websites/common/launch-browser.sh firefox /tmp/parrot-profile-measure about:blank
windowtitle  = Mozilla Firefox
windowclass  = firefox

log Visit page: navigate to the page under test and idle for 5 s
wait 0.1
keydown Alt_L
wait 0.05
keydown Home
wait 0.05
keyup Home
wait 0.05
keyup Alt_L
# 5 s of idling after the navigation begins, exactly as the template idles for
# __GMT_VAR_SLEEP__ after page.goto(). It covers load AND idle, not idle alone.
wait 5
log Page loaded and idled: 5 s after the navigation was started
