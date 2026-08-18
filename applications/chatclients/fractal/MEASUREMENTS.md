# Fractal — measured landmarks

Fractal 14.1 (Flathub, commit `be6bc4ab095c…`, runtime `org.gnome.Platform//50`)
in the benchmark container at 1440x900.

**RECORDED AND REPLAY-VERIFIED.** All 23 blocks measured, `fractal.parrot` is
1134 events with 23 checkpoints, and it replays **23/23 PASS, 0 FAIL** against
fresh containers with a worst RMSE of **0.0952** against a 0.2 threshold. No two
consecutive checkpoints are identical, and every mutating block was confirmed
against the homeserver:

```text
4 message(s)   [m.image] 'image.png'  [edit] '* Thank you so much indeed'
               [reply] 'Agreed, going out today'  [m.text] 'Thank you so much'
1 reaction     👍 -> 'Ship it when the smoke tests are green.'
1 edit         real m.replace
targets        edit     -> @parrot:parrot.test  :: 'Thank you so much'
               reaction -> @nadia:parrot.test   :: 'Ship it when the smoke tests are green.'
               reply    -> @nadia:parrot.test   :: 'Ship it when the smoke tests are green.'
membership     Parrot Lobby not a member, Parrot benchmark JOINED
drip           24, contiguous drip 01 .. drip 24
```

**Three blocks are not like-for-like with the rest of the group**, each by an
explicit decision recorded below: blocks 8 and 10 (media previews turned on, not
the shipped default), block 17 (pasted, so no file chooser is measured), and
block 3 (account recovery cannot be dismissed, so Fractal does cross-signing and
key-backup work no other client does). All four must be stated in the results.

## Window identity

`WM_CLASS(STRING) = "fractal", "fractal"` — `pin-windows.sh` gets **`fractal`**.

## Fractal needs a PORTAL, not a secret service — and its own advice is wrong

This is the finding worth keeping. Launched with everything the other clients
need, Fractal comes up on a full-window error and goes no further:

> **Secret Portal Error** — Could not restore previous sessions
> An unexpected error occurred when interacting with the D-Bus Secret Portal backend.

The dialog offers this fix:

```text
flatpak --user override --talk-name=org.freedesktop.secrets org.gnome.Fractal
```

**That does not work.** Measured: applied it, relaunched, identical error. The
reason is `oo7`, the secret library Fractal uses — inside a Flatpak it always
takes its *file* backend, and that backend fetches its encryption key from
`org.freedesktop.portal.Secret`. Being *allowed* to talk to the Secret Service
is irrelevant when the code path never asks for it:

```text
ERROR fractal::secret::linux: Could not restore previous sessions: secret error:
File backend error Portal communication failed ... The name
org.freedesktop.portal.Desktop was not provided by any .service files
```

The fix is to provide the portal, now in
[../common/install-flatpak.sh](../common/install-flatpak.sh):

* `apt install xdg-desktop-portal xdg-desktop-portal-gtk` — the Secret
  implementation itself comes from `gnome-keyring`, already installed there.
* `XDG_CURRENT_DESKTOP=GNOME` in `flatpak-session`. **Without it the portal
  activates and then serves nothing**, which looks exactly like the portal not
  being installed at all. The line that says it worked is:
  `Choosing gnome-keyring.portal for org.freedesktop.impl.portal.Secret`.

Both are D-Bus activated, so nothing has to be started by hand.

This matters for FluffyChat too — it is a Flatpak on the same runtime and gets
the same portal, which is where its block 17 problem comes from as well.

## Block 1 — Load app

Welcome screen: **Log In (720, 622)**. Nothing to dismiss.

## Block 2 — Sign in: homeserver first, and auto-discovery must be turned OFF

Fractal asks for a **Homeserver** domain and would autodiscover it, which cannot
work here: the corpus's `server_name` is `parrot.test`, Matrix autodiscovery
probes `https://parrot.test/.well-known/matrix/client` — HTTPS, at the MXID's own
domain — and this group is deliberately plain HTTP with no TLS and no such host.

**Fractal offers a way out, and that is why it is in the group.** A client that
autodiscovers and offers no manual override cannot be measured against this
homeserver at all; NeoChat was dropped for exactly that. The route is:

1. **Log In (720, 622)**.
2. **Advanced… (719, 708)** → *Homeserver Discovery* dialog.
3. Turn **Auto-Discovery off (912, 484)**, close with **× (946, 323)**.
4. The field changes from *Domain Name* to **Homeserver URL**: click
   **(700, 536)** and type `http://matrix.parrot.test:8008`.
5. **Next (719, 646)**.
6. Login form appears under the server address, **Matrix Username focused
   (720, 439)**: type `parrot`, click **Password (700, 522)**, type `parrot`.
7. **Next (719, 602)**.

Sign-in succeeds.

## Block 3 — Account recovery cannot be skipped, and its screen CANNOT be captured

Immediately after sign-in Fractal shows **Set Up Account Recovery** with an
optional passphrase field and a single **Set Up (719, 644)** button.

`script.md` block 3 says to dismiss any encryption-setup or key-backup prompt.
**Fractal offers no dismiss:**

| Tried | Result |
| ----- | ------ |
| Back arrow **(28, 27)** | returns to the *login form* — undoes the sign-in |
| `Escape` | same: back to the login form |
| Scrolling the page | nothing below; no skip |

So going through it is the only way in. With the passphrase left empty, **Set Up**
generates a recovery key, and Fractal then shows three screens in a row:

1. **Set Up Account Recovery** → **Set Up (719, 644)**, passphrase left empty.
2. **Account Recovery Set Up Successfully**, showing the key → **Done (719, 580)**.
3. **Login Complete** → **Start Chatting (719, 642)**.

### The recovery key is RANDOM PER RUN — never checkpoint screen 2

This is the thing that would quietly ruin a recording. Screen 2 displays the
generated key in full:

```text
EsU3 9dpR FiHQ AcKn 5Xqh rFhh ABq4 PesA DCg7 Rnyz KHPL peZ7
```

Twelve groups of random characters, different on every single run. A reference
screenshot taken there can never match a replay — and unlike the clock time in
Element's timeline, this is a large, high-contrast region of the image, so it
would blow past the 0.2 RMSE threshold rather than merely nudging it.

**Block 3's checkpoint must be taken after `Start Chatting`**, on the synced room
list, with all three screens behind it.

This also means Fractal does real cryptographic work in block 3 that no other
client in the group does — a cross-signing identity and a key backup. That is
Fractal's genuine first-run behaviour and there is no way to opt out of it, so it
should be stated in the results rather than hidden: block 3 is not quite the same
block here as it is elsewhere.

### The recovery state is SERVER state, so exploring it dirties the run

Worth knowing before anyone repeats this. After one attempt at the prompt, every
later launch showed **"Reset Account Recovery"** instead of "Set Up Account
Recovery", with two extra toggles (*Reset Crypto Identity*, *Reset Room
Encryption Keys Backup*) and a red **Reset** button.

Wiping the client profile does **not** put it back:

```text
rm -rf /home/parrot/.var/app/org.gnome.Fractal
```

still came up on "Reset". The partial cross-signing identity and key-backup live
on the **homeserver**, against the account, not in the Flatpak's data directory.

So a recording made after any exploration would open block 3 on the *Reset*
screen, while a replay against a freshly built homeserver would get the *Set Up*
screen — a guaranteed checkpoint failure that looks like a coordinate problem and
is not one. **Rebuild both containers before measuring this block**, which is
what `record-session.sh` does anyway.

## Block 3 result, and where the measuring stopped

After `Start Chatting` Fractal syncs and shows the room list with unread badges —
no further prompts. Two things to note for whoever continues:

* **The room list is not sorted the way the other clients sort it.** The first
  screen is filler rooms (`Quorum Triage 59`, `Pipeline Standup 54`, …), not the
  three big rooms. The "never click a room in the room list" rule from the other
  clients therefore applies here too, and Fractal has a **search button at
  (221, 27)** in the sidebar header — that is the navigation route to measure.
* The main window has no visible menu bar; the hamburger at **(261, 27)** is the
  primary menu.

## Blocks 4-6 — navigation, scroll-back, jump to live

### Navigation is the sidebar search, and it FILTERS rather than opening

**Search (221, 27)** turns the sidebar header into a text field. Typing
`Aurora Release` filters the list to a single row at **(144, 119)** — badge
`7999`, shown in full rather than abbreviated as SchildiChat does. Clicking that
row opens the room.

