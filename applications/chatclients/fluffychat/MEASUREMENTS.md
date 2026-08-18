# FluffyChat — measured landmarks

FluffyChat 2.8.0 (Flathub, commit `104c4950b04a…`, runtime `org.gnome.Platform//50`)
in the benchmark container at 1440x900.

**RECORDED AND REPLAY-VERIFIED.** All 23 blocks measured, and `fluffychat.parrot`
replays **23/23 PASS, 0 FAIL** against fresh containers with a worst RMSE of
**0.0178** against a 0.2 threshold — the tightest of the group so far. Every
mutating block was confirmed against the homeserver, including the target events
of the reply, the reaction and the edit. Two consecutive-checkpoint pairs are
identical and that was run down rather than waved through; see the section near
the end.

Flutter paints every control itself onto a single
surface, and that shows up here in a way it does not in the other five: there is
**exactly one X window for the entire session** — no menus, no tooltips, no
dialogs, no file chooser of its own. The checkpoint guard's window-count check,
which does real work in Fractal, is close to a formality here; the one thing it
does catch is the XDG portal chooser, which is a separate process.

## Window identity

`WM_CLASS(STRING) = "fluffychat", "Fluffychat"` — `pin-windows.sh` gets
**`fluffychat`**.

**The two halves differ in case**, unlike Fractal where both are identical. `pin-windows.sh` matches res_name, the first field, so it needs the
lowercase one. Measured without the argument the window came up **864x720 at
(288, 121)** instead of 1440x900 at the origin — silently, because a rule that
matches nothing applies nothing.

## Block 1 — Load app

Welcome screen, nothing to dismiss: **Create new account (720, 577)**,
**Sign in (720, 645)**, *Login with Matrix-ID (720, 690)*.

The third route takes a full MXID and autodiscovers over HTTPS at the MXID's
domain, which cannot work against this homeserver — it is what removed the sixth
entrant from the group. **Do not use it.** *Sign in* asks for the server first,
which is the route script.md's block 2 describes and the one Element and
SchildiChat take.

## Block 2 — Sign in: THE TYPED SERVER MUST BE SELECTED BEFORE CONTINUE APPEARS

Server first, defaulting to a list of matrix.org / mozilla.org / tchncs.de.

1. **Sign in (720, 645)**.
2. Click the field **(720, 258)** and type `http://matrix.parrot.test:8008`.
   The scheme and port are accepted as typed.
3. **The typed address becomes a RESULT ROW, not the answer.** It appears as
   `http://matrix.parrot.test:8008 / A matrix homeserver` with an **unselected**
   radio button, the list grows to fill the card, and **the Continue button is
   pushed off the card entirely**. Clicking where Continue used to be hits the
   list and does nothing.
4. Select the row **(686, 334)**. The radio fills and **Continue comes back** at
   **(720, 705)**.
5. **Continue (720, 705)** → the login form, headed
   `Log in to http://matrix.parrot.test:8008`.
6. **Matrix ID (720, 346)** is focused and accepts a **bare localpart** —
   `parrot` — despite the `@username:domain` placeholder, because the server is
   already chosen. **Password (700 … 720, 410)**, then **Login (720, 476)**.

## Block 3 — "SKIP" DOES NOT SKIP, and the key screen is random per run

Immediately after sign-in: **Set Up Crypto Identity**, asking for a passphrase,
with **Continue** (disabled until the passphrase rules pass) and **Skip
(720, 485)**.

script.md block 3 says to dismiss the encryption-setup prompt, and *Skip* is the
obvious reading. **It does not dismiss anything.** It skips only the
*passphrase*: FluffyChat then generates a recovery key anyway and shows it —

```text
EsTf DDUz V71m XSnL KcrB itbq ZJzw dX98 FHbd VAVw Raak nRsm
```

— twelve random groups, **different on every run**, in a large high-contrast
block, with *Save as file* and *Store securely on this device* checkboxes left
unchecked and **Continue (886, 142)**.

**Never checkpoint that screen.** This is the same trap as Fractal's recovery
key, and it is worse than a clock: it is a big region, so it would blow past the
0.2 RMSE threshold rather than nudging it. Block 3's checkpoint goes after
*Continue*, on the synced chat list.

So **FluffyChat and Fractal both do unavoidable cross-signing work in block 3**
that the three non-Flatpak clients do not. The earlier claim that this was
unique to Fractal is wrong and is corrected in the README.

