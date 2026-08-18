# nheko — measured landmarks

Everything here was read off a running nheko in the benchmark container, not
inferred. Coordinates are for a window pinned to **1440x900 at 0,0** by
`common/pin-windows.sh nheko 1440 900`; they mean nothing at any other geometry.

Version: `0.11.3+~0.9.2+~1.0.0+~0.3.0-1build4` (Ubuntu 24.04).

## Window identity

```text
WM_CLASS(STRING) = "nheko", "nheko"
```

Both halves are the same string, so `nheko` works as `pin-windows.sh`'s
res_name and as xdotool's `--class`. Unpinned, nheko opens **1066x600 at
187,181** — placement depends on what else fluxbox has mapped, so pinning is
not optional.

## Launch: the keyring, and why it needs a wrapper

Launching `/usr/bin/nheko` directly against a seeded profile puts this on
screen and stops:

```text
Unlock Login Keyring — Authentication required
The login keyring did not get unlocked when you logged into your computer.
```

The container has no session bus of its own, so nheko gets one from D-Bus
activation, gnome-keyring starts inside it **locked**, and there is no desktop
session that could have unlocked it at login.

**Unlocking from a setup-command does not fix it.** That runs in its own
short-lived shell with its own `DBUS_SESSION_BUS_ADDRESS`; nheko launches later
on a different bus and never sees it. `common/keyring.sh` says as much and it
is confirmed here: the unlock has to happen *inside the same session as the
application*.

`install.sh` therefore puts a wrapper at `/usr/local/bin/nheko` that runs
`dbus-run-session`, unlocks the keyring inside it, and execs the real binary.
Verified: with the wrapper, nheko comes straight up on the room list — no
prompt, no login screen.

## Where the session lives

Measured, and the split is the useful part:

| Path | What it is |
| ---- | ---------- |
| `~/.config/nheko/nheko.conf` | `access_token`, `device_id`, `user_id`, `home_server` |
| `~/.local/share/keyrings/` | the E2EE pickle key — what the prompt above wants |
| `~/.local/share/nheko/nheko/<hex-mxid>/` | the LMDB **cache** (the synced state) |

So nheko is one of the *separable* clients: the session is a config file and
the cache is its own tree.

### A captured profile does not work, and this is not a nheko problem

The obvious move — log in by hand, tar the config, restore it as a
setup-command — was tried and **fails**:

```text
nheko: dropping to the login page: Failed to setup encryption keys.
       Server response: Invalid access token passed. 401.
```

An access token is **server** state. Logging in writes a row to the
homeserver's database, and that write happens in the *running* container; it is
not in the image. GMT builds fresh containers for every run, so the homeserver
comes back from the image having never heard of the token, and the restored
profile points at a session that no longer exists. Nothing about the client is
wrong — rebuilding the server revoked the credential.

This applies to **every client in the group**, not just nheko. Any
`profile.tar.gz` carrying a Matrix session is stale the moment the homeserver
container is recreated.

The session therefore has to be created in the same run that uses it, and
**the scenario signs in itself** — `script.md` block 2. No seeding of any kind
appears in `usage_scenario.yml`.

`common/seed-session.sh nheko` is an alternative that also works: it logs in
over the API as a setup-command and templates `nheko.conf`, verified to bring
nheko up signed in with no cache. It is not used, because signing in through
the UI is the only arrangement that gives all six clients the *same* block 1.
Its one non-obvious detail is worth keeping either way: `user_id` must be
written with a **doubled leading `@`** (`@@parrot:parrot.test`), because
QSettings escapes a leading `@` — it introduces special values like
`@Invalid()`. A single `@` makes nheko read an empty user id and drop to the
login page.

## Blocks 2 and 3 — Sign in, Initial sync

This is the scenario's own path now, not a capture step: `script.md` block 2
signs in through the UI. Driven twice from clean containers with identical
results.

1. Welcome screen: `REGISTER` / `LOGIN` buttons. **LOGIN at (801, 582)**.
2. Form appears: Matrix ID / Password / Device name.
   **Matrix ID field at (720, 424)** — type `@parrot:parrot.test`.
3. **The layout changes here.** nheko tries `.well-known` autodiscovery on
   `parrot.test`, fails (there is no such service on this network), prints
   *"Autodiscovery failed. Unknown error while requesting .well-known."* and
   **inserts a "Homeserver address" field**. Everything below the Matrix ID
   moves. Typing the password immediately after the Matrix ID puts it in
   **Device name** instead — confirmed by doing it.