Clicking here is safe for the same reason block 12 is safe in the other clients:
the list has been filtered to exactly one result, so there is nothing to be
ambiguous about. The unfiltered list must still never be clicked — see below.

The filter **stays applied** after the room opens; it is cleared with the **×
(262, 68)** inside the field.

### GTK TOOLTIPS ARE SEPARATE WINDOWS, and they match `--class fractal`

Measured, and it will break a naive checkpoint guard. Hovering the room row
produced a second X window:

```text
win 6291502 [Fractal] X=84 Y=136 WIDTH=123 HEIGHT=30
win 6291461 [Fractal] X=0  Y=0   WIDTH=1440 HEIGHT=900
```

That 123x30 window is the tooltip. `CP()` in the other drivers asserts
"exactly one window matching the class", which would fire a warning on every
checkpoint taken with the pointer resting over a tooltip-bearing widget.

Two consequences for Fractal's driver:

* `park()` must move the pointer somewhere that raises no tooltip — over empty
  timeline space, **not** over the sidebar, the header buttons or the composer
  icons.
* The count check should stay, because it is the only thing that catches a real
  extra window; it just has to be given a parked position that does not trip it.

#### The obvious park position is the wrong one — IMAGES have tooltips too

"Empty timeline space" is not enough, and this would have been found only after a
failed recording. The natural place to park is where the wheel scrolls, over the
middle of the timeline at (860, 400) — and in `Field Photos` that is on top of an
image, which raises a **filename** tooltip:

```text
pointer at (860, 400)   win 6291591 [Fractal] X=807 Y=412 WIDTH=115 HEIGHT=30   <- "site-0395.png"
pointer at (400, 400)   (one window)
pointer at (1300, 300)  (one window)
```

Fractal centres timeline content in a fixed-width column — avatars at x≈521,
bodies and images from x≈553 to x≈1153 — so both **margins** are inert. The
driver parks at **(400, 400)**, the left margin: the right margin holds the
jump-to-bottom button at (1390, 805) and the read-receipt avatars at x≈1204.

Measured across every block below: parking at (400, 400) leaves exactly one
window matching `--class fractal` in all 23 checkpoints.

### `Prior` does NOT scroll the timeline — use the wheel

The composer holds focus, so Page Up is a text-cursor key and never reaches the
timeline. Ten `Prior` presses left the view **byte-identical**. This is the same
family of trap as `End` not jumping to live in Element and nheko, and it is worse
here because there is no visible feedback at all.