## Blocks 4, 8, 12, 18, 21, 22 — navigation, and the ONE THAT SENT TO THE WRONG ROOM

Rooms are opened through the search field at **(270, 36)**: click it, `ctrl+a`,
type, then click the result. Typing filters into sections — *Public Rooms*,
*Public spaces*, *Users*, *Chats* — which is the multi-section shape script.md
block 11 anticipates.

### The result row is NOT at a fixed position, and getting it wrong is silent

Measured the hard way. For `Aurora Release`, `Field Photos`, `windvane`,
`Parrot Lobby` and `Parrot Firehose`, the four section headers sit at y = 88,
121, 154, 187 and the single *Chats* result is at **(270, 252)**.

For **`Parrot Echo` it is at (270, 348)**, because the query also matches the
**`echo` bot user**, so a *Users* section with an avatar tile is inserted above
*Chats* and everything below it moves down ~96 px.

Clicking 252 for Parrot Echo lands in the Users section, opens nothing, and
**leaves the previous room on screen**. The `ping` that block 18 types then goes
to whichever room was already open — in the measuring run, to Windvane
Deployment. No error, no visual cue that anything is wrong, and `matrix-truth
sent --room parrot-echo` would simply report nothing. Every room's row position
is therefore pinned individually in the driver.

## Block 5 — `Prior` does nothing; the wheel is 53 px per notch

Three `Prior` presses left the view **byte-identical** (`shift=0px
meandiff=0.00`) — the same trap as Fractal, and the same family as `End` not
jumping to live in Element and nheko.

Measured by cross-correlating screenshots five notches apart:

```text
5 notches -> 264 px    5 notches -> 266 px    5 notches -> 266 px    5 notches -> 264 px
```

**~53 px per notch.** (The ±2 px is the measuring script's own resolution — it
downsamples by 2 — not the client.) The timeline viewport is ~760 px, so:

> **one screen = 14 notches** (742 px)

| Block | Other clients | FluffyChat |
| ----- | ------------- | ---------- |
| 5 Scroll back, ten screens | `for 1..10: Prior; sleep 2` | `for 1..10: wheel 14; sleep 2` |
| 10 Scroll thumbnails, five screens | `for 1..5: Prior; sleep 3` | `for 1..5: wheel 14; sleep 3` |

## Block 6 — Jump to live

Scrolling up raises a jump-to-bottom button at **(1404, 792)**. Verified
properly rather than by eye: after ten screens back, one click returns the
timeline **byte-identical** to the pre-scroll live view (`shift=0px
meandiff=0.00`).

## Block 7 — Chat details is an IN-WINDOW PANEL that narrows the timeline

Click the room header **(587, 29)** → a *Chat details* panel opens on the right
with the 509 participants and their avatars. In-window, like Element and
SchildiChat, not a separate window like Fractal.

**It narrows the timeline while open** — the composer moves from (950, 856) to
(760, 856) and the `⋮` from (1404, 36) to (1024, 36) — so every later coordinate
is wrong until it is closed. Close with **× (1088, 36)**.

## Block 8 — thumbnails decode BY DEFAULT

Unlike Fractal, FluffyChat does not implement MSC4278 media previews and renders
the 400 `Field Photos` thumbnails with no configuration at all. **No seeding is
needed for this client**, and blocks 8 and 10 are directly comparable with
nheko, Element and SchildiChat.

## Block 9 — View image full size

Click the newest image **(762, 707)**. In-window viewer, image at full size,
close **× (28, 36)**.

The viewer shows no filename, so the target was confirmed on the server instead:
the newest event in `Field Photos` is `reservoir-at-first-light.jpg` from
`@kwame:parrot.test`, which is the image script.md names.

## Blocks 13-16 — LONG PRESS, not right-click

Own messages are **right-aligned** here, as in SchildiChat.

**Right-click is the wrong affordance and looks like the right one.** It opens
Flutter's own text-selection menu — a single *Select all* item — and no message
action. A plain left-click does nothing at all.

The affordance is a **long press: mousedown, hold ~1.2 s, mouseup**. That puts
the whole view into a selection mode:

* the top bar turns pink and shows the selected count;
* every message grows a checkbox;
* the selected message grows a **quick-reaction row** — 👍 ❤️ 😂 😮 😢 and a
  *custom reaction* button;