4. So: after autodiscovery fails, set **Homeserver address (720, 547)** to
   `http://matrix.parrot.test:8008`, clear **Device name (720, 490)**, and only
   then fill **Password (720, 453)**.
5. **LOGIN at (720, 656)**. This ends block 2.

Block 3 is then everything that happens on its own plus the prompts:

1. A **Setup Encryption** wizard appears (cross-signing / online key backup).
   Declined with **Cancel at (1373, 861)** — the corpus is unencrypted, so
   there is nothing to set up, and accepting would start real key generation
   that belongs in no block.
2. A yellow **"Encryption not set up"** banner remains in the room list.
   Dismiss with the **× at (208, 65)**, or it is baked into all 23 reference
   images.

Timing, for pacing the driver: the room list is populated and the wizard is up
well within **20 s** of pressing LOGIN; 60 s was comfortably settled. The
recording should not pace this from a stopwatch though — the whole point of
block 3 is that its duration is the measurement.

## What the room list looks like when synced

Confirmed against the **v1** corpus (`MATRIX_HISTORY=8000`): unread badges of
**7999** for Aurora Release, **600** for Windvane Deployment, **400** for Field
Photos and **20** for each of the sixty fillers, with dates rendered as
**30 Jun 2026**. The smaller numbers quoted in earlier notes were the `dev`
image; the two corpora are not interchangeable and the reference screenshots
belong to v1.

That last one is the `?ts=` decision paying off: the corpus is stamped in the
past, so nheko renders an absolute date rather than "today" or a clock time,
and the reference screenshots will not rot. See `matrixserver/seed_corpus.py`.

The room-list pane is ~220 px wide and truncates names to about eight
characters (`Wind...`, `Auror...`). That is nheko's default and is left alone —
the benchmark measures the client as shipped — but it means the reference
screenshots identify rooms by position and badge, not by readable name.

## Block 1 — Load app

From a clean pair of containers built by `setup-container.sh nheko`, with no
seeding of any kind, nheko settles on its **welcome screen** — the nheko logo,
`REGISTER` and `LOGIN`, and a "Reduce animations" toggle — at 1440x900. No
first-run modal, no update nag, nothing to dismiss. The block is a wait.

Which is what `script.md` block 1 asks for: "settle on its first screen — a
welcome or sign-in screen for every client in this group".

## Navigation: never click a room in the room list

**This is the most important measurement on the page.** nheko ships with
`sort_by_unread=true`, so the room list is ordered by unread state first — and
*reading a room reorders the list underneath you*. Confirmed: after opening
Aurora Release it left the top of the list entirely and Windvane Deployment
took its place. A macro that clicks row 1 twice opens two different rooms, and
every count still matches.

Two seeded rooms are worse than reordered, they start at the bottom: **Parrot
Echo** and **Parrot Firehose** hold only messages from `@parrot` itself, which
are never unread, so they sort below all sixty filler rooms. Reaching them by
scrolling would be both slow and fragile.

The fix is a keyboard primitive that does not care about order at all:

```text
Ctrl+K            open the room switcher (tooltip: "Search rooms (Ctrl+K)")
<type room name>  fuzzy match; the EXACT match is ranked first and preselected
Return            open it
```

Verified end to end on Aurora Release. The switcher can also be opened by
clicking the magnifier at **(152, 880)**, but `Ctrl+K` is preferred: it is one
event instead of a click plus a position.

Every block that opens a room should use this. It is also why the corpus
timestamp stagger, while still correct and worth having, is no longer
load-bearing for the recording.

## Timeline primitives

| Action | How | Notes |
| ------ | --- | ----- |
| Scroll back | `Prior` (PageUp), pointer over the timeline | Confirmed to move: each press produced a different capture. Older batches load as it goes |
| Jump to live | click **(1401, 810)** | The circular ↓ button. **`End` does NOT work** — tried, the timeline stayed where it was |
| Member list | click **(1343, 28)** | Opens a SEPARATE window titled "Members of Aurora Release", reporting **509 people**. Close with **OK at (374, 654)** |
| Composer | click **(700, 880)**, then type | Placeholder "Write a message…" |
| Attach | paperclip at **(279, 880)** | For the upload block |
| Emoji picker | **(1382, 880)** | For the reaction block |
| Send | **(1420, 880)** or Return | |

### The member list is a second window, and checkpoints must account for it

`record-macro.py` captures
`xdotool search --onlyvisible --class nheko | head -n1` — the FIRST match, not
the largest — and the member dialog shares nheko's WM_CLASS. A checkpoint taken
while it is open can photograph the dialog instead of the main window, and that
image becomes what every future replay is measured against. This is exactly the
trap the word-processor group's `CP()` guards against by asserting the captured
geometry is 1440x900; the chat driver needs the same assertion.

