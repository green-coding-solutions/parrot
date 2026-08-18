# Benchmarking Matrix chat clients

Five chat clients driven through the same 23-block scenario against the same
local homeserver: a deterministic corpus served by Synapse, with an application
service seeding it and a bot the scenario can trigger.

Nothing leaves the Docker network and nothing is downloaded at measurement time,
so a recording made today replays identically next year and on another machine.

## Status

The homeserver image is built and passes its smoke test. **nheko is measured
end to end** - every block driven and, for the mutating ones, verified against
the server rather than the screenshot - and its landmarks are written up in
[nheko/MEASUREMENTS.md](nheko/MEASUREMENTS.md), which is worth reading before
starting any other client: most of what it found is about Matrix clients in
general, not about nheko.

**Element is measured and recorded** as well, with its own
[element/MEASUREMENTS.md](element/MEASUREMENTS.md). Read that one for the two
traps that are about *recording* rather than about Element: a mapped window is
not a painted window, and a file chooser behaves differently on a fresh profile
than on the profile you measured it with.

**SchildiChat is measured and recorded** too — read
[schildichat/MEASUREMENTS.md](schildichat/MEASUREMENTS.md) for what an
Element-derived driver gets *wrong* on the fork, which is more than expected.

All five are finished end to end, including both Flatpaks.

NeoChat was a sixth entrant and was **dropped**, the same way ONLYOFFICE and WPS
Office were dropped from the word processors. It only accepts a full Matrix ID
and autodiscovers over HTTPS at the MXID's domain; this group is deliberately
plain HTTP with no TLS and no `parrot.test` host, and NeoChat never puts up the
manual-homeserver prompt libQuotient asks it for, so the login row sits on
`Loading…` for ever. Pre-seeding the session was tried and did not work either —
NeoChat read the seeded account but never started a Connection. Its `install.sh`,
`usage_scenario.yml` and `MEASUREMENTS.md` are deleted rather than carried as
dead weight.

| Client | State |
| ------ | ----- |
| nheko | measured, recorded, replay-verified 23/23, GMT run clean |
| Element | measured, recorded, replay-verified 23/23, GMT run clean |
| SchildiChat | measured, recorded, replay-verified 23/23, GMT run clean |
| Fractal | measured, recorded, replay-verified 23/23, GMT run clean — see [fractal/MEASUREMENTS.md](fractal/MEASUREMENTS.md) |
| FluffyChat | measured, recorded, replay-verified 23/23, GMT run clean — see [fluffychat/MEASUREMENTS.md](fluffychat/MEASUREMENTS.md) |

### Four blocks are NOT like-for-like, and the results have to say so

Every one of these was a deliberate decision, taken on 2026-08-09 and written up
where it was found. None of them is a silent fudge, and none should become one.

| Block | Client | What differs | Why |
| ----- | ------ | ------------ | --- |
| 3 Initial sync | Fractal, FluffyChat | both do cross-signing and key-backup work the other three do not | neither can dismiss its encryption prompt — Fractal offers no skip at all, and FluffyChat's *Skip* skips only the passphrase |
| 8, 10 Thumbnails | Fractal | media previews turned **on**, which is not the shipped default | it implements MSC4278 and hides previews in public rooms; `Field Photos` is public |
| 15 React | FluffyChat | uses the quick-reaction row, so **no emoji picker is rendered** | 👍 is below the fold of its *Custom reaction* grid and that grid does not scroll with the wheel |
| 17 Upload | Fractal, FluffyChat | image is **pasted**, so no file chooser is measured | both are Flatpaks, so both get the XDG portal, whose document store needs a FUSE mount, i.e. `CAP_SYS_ADMIN` — dropped on purpose in cbe1099 |

The block-3 row is a correction: it was first written up as unique to Fractal.
FluffyChat behaves the same way, and its *Skip* button makes it look as though it
does not — see [fluffychat/MEASUREMENTS.md](fluffychat/MEASUREMENTS.md).

**The Flatpak three need a portal, not just a keyring.** `install-flatpak.sh` now
installs `xdg-desktop-portal` + `xdg-desktop-portal-gtk` and sets
`XDG_CURRENT_DESKTOP=GNOME` in `flatpak-session`. Fractal will not start without
it, and the advice in Fractal's own error dialog does not work — the reasoning is
in [fractal/MEASUREMENTS.md](fractal/MEASUREMENTS.md).

Both blanks that used to sit here are now filled in, and both failed *silently*
when wrong, which is why they were left blank rather than guessed:

| Was blank | Answer |
| --------- | ------ |
| `pin-windows.sh` res_name | Read off each running window: `element`, `schildichat`, `fractal`, `fluffychat`. **Never the binary or the Flatpak ref** — Electron names the window after the app id, and a WM_CLASS that matches nothing applies no rule at all, so the window lands wherever it likes and every coordinate drifts per run. FluffyChat is the one where the two halves of WM_CLASS **differ in case** (`"fluffychat", "Fluffychat"`); `pin-windows.sh` matches the first field, so it needs the lowercase one |
| the keyring wiring for the Flatpaks | A launcher wrapper, as predicted — `flatpak-session` now unlocks gnome-keyring inside the app's own bus. But that alone was **not enough**: Fractal also needs `xdg-desktop-portal` and `XDG_CURRENT_DESKTOP`, because inside a Flatpak its secret library only ever asks the portal |