Scroll-back is therefore the wheel, over the timeline. The earlier eyeballed
figure here ("20 notches moved back roughly a screen and a half ... ten screens
is on the order of 130 notches") was too rough to build a block on, so it was
measured properly by cross-correlating screenshots taken five notches apart:

```text
Field Photos    5 notches -> shift=430px   5 notches -> shift=430px
Aurora Release  5 notches -> shift=430px   5 notches -> shift=430px
```

**86 px per notch, identical in an image room and a text room, and repeatable to
the pixel.** The timeline viewport is ~790 px tall (header ends at y≈54, the
composer row starts at y≈845), so:

> **one screen = 9 notches** (774 px, 98% of a viewport)

That gives Fractal a direct analogue of the `Prior` loop the other four clients
use, rather than a number picked by eye:

| Block | Other clients | Fractal |
| ----- | ------------- | ------- |
| 5 Scroll back, ten screens | `for 1..10: Prior; sleep 2` | `for 1..10: wheel 9; sleep 2` |
| 10 Scroll thumbnails, five screens | `for 1..5: Prior; sleep 3` | `for 1..5: wheel 9; sleep 3` |

The loop matters as much as the total: script.md says to let each batch finish
loading before scrolling again, and 90 notches in one burst outruns the loader.

### Jump to live

Scrolling up raises a jump-to-bottom button at **(1390, 805)**.

## Layout reference for the remaining blocks

| Element | At |
| ------- | -- |
| Composer | (858, 872) |
| Paperclip | (507, 872) |
| Emoji | (547, 872) |
| Send | (1211, 872) |
| Room menu `⋮` | (1297, 27) |
| Sidebar hamburger | (261, 27) |

## Block 7 — Room Details is a SEPARATE WINDOW

Element and SchildiChat put room info and the member list in in-window panels.
Fractal opens a real second window:

```text
win 6291514 [Room Details] X=0 Y=0 WIDTH=640 HEIGHT=780
```

Route: **⋮ (1297, 27)** → **Room Details (1297, 79)** → **Members 509
(319, 325)** → close with **× (611, 27)**.

The `⋮` menu is *also* a separate window (127x103 at 1235,45), as is every GTK
tooltip. So in Fractal the checkpoint guard's window-count check is doing real
work rather than being a formality — but it also means **every popup must be
closed before a checkpoint**, not merely dismissed visually.

## Block 8 — thumbnails: DECIDED, previews are turned on per run

The earlier reading of this — "Fractal does not decode the thumbnails" — was
wrong, and the correction matters because it changes what has to be done about
it. Fractal decodes thumbnails perfectly well. It implements
[MSC4278](https://github.com/matrix-org/matrix-spec-proposals/pull/4278) media
previews, and the shipped default is **Show only in private rooms**:

> **Settings → Safety → Media Previews**
> ( ) Show in all rooms  (•) Show only in private rooms  ( ) Hide in all rooms

`Field Photos` is a **public** room, so the default suppresses its 400
thumbnails and renders "Click to show preview" placeholders instead. The other
four clients do not implement MSC4278 and decode regardless.

**Decision (2026-08-09): previews are set to "Show in all rooms".** Blocks 8 and
10 then measure the same work in all five clients. This is not Fractal as
shipped and must be stated in the results.

### The setting is SERVER state, so it is seeded per run and not clicked

This is the part that would otherwise silently not work. The radio button writes
nothing to disk — the local GSettings keyfile
(`~/.var/app/org.gnome.Fractal/config/glib-2.0/settings/keyfile`) holds only
`markdown-enabled`, `sessions` and `current-session`, and
`org.gnome.Fractal.gschema.xml` has no media key at all. What it writes is
**account data on the homeserver**, under the unstable MSC4278 key:

```text
GET /_matrix/client/v3/user/@parrot:parrot.test/account_data/io.element.msc4278.media_preview_config
{"media_previews": "on"}
```

(The stable `m.media_preview_config` key stays 404 — Fractal 14.1 writes the
`io.element.msc4278.` prefix only.)

GMT rebuilds the homeserver on every run, so a setting flipped by hand is gone
the next run. It is therefore seeded by a **matrix-container setup-command**,
[../common/seed-media-previews.sh](../common/seed-media-previews.sh), which logs
in as the account and PUTs the account data before the client ever starts. That
is a per-run write against the freshly built server, so it neither touches the
`parrot-matrixserver` image nor reseeds the corpus.

Seeding it rather than clicking it is also what keeps the blocks honest: no
block measures a trip through the preferences dialog, and block 8 starts with
the setting already in force.

Applying it takes effect **live, with no restart** — measured: the placeholders
became decoded thumbnails about 8 s after the radio button was clicked.

### Layout of the settings dialog, for the record

Not needed by the driver, since the setting is seeded rather than clicked, but
measured while finding the above. **The settings dialog is an in-window modal,
not a separate X window** — the window list stays at one 1440x900 `fractal`
window throughout, so the checkpoint guard cannot see it.

Route: avatar **(27, 27)** → gear **(204, 92)** → **Safety (789, 82)** →
**Show in all rooms (565, 500)** → close **× (1016, 82)**.

## Block 9 — View image full size

The viewer is **in-window**, like SchildiChat's lightbox and unlike Room Details:
the window list stays at one 1440x900 `fractal` window while it is open.

Click the newest image at **(853, 625)**. The viewer confirms the target in its
header — `reservoir-at-first-light.jpg`, which is what script.md names — and the
image renders fit-to-window with an expand button at (1257, 27) that is not used.
Close with the back arrow **(28, 27)**.

Closed explicitly before the checkpoint, for the same block-boundary reason as
block 7, because the guard cannot see it.

## Block 11 — the filter, and the focus trap in clearing it

**The × does not leave the field focused.** Block 12 ends by clearing the filter
with × (262, 68); the field stays open and empty and the full room list comes
back, but keystrokes then go nowhere. Typing `windvane` straight after clearing
produced a **byte-identical screen** — no error, no caret, nothing.

So every navigation in this client clicks the field first. The driver's `ROOM()`
is:

```text
CLICK 144 68     # the filter field - REQUIRED, the × dropped focus
K ctrl+a         # replace whatever the last block left in it
T '<room name>'
CLICK 144 119    # the single filtered row
```

`ctrl+a` rather than a second × click: it is one action instead of two and it
works whether the field is empty or still holds the previous room's name.

Typing `windvane` filters the list to one row, `Windvane Deployme… 600`.

## Block 12 — Open filtered room

Click the row **(144, 119)**, then clear the filter with **× (262, 68)** as
script.md asks. Clicking here is safe for the same reason as in the other
clients: the list has been filtered to exactly one result.

## Blocks 13-16 — the composer, and how the message menu is positioned

Own messages are **LEFT-aligned** in Fractal. SchildiChat right-aligns them and
aims block 16 at the right-hand side of the timeline; that coordinate does not
carry over.

### The context menu hangs its BOTTOM EDGE off the click point

Worth stating because it makes the menu coordinates derivable rather than
guessed. The menu is a separate 192-wide X window whose origin is
`(click_x - 1, click_y - height)`, so it grows **upwards** from the pointer:

| Block | Right-clicked at | Menu geometry | Item clicked |
| ----- | ---------------- | ------------- | ------------ |
| 14 Reply | (686, 694) | X=685 Y=389 192x305 | **Reply (722, 516)** |
| 15 React | (686, 628) | X=685 Y=323 192x305 | **••• (843, 395)** |
| 16 Edit | (618, 761) | X=617 Y=392 192x369 | **Edit (648, 551)** |

The own-message menu is **369 tall, not 305**, because it gains *Edit* and
*Remove*. A position copied from block 14 to block 16 would land on the wrong
item.

Every menu carries a quick-reaction row (👍 👎 😄 🎉 / 😕 ❤️ 🚀 •••) above
*Reply*, then *Copy Text*, *Copy Message Link*, *Properties*, *Report…*.

### Block 15 goes through the picker, not the quick row

The 👍 in the menu's quick-reaction row would be one click. script.md says
"through the client's emoji picker", and the other clients render a full picker
before clicking 👍 in its Quick Reactions section — so taking the shortcut here
would skip the picker rendering that the other four are being charged for.

Route: **••• (843, 395)** opens the picker (a separate window, 388x412 at
491,216) → **Body & Clothing tab (589, 605)** → **👍 (843, 458)**, the last item
of the fourth row. Colour emoji render correctly, which is what
`fonts-noto-color-emoji` in `install-flatpak.sh` is for.

### TARGET THE ORIGINAL, NOT THE QUOTE

The same trap SchildiChat documented, and it is live here: after block 14 the
reply renders a quoted copy of Nadia's text at y≈813 while the original sits at
y≈628. Block 15 right-clicks **(686, 628)**.

Verified on the server rather than by eye — the reaction resolves to
`@nadia:parrot.test :: 'Ship it when the smoke tests are green.'`, and the reply
resolves to the same event.

### Block 16

`ctrl+a` then retype the whole string, as SchildiChat does, so both clients are
doing the same work. Confirmed server-side as a real `m.replace`:

```text
1 edit(s) in Windvane Deployment
  @parrot:parrot.test replaced $c6RVRHV4Ic0... -> 'Thank you so much indeed'
```

## Block 17 — the upload needs /dev/fuse, and fails SILENTLY without it

The worst failure found in this client, because every visible signal says it
worked.

Fractal's chooser is **not** its own dialog and **not** the one the two Electron
clients get. It is the XDG portal, in a separate window with a class that does
not match the client:

```text
win 12582915 [Select File] class= "xdg-desktop-portal-gtk" X=1 Y=45 1096x843
```

Two things follow.

### The checkpoint guard is BLIND to this chooser

SchildiChat's `CP()` catches its file chooser because the chooser's WM_CLASS
starts with the client's name. Fractal's does not match `--class fractal` at all,
so a run that left it open would checkpoint a screen with a file dialog on it and
report one window, geometry correct, no warning. **Fractal's `CP()` therefore
asserts on the portal class separately.**

### Selecting a file returns nothing without FUSE

The chooser opens on **Recent**, which is empty on a fresh profile — the trap
already documented for the GTK chooser — so the path is typed with `ctrl+l`. The
accept button here is **Select** (1047, 842), not *Open*.

That much works: the path lands in the location bar and *Select* enables. And
then nothing is attached, no error appears on screen, and the block passes every
check that does not consult the server. The reason is in `/tmp/fr.log`:

```text
fusermount3: fuse device not found, try 'modprobe fuse' first
error: fuse init failed: Can't mount path /run/user/1001/doc
xdg-desktop-portal-WARNING: Failed to register file:///tmp/parrot.png:
    GDBus.Error:org.freedesktop.DBus.Error.NoReply
ERROR fractal::session_view::room_history::message_toolbar::imp:
    Could not open file: Error { ..., message: "No file selected" }
```

GTK4 forces the portal for sandboxed apps — `GTK_USE_PORTAL=0` does not disable
it, `gdk_should_use_portal()` hard-codes "1" inside a sandbox — so the portal
cannot be routed around. After the pick, xdg-desktop-portal registers the file
with `org.freedesktop.portal.Documents` so the sandbox can read it, and the
document store is a **FUSE filesystem**.

### What it costs to make the chooser work: CAP_SYS_ADMIN

Measured one step at a time, because the first fix looks like it should be enough
and is not:

| Container | Result |
| --------- | ------ |
| as shipped | `fusermount3: fuse device not found, try 'modprobe fuse' first` |
| `+ --device /dev/fuse` | `fusermount3: mount failed: Operation not permitted` |
| `+ --cap-add SYS_ADMIN` | `portal on /run/user/1001/doc type fuse.portal` — **works** |

The device node alone is not enough: a FUSE mount needs `CAP_SYS_ADMIN`, and
Docker drops it from the bounding set, so even a setuid-root `fusermount3` cannot
get it. Confirmed independently — `mount -t tmpfs` is denied in this container
and succeeds in one with the capability added.

`--filesystem=host` on the Flatpak does **not** avoid the document portal:
xdg-desktop-portal 1.18.4 registers documents unconditionally for sandboxed apps.
Measured, and it changed nothing.

So the file chooser costs the capability this group removed on purpose in commit
cbe1099 — the one the scenario comment means by *"It can no longer escape into
it: that needed SYS_ADMIN, which is gone."*

### Decision (2026-08-09): paste from the clipboard, keep the capability dropped

Block 17 pastes the image into the composer with `ctrl+v` instead of going
through the chooser. Verified end to end against a container with **Docker's
default capability set**:

```text
1 message(s) from @parrot:parrot.test in Windvane Deployment
  [m.image  ] 'image.png'
```

* **What is still measured**: the same 762 kB image encoded, uploaded and
  rendered as a thumbnail — the expensive part of the block, and the part the
  other four clients are charged for.
* **What is not**: the file chooser itself. The other four open one; Fractal does
  not. Block 17 is therefore *not* like-for-like across the group and the results
  must say so.
* The event arrives named **`image.png`**, not `parrot.png`, because a clipboard
  image carries no filename. Anything comparing bodies across clients has to
  expect that.

The clipboard is loaded by
[../common/seed-clipboard.sh](../common/seed-clipboard.sh) as the **last**
setup-command — after `entrypoint.sh`, because it needs the X server that
entrypoint starts. X11 has no clipboard daemon, so the `xclip` that owns the
selection is left running for the whole session; if it exits, the clipboard is
empty and block 17 pastes nothing while looking entirely healthy. That is why
the seeder reads the selection back and checks its byte count instead of
trusting `xclip`'s exit code, which is 0 whether or not it ever took ownership.

Pasting raises a preview dialog with *Cancel* / **Send (861, 272)**. **Send is
the step that uploads** — the dialog closing means nothing, the same trap as
SchildiChat's second confirmation step.

## Blocks 18-21 — navigation and room lifecycle

### Block 18 — Echo round trip

`ROOM('Parrot Echo')`, composer **(858, 872)**, `ping`. `pong` from `@echo` came
back inside 12 s.

### Block 19 — Join room

Hamburger **(261, 27)** → **Join Room… (209, 142)** (`Ctrl+L` does the same, but
the menu item is clicked so the recording does not depend on focus). The dialog
is an **in-window modal**, so the window count stays at one.

Field is focused → type `#parrot-lobby:parrot.test` → **Look Up (719, 533)** →
a room preview appears (`Parrot Lobby`, *Open room*, 3 members) → **Join
(719, 620)**.

Verified as real membership, not a peek: `Parrot Lobby JOINED`.

### Block 20 — Create room

Hamburger **(261, 27)** → **New Room… (212, 110)**. Also an in-window modal.

**Fractal defaults to Private but with End-to-End Encryption OFF** — unlike
Element and SchildiChat, which default to private *and* encrypted. Choosing
**Public (581, 601)** removes the encryption toggle entirely and makes a **Main
Address** mandatory, exactly as SchildiChat does; *Create Room* stays disabled
until it is filled.

Route: type `Parrot benchmark` → **Public (581, 601)** → address field
**(670, 690)**, type `parrot-benchmark` → **Create Room (719, 758)**.

The invite is then **⋮ (1297, 27)** → **Invite New Members… (1267, 112)** → type
`@alice:parrot.test` → the result row **(300, 140)**, which ticks a checkbox →
**Invite (583, 27)**.

The invite dialog is a **separate X window** — 640x780 at (0,0), titled
`Room Details` even though it says *Invite New Members* — and it does match
`--class fractal`, so the count check catches it if it is left open.

Verified server-side rather than by the dialog closing:

```text
room: Parrot benchmark !UaRCgqOkLxazkxrzHm:parrot.test
    join_rule: public
    @alice:parrot.test -> invite
    @parrot:parrot.test -> join
```

with no `m.room.encryption` event — public and unencrypted, which is what
script.md asks for and what the other clients produce.

### Block 21 — Leave room, and THE ⋮ MENU CHANGES SIZE PER ROOM

This cost a wrong click and is the sort of thing that looks like a coordinate
typo. The `⋮` menu is not one menu:

| Room | Menu geometry | Items |
| ---- | ------------- | ----- |
| Parrot benchmark (own room) | X=1204 Y=45 **189x135** | Room Details, Invite New Members…, Leave Room |
| Parrot Lobby, Aurora Release | X=1235 Y=45 **127x103** | Room Details, Leave Room |

`@parrot` cannot invite in the corpus rooms, so *Invite New Members…* is absent
and everything below it moves up. **Leave Room is at (1267, 156) in the
three-item menu and (1296, 124) in the two-item one.** Clicking 156 in a corpus
room lands below the menu entirely — it dismisses it and does nothing, silently.

Then a confirmation dialog, *Leave Room?*, with **Leave (803, 499)**.

Verified: `Parrot Lobby not a member`, `Parrot benchmark JOINED`.

## Blocks 22-23 — the idle pair

`ROOM('Parrot Firehose')`, settle, 60 s untouched. Then composer, `drip`,
Return, and 130 s. All 24 arrived, rendered and were on screen at the end:

```text
24 drip message(s) on the server
  contiguous: drip 01 .. drip 24
```

## What every mutating block was checked against

Not screenshots. Blocks 13, 14, 15, 16, 19, 20, 21 and 23 were each confirmed
against the homeserver, and blocks 14 and 15 additionally had their **target
event** resolved, because a reply or a reaction attached to the wrong event is
invisible on screen and is the defect this group keeps producing.

## `PAINTED` is lower here than in the other drivers, and that is calibration

The blank-screen guard is `PAINTED=15000` in `drive-scenario.sh`, not the 30000
the other three use. It was 30000 for the first recording and **warned on block
20 every time**, on a screen that was completely fine.

Element's sparsest real screen is ~99 kB, so 30000 has enormous headroom there.
Fractal's is not, because its screens are mostly white and PNG-compress far
better. Measured across this recording:

| Screen | Size |
| ------ | ---- |
| a truly blank/loading screen (Element, for reference) | ~2.4 kB |
| **block 20, the newly created empty room** | **25 kB** |
| welcome screen | 40 kB |
| block 8, Field Photos with 400 decoded thumbnails | 45 kB |
| text rooms | 79-108 kB |

Two things worth taking from that table. Block 20 is a genuine, fully painted
screen at 25 kB — an empty timeline, *"The conversation starts here."*, *"2 room
changes"* and a one-row sidebar — so 30000 was condemning it wrongly, and a guard
that cries wolf on a known-good block is one nobody reads on the block that
matters.

And **the photo room is SMALLER than the text rooms**, which inverts the
intuition the threshold was originally built on. 45 kB looks like a placeholder
screen next to a 108 kB text screen; it is not. The corpus images are smooth
gradients, and gradients compress better than antialiased text. Do not read a
small PNG here as evidence that thumbnails failed to decode — open it.

## Still to do

* Nothing for Fractal. Recorded, replay-verified, and run through GMT.