## Message actions: right-click, do not hover

nheko reveals a four-icon bar (react / thread / reply / options) on hover at the
message's top-right. **Do not use it.** Two reasons, both measured:

- The reply icon sits at **(1401, 810)** — the *same point* as the jump-to-live
  button. Which one is there depends on whether the timeline is scrolled, so
  the same click does two different things at two points in the scenario.
- Clicks on it did not register reliably; two attempts left the composer
  untouched and simply dismissed the hover.

**Right-click the message body instead.** It opens a labelled context menu,
anchored so its *bottom* sits just above the click, growing upward, with items
25 px apart. Verified against two different click positions:

| Menu | Items | Offset from click y |
| ---- | ----- | ------------------- |
| Someone else's message | 9 | React `−188`, Reply `−163` |
| Your own message | 11 | Edit `−188` |

Menu x is comfortably **click_x + 60**.

The offsets differ because the own-message menu inserts *Edit* and *Remove
message*. Do not reuse one table for both.

### Better still: the items have mnemonics, so use no coordinate at all

Every entry is underlined-letter accessible, and pressing the letter with the
menu open activates it — no `Alt`, no arrow keys:

| Key | Item |
| --- | ---- |
| `a` | Re**a**ct |
| `y` | Repl**y** |
| `e` | **E**dit (own messages only) |
| `c` | **C**opy |
| `t` | **T**hread |

This is what the driver uses, and it makes the table above documentation rather
than something the recording depends on. It matters because the menu is
anchored to the click, so every item moves with the message — and the message
moves after every send, reply and reaction. The mnemonic is the same keystroke
wherever the message happens to be.

Verified end to end: `y` opened the reply composer quoting the correct message,
`e` opened the editor on the correct one.

## The cluster, measured and ground-truth verified

Each of these was driven and then checked against the homeserver with
`matrix-truth.py` — not against the screenshot.

| Block | How | Server said |
| ----- | --- | ----------- |
| Send | click composer **(700, 880)**, type, `Return` | — |
| Reply | right-click msg → `y−163` → type → `Return` | `[reply] '> <@nadia…> Ship it when…\n\nAgreed'` — a real `m.in_reply_to` |
| React | right-click msg → `y−188` → picker **Search (700, 544)** → type `thumbs up` → first hit **(595, 585)** | `@parrot reacted '👍' -> 'Ship it when the smoke tests are green.'` — right emoji, **right target event** |
| Edit | right-click own msg → `y−188` → `ctrl+a` → type → `Return` | `[edit] '* Agreed, going out today indeed'` — a real `m.replace`, not a new message |
| Upload | paperclip **(279, 880)** → File name **(720, 845)** → type `/tmp/parrot.png` → `Return` → **"Upload file" (1307, 841)** | `[m.image] 'parrot.png'` |
| Join | **+ (66, 880)** → "Join a room" **(110, 815)** → field **(190, 103)** → alias → Join **(248, 131)** | `Parrot Lobby JOINED` |
| Create | **+ (66, 880)** → "Create a new room" **(110, 839)** → Name **(150, 124)** → **Public toggle (212, 288)** → Create Room **(119, 440)** | `Parrot benchmark JOINED`, and the timeline records "parrot opened the room to the public" |
| Room menu | **⋮ (1415, 28)** → Invite users **(1365, 55)**, Members **(1365, 80)**, Leave room **(1365, 105)** | — |

### Two traps in there worth stating plainly

**The upload needs a second click.** nheko does not send on file selection — it
shows a preview with **"Upload file" / "Cancel"**. The first attempt selected
the file, the dialog closed, the timeline looked busy, and the server had
nothing. Confirmed by ground truth, invisible on screen.

**The invite needs the search result selected.** Typing `@alice:parrot.test`
into the invite field and pressing Invite sends **no invite at all** — the
dialog closes and looks successful, and the room's member events show only
`@parrot`. The result row (**(230, 193)**, "Alice Brenner") has to be clicked
first. This one is still not verified end to end: a second attempt stacked two
invite dialogs on top of each other and `Escape` did not close them, so the
sequence needs one clean pass in a fresh container.

## The file dialog defeats the usual checkpoint guard

`record-macro.py` captures the FIRST window matching the class. nheko's
"Select a file" dialog is **also 1440x900**, so the geometry assertion the
word-processor group's `CP()` uses cannot tell it from the main window. The
member-list and Join/New Room dialogs are smaller and would be caught by
geometry; this one would not.

