# Benchmarking websites

Measure any website in a **real browser**, driven by Parrot, with a warm caching
proxy in front of it. The page is passed in as a Green Metrics Tool variable, so
one scenario file measures any number of sites.

```bash
cd /home/didi/code/green-metrics-tool && venv/bin/python runner.py \
  --uri /home/didi/code/parrot \
  --filename websites/usage_scenario_firefox_cached.yml \
  --variable __GMT_VAR_PAGE__=https://www.green-coding.io \
  --allow-unsafe --dev-no-system-checks=check_ssh_session
```

Swap `firefox` for `chrome` in the filename for the other browser. Everything
else is identical, deliberately.

## What this is a version of

GMT ships [`templates/website/usage_scenario_cached.yml`](https://github.com/green-coding-solutions/green-metrics-tool/blob/main/templates/website/usage_scenario_cached.yml),
which measures a page in headless Playwright behind a squid cache. This group is
the same measurement with the Playwright browser replaced by a real one:

| | GMT template | this group |
| --- | --- | --- |
| Browser | Playwright, headless | Firefox 155.0.1 / Chrome for Testing 152.0.7977.82, on Xvfb |
| Driven by | a JS snippet over an IPC fifo | a `.parrot` macro, replayed as X input events |
| Cache | `greencoding/squid_reverse_proxy:v5` | the same image, same config |
| TLS to the bumping proxy | `ignoreHTTPSErrors: true` | the proxy's CA imported into the browser's own certificate store |
| Navigation | `page.goto(url)` | `Alt+Home`, with the URL as the browser's home page |
| Scroll | wheel until the page reports it is at the bottom | 25 wheel ticks, 200 ms apart |
| Page | `__GMT_VAR_PAGE__` | `__GMT_VAR_PAGE__` |

The shape of the run is kept: a hidden warmup that fills the proxy cache, then
`Visit page and idle for 5 s`, then `Scroll down and wait 5 s`.

## The flow

Three hidden steps and two measured ones. The hidden ones exist so that the
measured ones contain only the browser doing the thing being measured.

| Phase | Hidden | What runs |
| --- | --- | --- |
| Check page is reachable | yes | `common/check-url.sh` |
| Warmup and Caching | yes | `common/warmup.sh <browser>` |
| Start browser | yes | `replay.py <browser>/start.parrot` |
| **Visit page and idle for 5 s** | no | `replay.py <browser>/visit.parrot` |
| **Scroll down and wait 5 s** | no | `replay.py <browser>/scroll.parrot` |

**Check page is reachable** is the template's "Check HTTP Status Code" step,
moved to the front. Playwright can report the status of the very navigation it
measured; a real browser cannot, so the status has to be taken separately, and
once it is separate the front is the right place for it. A typo in
`__GMT_VAR_PAGE__` then costs two seconds instead of a warmup, a browser start
and two measured phases of a browser rendering an error page.

It is also where the certificate is checked, which is the more valuable half.
See "The proxy is a man in the middle" below.

**Warmup and Caching** is `gmtPlaywrightCache()`: load the page once so the proxy
holds it. Playwright then throws the browser cache away by closing the context;
a real browser has no such operation, so the warmup runs in its own process with
its own throwaway profile, and both are gone before the measured browser starts.

**Start browser** is the template's `flow-prepend`. Starting a browser costs more
than the page load being measured, so it happens here, hidden, and the measured
phases drive a browser that is already up and sitting on a blank page.

## How a static macro navigates to a URL it cannot know

The URL is a GMT variable, so it does not exist when the macro is written. It
cannot be typed, because a macro is a stream of keysyms.

So the URL is not in the keystrokes. It is the browser's **home page**, and the
measured macro presses `Alt+Home`:

* Firefox reads it from `browser.startup.homepage` in the profile, written by
  `common/setup-profile.sh` from `$PARROT_URL`.
* Chrome takes it from `--homepage` on its command line in
  `common/launch-browser.sh`. Not from the profile: Chrome protects that
  preference with a MAC in Secure Preferences and silently reverts values it did
  not write itself.

`Alt+Home` is a plain navigation, and that matters more than it looks. A reload
would be the obvious alternative and it is wrong: `Ctrl+R` and `Ctrl+Shift+R`
send `Cache-Control` upstream, the squid config carries no `ignore-reload`, and
the request would go to the origin. The cache the scenario exists to use would
be bypassed, silently, in the measured phase.

## The proxy is a man in the middle

`greencoding/squid_reverse_proxy` terminates TLS and signs a certificate for
each site on the fly. Playwright ignores that with `ignoreHTTPSErrors`. A real
browser has no equivalent that is safe to use, and Firefox has no
"ignore all certificate errors" preference at all, so the proxy's signing
certificate has to be a trust anchor in the browser's own NSS database.

`websites/squid-ca.crt` is that certificate, copied from the GMT repository at
`docker/auxiliary-containers/squid_reverse_proxy/tls-ca.crt`. It is the public
half of a keypair that is itself public, so committing it gives nothing away.

Two details worth knowing before touching it:

* It is an **intermediate** ("Enterprise Subordinate CA"), not a self-signed
  root, and squid sends only the leaf plus this one. NSS will anchor a chain at
  a non-self-signed certificate as long as it is marked trusted, which is why
  the trust flags in `setup-profile.sh` matter.
* Firefox gets it per profile (`cert9.db` in the profile directory); Chrome
  reads the shared user store at `~/.pki/nssdb`. Different places, same
  `certutil`.

**If squid is ever rebuilt with a new signing certificate, this file has to be
refreshed.** `common/check-url.sh` is what makes that loud: it fetches the page
through the proxy with `--cacert` and no `--insecure`, so a mismatch fails in a
hidden step with a certificate error naming the problem, instead of two browsers
quietly showing an interstitial in a phase that still produces a plausible
energy figure.

## What is in the measurement, and what is not

Measured, per phase, on this machine against `https://www.green-coding.io`:

| Phase | Firefox | Chrome |
| --- | --- | --- |
| Visit page and idle for 5 s | 6.60 s | 6.55 s |
| Scroll down and wait 5 s | 6.53 s | 6.49 s |

The macro itself accounts for about 5.35 s of each. The remaining ~1.2 s is
Parrot's own per-replay setup: `replay.py` starting, finding the window, and
`position-window.sh` re-asserting the geometry. It is **inside** the measured
phase, it is near-idle work, and it is the same in every phase and both
browsers, so it dilutes the signal by a constant factor rather than biasing a
comparison. Subtract it before quoting a figure as "the cost of loading a page".

Not in the measurement: browser start-up, the warmup load, profile creation,
the certificate import, and the reachability check. All of those are hidden
phases or setup-commands.

## Two things that are not comparable between the browsers

Both are properties of driving real browsers rather than a scripted one, and
both belong in any write-up:

1. **A wheel tick is not the same distance in Firefox as in Chrome.** The
   template scrolls by a fixed 200 CSS pixels per step because Playwright can
   ask for that. A real wheel tick is whatever the browser decides it is: over
   the same 25 ticks Firefox reached further down the same page than Chrome did.
   The scroll phase compares **five seconds of scrolling**, not a fixed
   distance. Compare pages within one browser.
2. **The viewport is the whole 1440x900 window minus each browser's own
   chrome**, which differs by a few pixels between the two.

## Building the image

The browsers live in `ribalba/parrot-browsers`, built from `websites/Dockerfile`,
which extends `ribalba/xwindow-server` with Firefox, Chrome and the fonts they
need. Both browsers are pinned by SHA256.

```bash
make -C websites build     # or: make browsers      from the repository root
make -C websites check     # start both browsers once and print their versions
make -C websites push      # or: make push-browsers from the repository root
make -C websites release   # build, check, push
```

The base image is taken **by tag**, so a fix to `replay.py`, `helpers.py`,
`timed_xmacro.py` or `tools/` needs the base rebuilt and pushed first:

```bash
make build push            # the base
make -C websites release   # then this one
```

GMT pulls `image:` unconditionally, so an unpushed local build is not what a
plain run measures. See the note in this repository's memory about the
local-image fallback, which needs a TTY and is therefore only good for proving
that a scenario runs.

## Traps

**Firefox 155 opens a modal Terms of Use panel on first run.** It covers the
content area and nothing gets through until it is dismissed. Without
`termsofuse.bypassNotification` the browser comes up on the new tab page with
the panel on top and the measured `Alt+Home` does nothing at all, while the
phase still runs, still takes 5 s and still produces a number. Measured here;
the prefs are in `common/setup-profile.sh`.

**Firefox's res_name is `Navigator`, not `firefox`.** `WM_CLASS` is
`("Navigator", "firefox")`, and `pin-windows.sh` matches on the res_NAME. Giving
it `firefox` matches a hidden 10x10 window instead, and the real window is never
pinned. A fluxbox rule that matches nothing applies nothing, silently.

**Chrome's res_name contains the profile path**, as
`chromium-browser (/tmp/parrot-profile-measure)`, and fluxbox matches these
patterns in full rather than as a substring: `(name=chromium-browser)` was tried
here and does not match. `common/launch-browser.sh` passes `--class=parrot-chrome`
to give it a stable class, and the scenario pins on the class with an empty name.
This group's `common/pin-windows.sh` differs from the copies under
`applications/*/common/` by exactly that one capability.

**Chrome needs more than Docker's default 64 MB `/dev/shm`.** Without
`--shm-size=1g` the renderer dies and the tab shows "Aw, Snap! Error code:
SIGTRAP", measured here on an ordinary site. It is in `docker-run-args`, which
GMT gates behind `--allow-unsafe` in CLI mode. For a production run, allowlist
the string under
`capabilities.measurement.orchestrators.docker.allowed_run_args` instead.

**Chrome for Testing paints a permanent banner** reading "Chrome for Testing is
only for automated testing" across the top of the content area, 55 px of
viewport a desktop browser would not lose. `--disable-infobars` removes it;
`--test-type` does not. Both were tried.

**The warmup browser has to be gone before the next step.** `replay.py` finds the
app by window class, so a lingering warmup window is the window the measured
phases would drive: right browser, wrong profile, page already loaded. It would
not look like an error anywhere. `warmup.sh` waits for the process to disappear
and fails loudly if it does not.

## Files

```text
websites/
├── Dockerfile                        Parrot + Firefox + Chrome
├── Makefile                          build / check / push / release
├── install-firefox.sh                pinned by SHA256, from ftp.mozilla.org
├── install-chrome.sh                 pinned by SHA256, Chrome for Testing
├── squid-ca.crt                      the bumping proxy's signing certificate
├── usage_scenario_firefox_cached.yml
├── usage_scenario_chrome_cached.yml
├── common/
│   ├── check-url.sh                  reachability + certificate check (hidden)
│   ├── warmup.sh                     fills the proxy cache (hidden)
│   ├── setup-profile.sh              proxy, home page, certificate, no first-run UI
│   ├── launch-browser.sh             the ONE place either command line is written
│   └── pin-windows.sh                deterministic geometry, before fluxbox starts
├── firefox/{start,visit,scroll}.parrot
└── chrome/{start,visit,scroll}.parrot
```

The `.parrot` files here are **written by hand, not recorded**, and they carry no
`check` steps. There is nothing to record: the interactions are one keystroke and
25 wheel ticks. And there is nothing to check against, because the page is a
variable, so there are no reference screenshots in this group and a replay cannot
fail on a pixel comparison. Verify a change here by looking at the run, not at a
pass count.