* the bottom bar becomes **Forward (622, 856)** and **Reply (1288, 856)**.

### The top-bar icon row is RIGHT-ALIGNED, so it shifts with the message

| Selected | Icons, left to right |
| -------- | -------------------- |
| someone else's message | quote (1324), copy (1364), ⋮ (1404) |
| **own message** | **edit ✏ (1244)**, quote (1284), copy (1324), delete 🗑 (1364), ⋮ (1404) |

Block 16 clicks **(1244, 36)**, which on a *received* message is not the edit
button but empty bar. The `⋮` menu is **not** where Edit lives — it holds only
*Message info* and *Report message*.

Edit pre-fills the composer with the old text; `ctrl+a` then retype, as the
other clients do.

### TARGET THE ORIGINAL, NOT THE QUOTE

Live here as everywhere: after block 14 the reply renders a quoted copy of
Nadia's text at y≈735 while the original is at y≈547. Block 15 long-presses
**(804, 547)**.

Confirmed with `matrix-truth targets`, which resolves the target's **sender**:
both the reply and the 👍 land on `@nadia:parrot.test :: 'Ship it when the smoke
tests are green.'`

**FluffyChat includes the rich-reply fallback in the body**, unlike Fractal:

```text
[reply] '> <@nadia:parrot.test> Ship it when the smoke tests are green.\n\nAgreed'
```

so `matrix-truth sent` truncates it to something that looks like the word
`Agreed` — the trap HANDOFF.md records for SchildiChat, alive in this client too.

### Block 15 uses the QUICK-REACTION ROW, and that is a deviation

The custom-reaction button opens a full picker, headed *Custom reaction*, with
category tabs. **👍 is below the fold in it and the grid does not scroll with
the wheel** — 12 notches over the grid moved it 0 px, measured.

So block 15 clicks **👍 (650, 549)** in the quick-reaction row instead. It is
FluffyChat's primary reaction affordance and the grid is explicitly for emoji
*outside* that set — but it means **no full emoji picker is rendered here**,
while the other four clients do render one before clicking 👍. That has to be
stated in the results.

## Block 17 — same portal, same FUSE wall, same clipboard answer as Fractal

The `+` at **(602, 856)** opens *Start poll / Send image (667, 744) / Send video
/ Send file*. *Send image* opens **the XDG portal**, not a dialog of FluffyChat's
own:

```text
win 6291460 [flutter picker] class="xdg-desktop-portal-gtk" X=172 Y=60 1096x843
```

and it fails exactly as Fractal's does, for exactly the same reason:

```text
fusermount3: fuse device not found, try 'modprobe fuse' first
error: fuse init failed: Can't mount path /run/user/1001/doc
xdg-desktop-portal: Failed to register file:///tmp/parrot.png ... NoReply
```

No event reaches the room, and nothing on screen says so. Making it work costs
`CAP_SYS_ADMIN`, dropped on purpose in commit cbe1099 — the full measurement is
in [../fractal/MEASUREMENTS.md](../fractal/MEASUREMENTS.md) block 17.

**So block 17 pastes**, via [../common/seed-clipboard.sh](../common/seed-clipboard.sh),
the same as Fractal. Two differences worth knowing:

* The paste raises a dialog headed **"Send file"** with a document icon rather
  than an image preview — but it still sends a real **`m.image`** with
  `mimetype: image/png`. Send is at **(816, 546)**; *Send is the step that
  uploads*, the dialog closing means nothing.
* **The body is EMPTY**, not a filename. Fractal's paste produces `image.png`;
  FluffyChat produces `''`. Anything matching on the body across clients has to
  expect both.

Note the portal window sits at **(172, 60)** here and at **(1, 45)** for Fractal,
so its accept button is at a different place in each — not that the driver ever
clicks it now.

## Block 19 — Join room

Type `#parrot-lobby:parrot.test` into the search. It appears as a tile under
**Public Rooms** at **(123, 145)** — a tile, not a list row. Clicking it opens a
room card with *report / Copy / Share* and **Join room (720, 519)**.

Verified as real membership, not a peek: `Parrot Lobby JOINED`.

## Block 20 — the + button defaults to SPACE, not a room

**The trap in this block.** The `+` at **(40, 100)** opens *New space*, with a
**Group | Space** toggle already set to **Space**. Left alone it creates an
`m.space`, which is not a room, is not what script.md asks for, and is not what
the other clients produce.