Asserting on the window **name** instead does not rescue it, for the reason in
the image-viewer section: the main window's title carries a live unread count
(`nheko (9799)`), so only a prefix test matches it — and a prefix test also
matches the viewer and the file dialog. **No single assertion separates them.**
What works is closing the extra window before the checkpoint, which the driver
does, and taking the two deliberate ones knowing which window is on top.

## Screenshots after the first sent message contain today's date

The moment the scenario sends anything, nheko inserts a day separator with the
**wall-clock** date ("Saturday, 8 August") and a live timestamp. Every
reference image from the send block onwards carries it. The seeded corpus is
frozen in the past precisely to avoid this, but messages the scenario itself
sends cannot be. Expect a small, permanent RMSE floor on those checkpoints, and
expect it to grow slowly as the rendered date string changes length.

## The photo room rendered nothing, and it was the server's fault

`Field Photos` came up as a grid of broken-image icons. Three blocks of the
scenario - open photo room, view image full size, scroll thumbnails - were
measuring a placeholder glyph.

```text
[net] [error] Failed to download parrot.test/hVyeUPGzJQHhQUaaPcJwreOI:
              (http: 404, matrix: M_NOT_FOUND:'Not found')
```

Nothing was missing. 2000 files sat in the media store, and the same id served
609437 bytes over `/_matrix/client/v1/media/download` with a token. Synapse
1.120+ defaults `enable_authenticated_media` to true, which 404s the legacy
`/_matrix/media/v3/download` - and nheko 0.11.3 only speaks the legacy one.

Fixed in `matrixserver/conf/homeserver.yaml`, which now sets it false: the
authenticated endpoint keeps working, the legacy one starts working again. The
flag is recorded per media row at upload time, so the corpus had to be
re-seeded, not just reconfigured. `smoke_test.py` now fetches the anchor image
over **both** endpoints and compares the bytes, because every other check in it
passed while the room was rendering placeholders.

Worth stating for the other five clients: this was never an nheko bug. Any
client on the pre-v1.11 media API would have shown the same empty room, and the
group would have compared a client that decodes 400 images against clients that
decode none.

## Dialogs cascade, so prefer the keyboard

`pin-windows.sh` pins the main window and sets `CascadePlacement`. nheko's
dialogs share its `WM_CLASS`, and they are placed by the cascade - each new one
**23 px down and right of the last**, and the counter never resets:

```text
New Room, 1st time in the session   X=1   Y=45
        2nd                         X=24  Y=68
        3rd                         X=47  Y=91
```

Closing a dialog does not wind it back. So a dialog's position is a function of
how many dialogs opened before it, which means a click coordinate measured in
one exploratory session is wrong in the next. This is what left two stacked
invite dialogs behind last time: the Cancel click was aimed where the *first*
dialog's button had been.

It is reproducible for a fixed sequence of actions, so a recording would work.
It is still not worth relying on, because every dialog would need its own
coordinate computed from its position in the run. **Driving the dialogs by
keyboard removes the dependency entirely**, and keystrokes are input events, so
xmacrorec2 records them - unlike an `xdotool windowmove`, which it would not.

| Dialog | Keyboard route | Verified |
| ------ | -------------- | -------- |
| New Room | name has focus on open: type it, `Tab`x3, `space` (Public), `Tab`x3, `space` (Create Room) | `Parrot benchmark JOINED`, public |
| Invite users | type the mxid, `Return`, `Tab`x2, `space` | `membership: invite` for Alice |
| Join room | `Tab`, `shift+Tab`, type the alias, `Return` | `Parrot Lobby JOINED` |
| Leave room | `Return` confirms | `Parrot Lobby: not a member` |

### The Join dialog does not focus its own field

Typing straight into it goes nowhere - the window has keyboard focus
(`xdotool getwindowfocus` returns the dialog) but no widget does, and the text
is discarded silently. Waiting longer does not help; six seconds and a full
mxid produced an empty field. `Tab` lands on **Cancel**, and `shift+Tab` from
there lands in the text field. Confirmed twice.

### The invite needed one keystroke, not a click

Typing the mxid and pressing Invite sends nothing, which is what was unresolved
last time. The result row has to be moved into the right-hand *selected* pane
first - and **`Return` does it**, no click and no coordinate. A second `Return`
does *not* press Invite; only `Tab` `Tab` `space` does. Ground truth:

```text
m.room.member @parrot:parrot.test {"displayname": "Alice Brenner", "membership": "invite"}
```

## The room ⋮ menu changes shape per room

Not a fixed menu. In `Parrot benchmark`, which parrot created, it has four
items; in `Parrot Lobby`, where parrot is an ordinary member, **Invite users is
absent** and everything moves up 25 px:

| Room | Items | Leave room at |
| ---- | ----- | ------------- |
| Parrot benchmark (creator, PL 100) | Invite users, Members, Leave room, Settings | (1367, 105) |
| Parrot Lobby (plain member) | Members, Leave room, Settings | (1367, 80) |

Clicking (1367, 105) in the lobby opens **Settings**, not the leave
confirmation - done by accident, and the wrong window opens without any error.
The menu's own geometry gives it away: 139x100 for four items, 139x75 for
three.

## Two checkpoints cannot prove their own block happened

A consequence of the rule above, and it should be stated rather than discovered
later from a byte-identical pair in `verify-client.sh`:

- **Block 7 (member list)** ends by closing the dialog, so its capture is the
  Aurora timeline — the same pixels as block 6's.
- **Block 9 (image viewer)** ends by closing the viewer, so its capture is the
  Field Photos timeline — the same pixels as block 8's.

`verify-client.sh` reports both pairs, and they are the only two:

```text
=== identical consecutive checkpoints ===
    nheko-check-006.png == nheko-check-007.png
    nheko-check-008.png == nheko-check-009.png
```

There is no arrangement that fixes it. Capturing while the extra window is open
does not help, because the recorder raises the main window before importing,
so it photographs the main window either way. And ground truth cannot help
either: opening a member list or an image viewer is a read, not a server-visible
mutation, so `matrix-truth.py` has nothing to report.

**What this does and does not invalidate.** The work still happens and is still
measured — 509 avatars are fetched and decoded, a full-size image is decoded and
scaled — and energy is what the benchmark is for. What is lost is the
*screenshot* as evidence that the block ran. If block 7 silently stopped opening
the member list after an nheko update, these checkpoints would keep passing.
Comparing the same block across two clients is the only thing that would catch
it, which is the same blind spot AGENTS.md describes for every ground truth in
this repo.

## The image viewer defeats both checkpoint guards

Opening an image full size maps a **second window that is also 1440x900**, also
`WM_CLASS "nheko", "nheko"` - and titled plain `nheko`. Meanwhile the main
window's title carries the unread count:

```text
[nheko (9799)]  X=0 Y=0 WIDTH=1440 HEIGHT=900     <- main
[nheko]         X=0 Y=0 WIDTH=1440 HEIGHT=900     <- image viewer
```

So the geometry assertion cannot separate them, and neither can an equality
test on the name - `== "nheko"` matches the *viewer* and rejects the main
window. Anything asserting on the title has to accept a `nheko*` prefix, which
then matches both. The practical rule: the viewer is closed with `Escape`
before any later checkpoint, and the one checkpoint taken while it is open is
meant to photograph it.

`Escape` closes it cleanly - confirmed, one window left afterwards.

## The remaining blocks, measured

| Block | How | Result |
| ----- | --- | ------ |
| Open photo room | `Ctrl+K` `Field Photos` `Return` | 400 images, thumbnails decode |
| View image full size | click the newest thumbnail **(523, 685)**, `Escape` to close | full-screen viewer window |
| Scroll thumbnails | pointer over the timeline, `Prior` x5 | reached 11 June from 30 June |
| Echo round trip | `Ctrl+K` `Parrot Echo`, composer, `ping` | `echo: pong` inside 6 s |
| Idle quiet | `Ctrl+K` `Parrot Firehose`, then nothing for 60 s | settles, nothing arrives |
| Idle receiving | send `drip`, wait ~130 s | `24 drip message(s)`, contiguous `drip 01..24` |

## Sign-in: the LOGIN button moves while you fill the form

Two positions matter and they are not the same. While the autodiscovery error
is on screen it wraps to two lines and pushes the button down; filling the
homeserver field clears the error and everything springs back up:

| State | Password | LOGIN |
| ----- | -------- | ----- |
| autodiscovery error showing | (720, 445) | (720, 676) |
| homeserver filled, error gone | (720, 453) | (720, 656) |

So fill the **homeserver first, password second** - which is also the order
that avoids typing the password into Device name. The field order on screen
(ID, Password, Device name, Homeserver) is not the order to fill them in.

## Relaunching nheko comes back signed in

Killing nheko and starting it again puts it straight on the room list: the
token is in the keyring, which lives in the container's home directory and
survives the process. The **Setup Encryption wizard reappears on every launch**
until encryption is actually set up, so it is not a first-run-only prompt.

Irrelevant to a real run, which launches once - but it means a measuring
session does not have to sign in again after a crash, and that the wizard
dismissal is not something the recording can skip.