One more that only shows up on a rebuild: **fluxbox rewrites `~/.fluxbox/apps`
when it exits**, so `pin-windows.sh` has to run while fluxbox is *stopped*. Pin
first and restart it after, or the rule is silently discarded and the window
comes up unpinned.

## Sessions: why there are no profile tarballs

The plan was a captured `profile.tar.gz` per client. It does not work, for a
reason that applies to **every client in the group**:

> An access token is *server* state. Logging in writes a row to the
> homeserver's database, and that write happens in the running container, not in
> the image. GMT rebuilds both containers for every run, so a captured token
> comes back to a homeserver that has never heard of it.

Measured, with nheko:

```text
dropping to the login page: Failed to setup encryption keys.
Server response: Invalid access token passed. 401.
```

So the session has to be created in the same run that uses it — and **the
scenario signs in itself**. `script.md` block 2 is "Sign in", driven through
each client's own UI like any other block.

This started as a workaround and turned out to be the better design:

- It is the only arrangement where the credential and the homeserver cannot
  disagree, because the run creates both.
- All five clients get the **same** block 1, rather than five different seeding
  mechanisms — which is what the group exists to compare.
- Sign-in becomes a measured result instead of a hidden setup cost. It is its
  own block with its own checkpoint, so it can be reported separately or
  subtracted from a total when "typical usage" is the question.

The flows are not identical — some clients take `@parrot:parrot.test` and find
the server themselves, some ask for the server first, and nheko only reveals a
server field once `.well-known` discovery fails. That variation sits inside one
block, the same way the email group's "Sync account" block absorbs "entering the
password only if the client asks".

Autodiscovery is deliberately left failing. Making it succeed means serving
`/.well-known/matrix/client` from `parrot.test` over HTTPS, which brings back
the whole certificate problem that plain HTTP exists to avoid, to save one
field of typing.