**Click Group (902, 156) first.** The form becomes *Create group*:

* **Group name (950, 360)** — type `Parrot benchmark`
* **Group is public (1174, 428)** — off by default; turning it on reveals a
  third row, *Group can be found via search*, already on
* **Enable encryption** — **off by default**, unlike Element and SchildiChat
* there is **no room-address field**; FluffyChat does not require one
* **Create a group and invite users (950, 610)** — note this moves down 56 px
  when the public toggle adds its extra row

Creating goes straight to an **Invite contact** page: field **(950, 168)**, type
`@alice:parrot.test`, and the result row carries an **Invite (1180, 244)** link
which flips to *Participant* once sent.

Verified on the server rather than by the label changing:

```text
room: Parrot benchmark !PvxxkQTTQwxSIVtUXC:parrot.test
  m.room.create type: None          <- a normal room, NOT a space
  join_rule: public
  @alice:parrot.test -> invite
  @parrot:parrot.test -> join
```

with no `m.room.encryption` event.

## Block 21 — Leave

`⋮ (1404, 36)` → *Chat details / Mute chat / Search / Encryption / Emote
Settings /* **Leave (1324, 288)** → confirmation *"Are you sure?"* →
**Leave (815, 516)**.

## Blocks 22-23 — the idle pair

`Parrot Firehose` opens from search at **(270, 252)**. Settle, 60 s untouched,
then composer, `drip`, Return, 130 s. All 24 arrived, rendered and were on
screen at the end: `contiguous: drip 01 .. drip 24`.

## park() goes on the NAV RAIL, not the timeline

Hovering a message draws a **row highlight** that is baked into the reference
image — confirmed by comparing two captures that differ only in pointer
position. The timeline is therefore not a safe park.

`park()` uses **(40, 450)**: the empty stretch of the left nav rail, between the
`+` at y=100 and the compose button at y=860. No widget there, and it is outside
the timeline entirely.

## BLOCKS 7 AND 9 HAVE A VERIFICATION GAP — their checkpoints prove nothing

`verify-client.sh` flagged two pairs of byte-identical consecutive references:

```text
fluffychat-check-006.png == fluffychat-check-007.png     (Jump to live == Open member list)
fluffychat-check-008.png == fluffychat-check-009.png     (Open photo room == View image full size)
```

That check exists because **a recording that did nothing replays perfectly** —
identical references match identical captures and every check passes. So this
was run down rather than waved through, and the answer is *legitimate, but with
a caveat that matters*.

Both blocks open an in-window overlay and close it again, and in FluffyChat
closing restores the underlying view **to the pixel**. Reproduced by hand,
following the driver's exact sequence:

| Test | Overlay opened? | Identical after closing? |
| ---- | --------------- | ------------------------ |
| block 6 → 7 (scroll back, jump to live, open, close) | **yes** | **yes** |
| block 8 → 9 (open Field Photos, settle, open viewer, close) | **yes** | **yes** |

Two false alarms had to be cleared on the way, and both are worth knowing:

* Opening `Aurora Release` *fresh* and doing the same open/close does **not**
  come back identical — the scroll anchoring differs. It only restores exactly
  when the timeline is bottom-pinned, which is what block 6's jump-to-live does.
* In `Field Photos` the first comparison also failed, purely because thumbnails
  were still decoding during the "before" capture. With a longer settle it is
  identical.

**The caveat**: the overlays genuinely open, so the work — 509 avatars loading,
a full-size image rendering — is really being measured, and the energy figures
for blocks 7 and 9 are sound. But their *screenshots* cannot tell "did the work"
apart from "did nothing". If a future coordinate drift made block 7 miss the
header, the replay would still report 23/23. Those two blocks are covered by the
energy measurement and by nothing else, and a change to this driver must not
lean on the image check to catch a mistake in them.

The other five clients do not have this: Fractal's `verify-client.sh` reports
*"none — every checkpoint differs from the one before it"*.

## What every mutating block was checked against

Not screenshots. Blocks 13, 14, 15, 16, 17, 19, 20, 21 and 23 were each
confirmed against the homeserver, and blocks 14 and 15 had their **target
event** resolved with `matrix-truth targets`, because a reaction on the reply's
quoted copy rather than on the anchor is invisible on screen.