`common/seed-session.sh` (templates a session into a client's config) and
`common/capture-profile.sh` / `common/seed-profile.sh` (tarball a home
directory) are kept for non-session state and for anyone who wants a
pre-authenticated variant, but the scenario does not use them.

## Clients under test

Versions and commits were resolved from published package metadata on
2026-08-08. All five have been installed, driven and recorded; each client's
`MEASUREMENTS.md` records how it comes up and what it demands before it will
sign in.

| Client | Runtime | Version | Source |
| ------ | ------- | ------- | ------ |
| [Element Desktop](element/) | Electron | 1.12.25 | packages.element.io |
| [SchildiChat Desktop](schildichat/) | Electron | 1.11.36-sc.3 | GitHub release `.deb` |
| [nheko](nheko/) | Qt / C++ | 0.11.3+~0.9.2+~1.0.0+~0.3.0-1build4 | Ubuntu 24.04 |
| [Fractal](fractal/) | GTK4 / Rust | Flathub `be6bc4ab` | Flathub, `org.gnome.Platform//50` |
| [FluffyChat](fluffychat/) | Flutter | Flathub `104c4950` | Flathub, `org.gnome.Platform//50` |

Four distinct runtimes across five clients, which is the point of the group. Two
pairings hold something fixed on purpose:

- **Element against SchildiChat** is the nearest thing to a control: same
  Electron, same `matrix-js-sdk`, different UI layer. It is *not* exact -
  SchildiChat 1.11.36-sc.3 is built on Element 1.11.36 while Element pins
  1.12.25, so the pair carries about one Element minor release of upstream
  change. See the note at the top of `schildichat/install.sh`.
- **Fractal against FluffyChat** share `org.gnome.Platform//50`, pinned to the
  same commit. FluffyChat is Flutter and might have been expected on the
  freedesktop runtime; its Flathub manifest says otherwise. So the runtime is a
  constant between them and a gap is the application and its toolkit.

nheko is the only client needing no `docker-run-args` at all: no Chromium
wanting shared memory, no bubblewrap wanting a user namespace.

## Two scenarios per client: as-recorded and time-normalized

Each client has both `usage_scenario.yml`, which replays `<client>.parrot` at the
speed it was recorded, and `usage_scenario_normalized.yml`, which replays
`<client>-normalized.parrot`. The normalized copies come from

```bash
./tools/check_blocks.py applications/chatclients/ --normalize-time
```

which pads every block, with a single extra `wait`, to the longest that block
takes across the group. All five files define the same 23 blocks in the same
order — the tool checks that and refuses if they disagree — so after
normalization every block starts and ends at the same offset in all five runs,
which is what makes a per-block side-by-side comparison fair. Only `wait` lines
are added; the actions, their order and all 23 reference images are untouched.

**What that costs, and it has to be read with the numbers.** Every normalized run
is **1098.6 s**, the sum of the per-block maxima, against as-recorded totals of:

| Client | As recorded | Padding added |
| ------ | ----------: | ------------: |
| nheko | 823.4 s | **+275.2 s** |
| element | 965.4 s | +133.2 s |
| schildichat | 966.3 s | +132.3 s |
| fractal | 1013.2 s | +85.4 s |
| fluffychat | 1025.0 s | +73.6 s |

The padding is idle time, and idle is not free — it is the thing blocks 22 and 23
exist to measure. So a normalized run charges the fastest client for the most
waiting: **nheko's normalized figure carries 275 s of idle that its own recording
never had.** Use the normalized scenarios to compare *blocks* against each other,
and the as-recorded scenarios to compare *totals*. Reporting a normalized total as
"what the client costs" would flatter the slow clients and penalise nheko.

## The homeserver

[`matrixserver/`](matrixserver/) builds an image carrying Synapse, PostgreSQL
and the whole seeded corpus. See its [README](matrixserver/README.md) for the
bot; the corpus decisions are in `seed_corpus.py`.

Three that are not recoverable from the code:

- **The seeder is an application service**, which is the only kind of Matrix
  client allowed to set `?ts=`. Without that the corpus is stamped with the
  build date, every client renders "today" and "12:04", and every reference
  screenshot rots the day after the image is built. It also buys impersonation
  and rate-limit exemption, which is what makes 500 members affordable.
- **PostgreSQL rather than SQLite**, because block 2 measures the initial sync
  and on SQLite that room is slow enough that every client would be waiting on
  Synapse instead of on itself.
- **Presence and URL previews are off.** Both inject server-driven events at
  times nothing in the scenario controls. Presence is a real cost in the wild
  and is excluded because it cannot be made to arrive at the same point twice.

Rooms are **unencrypted** and the room the scenario creates is **public**, which
is what keeps clients from turning encryption on by themselves. E2EE would drag
in cross-signing, key backup and per-client "unable to decrypt" states.

## Media: the server setting that decides whether images exist

`matrixserver/conf/homeserver.yaml` sets `enable_authenticated_media: false`,
and it is not a detail. Synapse defaults it to true since 1.120, which makes
the legacy `/_matrix/media/v3/download` endpoint 404 anything uploaded while it
is on. nheko 0.11.3 speaks only that endpoint, so `Field Photos` came up as a
grid of broken-image icons and three blocks of the scenario - open photo room,
view image full size, scroll thumbnails - measured a placeholder glyph.

Nothing was missing: 2000 files in the media store, and the same id served
609437 bytes over the authenticated endpoint with a token. Turning the flag off
is strictly more compatible - the authenticated endpoint keeps working, the
legacy one starts working again.

Two things worth carrying to the other clients:

- The flag is recorded **per media row at upload time**, so changing it means
  re-seeding the corpus, not just restarting the server.
- `smoke_test.py` now fetches the anchor image over **both** endpoints and
  compares the bytes. Every other check in it passed while the room was
  rendering placeholders, which is the whole argument for the check existing.

## Recording

The loop is the one in [`../../AGENTS.md`](../../AGENTS.md), which is worth
re-reading before starting a client rather than after. The chat-specific part is
step 3, verifying against ground truth: [`common/matrix-truth.py`](common/matrix-truth.py)
asks the homeserver what actually happened. It exists because every trap in
AGENTS.md has a chat equivalent that looks fine on screen:

| What it looks like | What may have happened |
| --- | --- |
| Message is in the timeline | Still queued locally - several clients render optimistically |
| Reaction is under the message | Attached to the event above it, or to the reply rather than its parent |
| Edit shows the new text | Sent as a new message rather than an `m.replace` |
| Joined, and the timeline renders | Peeked - public rooms can be read without joining |
| 24 drip messages on screen | Some arrived and were never rendered |

And it has the same blind spot as every other ground truth in this repo: it
cannot say *which* message a client acted on. Comparing the same checkpoint
across two clients is still the only thing that catches that.

## Files

| Path | What it is |
| ---- | ---------- |
| `script.md` | the scenario, one `* Label: detail` line per block |
| `account.env` | single source of truth for accounts, the homeserver and the drip |
| `matrixserver/` | Synapse, the corpus seeder, the smoke test and the bot |
| `common/setup-container.sh` | rebuilds both containers from a `usage_scenario.yml` |
| `common/measure.sh` | helpers for measuring landmarks by hand |
| `common/matrix-truth.py` | what the server thinks happened |
| `common/install-flatpak.sh` | pinned Flatpak install, running as uid 1001 |
| `common/client-setup.sh` | waits for the homeserver, prints the anchors |
| `common/seed-profile.sh` | restores a captured session |
| `common/keyring.sh` | a secret service, for the clients that need one |
| `common/pin-windows.sh` | deterministic window geometry |
