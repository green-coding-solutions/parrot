# Element Desktop — measured landmarks

Everything here was read off a running Element in the benchmark container, not
inferred. Coordinates are for a window pinned to **1440x900 at 0,0** by
`common/pin-windows.sh element 1440 900`; they mean nothing at any other
geometry.

Version: `1.12.25` (packages.element.io).

**Read [`../nheko/MEASUREMENTS.md`](../nheko/MEASUREMENTS.md) first.** Most of
what it records — the fluxbox dialog cascade, the checkpoint/window-raise trap,
the authenticated-media setting — is about this harness and this homeserver, not
about nheko, and applies here unchanged.

## Window identity: the obvious guess is wrong

```text
main window                CLASS = "element", "element"
Electron's error dialog    CLASS = "element-desktop", "Element-desktop"
```

The binary, the Debian package and the PATH command are all
**element-desktop**. The main window's res_name is plain **element**.

Guessing `element-desktop` for `pin-windows.sh` would have matched only the
startup *error* dialog. The main window would never have been pinned, and
because a fluxbox rule that matches nothing applies nothing, there is no error —
the window simply lands wherever it likes at 1024x768 and every coordinate in
the recording drifts per run.

The title also carries a live unread count — `Element [63]` — so anything
asserting on the window name needs a prefix test, exactly as for nheko.

## Element will not run as root, and `--no-sandbox` does not save it

Measured. With `--no-sandbox` on the main process, Element reaches
`Opening main window` and then never maps one, while the log loops forever:

```text
ERROR:network_service_instance_impl.cc:721 Network service crashed or was
      terminated, restarting service.
FATAL:electron_main_delegate.cc:224 Running as root without --no-sandbox is
      not supported. See https://crbug.com/638180.
```

The flag reaches the browser process but not the utility process Electron
re-execs, so the network service dies and restarts in a tight loop. There is no
window, and nothing in the output names Element — it presents as a hang.

**The fix is to run as uid 1001**, the same non-root user the three Flatpak
clients already use, which is also what a real user does. `--no-sandbox` is
still required (no user namespaces in the container), but as a non-root user it
is now sufficient. nheko remains the only client running as root, because a
plain Qt binary genuinely does not care.

Expect SchildiChat to need exactly this too: it is the same Electron.

## The keyring: a secret service is necessary but not sufficient

With no secret service, Element stops on a modal before showing anything:

```text
System unsupported
Your system has an unsupported keyring meaning the database cannot be opened.
Electron's keyring detection did not find a supported backend.
[Cancel]  [Use weaker encryption]
```

Taking *Use weaker encryption* would measure a different program — it stores
secrets in plaintext, which is not what an Ubuntu user with gnome-keyring
running gets.

**Starting gnome-keyring did not fix it.** Measured: the dialog came back
unchanged with an unlocked secret service on the app's own session bus.
Electron chooses its backend from the desktop environment, and there is no
desktop environment here, so detection fails no matter what is listening. It
has to be told:

```text
--password-store=gnome-libsecret
```

With that **plus** a running unlocked gnome-keyring inside the application's own
`dbus-run-session`, Element comes up on its welcome screen with no prompt at
all. All three parts are required; each was removed and retested.

## Block 1 — Load app

From a cold pair of containers, Element settles on its welcome screen — the logo,
**Sign in (720, 322)** and **Create account (720, 374)** — at 1440x900. Nothing
to dismiss.

Timed on a container built from scratch by `setup-container.sh`: the window is
mapped at **4 s** and the welcome screen is painted at **7 s**.

### A mapped window is not a painted window

The first full recording of Element was thrown away because of this, and it is
worth describing because every guard in `drive-scenario.sh` passed while it
happened.

Element mapped its window in the first second and then sat on its **loading
spinner for about five minutes**. The driver, which waited a fixed 45 s, drove
blocks 1–6 against a white screen: the sign-in keystrokes went into nothing, and
by the time the welcome screen appeared the driver was at block 7. The result was
23 checkpoints of which six were the spinner and seventeen were the untouched
welcome screen — and `record-session.sh` reported *23 checkpoints, 23
screenshots, zero warnings*, because:

* there was exactly one window, so the count check passed;
* it was 1440x900, so the geometry check passed;
* no dialog was open, so nothing else tripped.

The five minutes has not reproduced — a cold rebuild paints in 7 s, and the
re-recording painted before the driver even started. It was almost certainly
host I/O contention, not an Element property. That is precisely why the guard
matters: an intermittent stall that cannot be reproduced also cannot be waited
out with a bigger `sleep`.

The fix is `wait_paint()` plus a size check in `CP()`. **Screen content is the
only signal that distinguishes these states**, and PNG size is a good enough
proxy for it:

| Screen | PNG |
| ------ | --- |
| Loading spinner | ~2.4 kB |
| Sign-in form, room list, timeline | ~120 kB |
| Welcome screen (photographic background) | ~1.88 MB |

So the threshold has to sit **just above the spinner**, not near the middle. A
threshold of 200 kB was tried first and warned on the perfectly good post-sign-in
screen, because flat UI compresses two orders of magnitude better than the one
screen with a photograph on it. 30 kB separates the two cleanly.

**The head time is deliberately the same as nheko's** — 20 s in
`record-session.sh`, 25 s in the driver, 5 s in `CP` — because it is measured
time. Giving one client a longer head makes its run cost more energy for a
reason that has nothing to do with the client. `wait_paint()` is inserted into
that budget rather than added on top of it.

## Block 2 — Sign in

Element asks for the **homeserver first**, which is the other route `script.md`
allows for. It defaults to matrix.org and needs an explicit edit:

1. **Sign in (720, 322)**.
2. Homeserver shows `matrix.org`. Click **Edit (999, 239)**.
3. A *Sign into your homeserver* dialog opens with **Other homeserver already
   selected and its field already focused** — no click needed, just type
   `http://matrix.parrot.test:8008`.
4. **Continue (714, 573)**.
5. The form becomes Username/Password with **Username focused (822, 354)**:
   type `parrot`, click **Password (822, 406)**, type `parrot`.
6. **Sign in (822, 502)**.

Element accepted the plain-HTTP homeserver without complaint — no certificate
warning and no "insecure server" gate, which is what makes the whole
no-TLS design work for this client.

## Block 3 — Initial sync

Signed in and fully synced inside 45 s, with badges matching the corpus:
**7999** Aurora Release, **600** Windvane Deployment, **400** Field Photos,
**20** per filler. Parrot Echo and Parrot Firehose show no badge, as expected —
they contain only the account's own messages.

Element renders **full room names**, unlike nheko's ~8-character truncation, so
reference screenshots here identify rooms by name rather than by position.

### Three prompts, and they arrive one after another

Not one prompt but a **chain**: each appears only once the previous is gone, and
the first does not appear until the sync is well under way. Dismissing them is
block 3's real work.

| Order | Prompt | Answer | At |
| ----- | ------ | ------ | -- |
| 1 | Back up your chats | **Dismiss** | (190, 192) |
| 2 | Help improve Element | **No** | (248, 152) |
| 3 | Introducing Sections | **Ok** | (751, 98) |

Why those answers: *Continue* on the first starts real key-backup generation and
the corpus is unencrypted; *Yes* on the second turns on analytics, which would
put network traffic of Element's choosing inside a measured run.

**The timing is the risk, not the coordinates.** Prompt 2 appeared several
seconds after the room list had finished populating — long after the block
looked finished. A driver that dismisses them on a short fixed delay will miss
the later ones, and a prompt still on screen at a checkpoint is baked into that
reference image and every one after it. Each dismissal needs a generous settle,
and the last one needs a check that nothing else has appeared.

Nothing else appears after the third; confirmed by waiting.

## Navigation: Ctrl+K works, and the room list DOES reorder

`Ctrl+K` opens Element's spotlight Search; typing a room name and pressing
`Return` opens it. Verified on Aurora Release.

**Element's room list reorders too.** An early observation suggested otherwise —
Aurora Release stayed at the top immediately after being opened, merely losing
its badge — but that was too small a sample. By block 19 the order had become
Windvane, Aurora, Field Photos: the list is sorted by recent activity, so it
moves as the scenario touches rooms, just on a different rule from nheko's
unread-first sort.

So the "never click a room in the room list" rule from nheko's MEASUREMENTS
applies here too, for the same practical reason even though the sort key
differs.

The window title carries the open room, which is a useful confirmation that
navigation worked: `Element [62] | Aurora Release`.

## Timeline primitives

| Action | How | Notes |
| ------ | --- | ----- |
| Scroll back | `Prior` (PageUp) x10 | Reached Jun 15 2026 from Jun 30 |
| Jump to live | click **(1392, 786)** | The circular ↓ button, bottom right of the timeline |
| Composer | click **(900, 857)**, placeholder "Send an unencrypted message…" | |
| Member count | shown in the header, **509** | no dialog needed just to read it |

### `End` does not jump to live — in either client

Measured: pressing `End` left the timeline at Jun 15 2026 and did nothing
visible. The composer holds focus, so `End` is a text-cursor key and never
reaches the timeline. The jump-to-bottom button is the only route.

nheko behaves the same way. Two clients, same wrong assumption, so it is worth
stating as a group-level rule rather than a per-client quirk: **never use `End`
for the jump-to-live block.**

## Element's panels are IN-WINDOW, and that changes what a checkpoint proves

The member list and the image viewer are both **panels inside the main window**,
not separate X windows — `WINS` shows one window throughout:

| Block | Element | nheko |
| ----- | ------- | ----- |
| 7 member list | right-hand panel, "509 Members" | separate 420x650 window |
| 9 image viewer | in-window lightbox, names `reservoir-at-first-light.jpg (595.57 KB)` | separate 1440x900 window titled `nheko` |

So Element's blocks 7 and 9 *could* be checkpointed **with the panel open**,
where nheko's provably cannot — the recorder raises the main window over
nheko's separate viewer before capturing.

**The driver does not take that option.** It closes the panel first, exactly as
the nheko driver does, because `script.md` ends both blocks by closing what they
opened and the checkpoint is what marks the block boundary. Capturing with the
panel open would push the close into the *next* block's timing. A slightly
richer screenshot is not worth mis-attributing the work.

The consequence is the same as for nheko: those two reference images do not by
themselves prove their block ran. Element at least *has* the option, which is
worth knowing if that assertion ever matters more than the boundary.

| Landmark | Where |
| -------- | ----- |
| Member list open | click the member count **(1400, 31)** |
| Close panel (members or thread) | **× (1410, 31)** |
| Image viewer close | **× (1408, 31)** |

## Blocks 8-12

| Block | How | Result |
| ----- | --- | ------ |
| Open photo room | `Ctrl+K` `Field Photos` `Return` | 400 images decode |
| View image full size | click newest thumbnail **(683, 705)** | lightbox names the anchor file |
| Scroll thumbnails | `Prior` x5 | |
| Filter room list | `Ctrl+K`, type `windvane` | spotlight, one match |
| Open filtered room | `Return` | window title gains the room name |

## Message actions: right-click, then ONE Down

Right-click opens a context menu anchored with its bottom near the click, the
same shape as nheko's. There are **no keyboard mnemonics** — this is a web app,
not Qt — but the menu is arrow-navigable, which is just as position-independent:

```text
React  Reply  Reply in thread  Forward  Share  Report  View source
```

**The menu opens with React already focused.** So `Down` `Return` is Reply, and
`Down` `Down` `Return` is *Reply in thread* — measured by doing it, which opened
a thread panel on the right and silently changed the layout width of the
timeline for every subsequent coordinate. One Down too many is not a no-op here;
it puts the client in a different state that looks plausible.

| Item | Keys after right-click |
| ---- | ---------------------- |
| React | `Return` |
| Reply | `Down` `Return` |
| Reply in thread | `Down` `Down` `Return` — **not** what the scenario wants |

## Element sends no reply fallback, and that is fine

Ground truth for the same block, both clients:

```text
Element  [reply] 'Agreed, going out today'
nheko    [reply] '> <@nadia:parrot.test> Ship it when the smoke tests are green.\n\nAgreed'
```

Both are real `m.in_reply_to` relations; nheko additionally writes the
deprecated quoted fallback into the body. `matrix-truth.py` reports `[reply]`
for both, which is the property the block is asserting — do not "fix" the
Element case by looking for the quote.

## Day separator: "Today", not a date

Element writes **Today** where nheko writes "Saturday, 8 August". Only the clock
time varies between record and replay, so Element's RMSE floor on the blocks
after the first send is smaller than nheko's, and it will not grow as the
rendered date string changes length.

## The cluster, measured and ground-truth verified

Each driven, then checked against the homeserver rather than the screen. The
anchor moves up after every send, so each row's coordinate is only valid at that
point in the sequence.

| Block | How | Server said |
| ----- | --- | ----------- |
| Send | composer **(900, 857)**, type, `Return` | `[m.text] 'Thank you so much'` |
| Reply | right-click anchor **(660, 696)** → `Down` `Return` → type → `Return` | `[reply] 'Agreed, going out today'` |
| React | right-click anchor **(660, 611)** → `Return` → Quick Reactions 👍 **(872, 766)** | `reacted '👍️' -> 'Ship it when the smoke tests are green.'` |
| Edit | right-click own msg **(660, 710)** → `Down` x3 → `Return` → `ctrl+a` → type → `Return` | `[edit] '* Thank you so much indeed'` |
| Upload | paperclip **(1378, 857)** → pick the file → **Upload (876, 644)** | `[m.image] 'parrot.png'` |

As with nheko, the reaction had to target Nadia's **original** at y=611 and not
the quoted copy inside the reply at y=764. Ground truth prints the target event
text, which is the only way to tell those two apart.

### The upload confirmation is not an nheko quirk

Element also does **not** send on file selection. It shows a preview card with
an **Upload** button, and without that second click the file dialog closes, the
composer looks busy, and the server receives nothing. Confirmed by ground truth:
`sent` showed three messages and no `m.image` until Upload was clicked.

Two clients, same failure mode, both invisible on screen. Treat "the file
dialog closed" as meaning nothing in any client in this group.

### The file dialog has a different WM_CLASS, and that is a gift

```text
main window   [Element … ]  CLASS = "element", "element"        1440x900
file chooser  [Open Files]  CLASS = "element-desktop", …        1124x822
```

Unlike nheko's file dialog — which shares the main window's class *and* its
1440x900 geometry — Element's differs in both. The geometry assertion in `CP()`
catches it, so the checkpoint guard that could not work for nheko does work
here.

One caution: `xdotool search --class element` matches `element-desktop` too,
because the match is an unanchored regex. The guard must therefore keep
asserting on geometry, not merely on the class matching one window.

### The file chooser opens on "Recent", and on a fresh profile Recent is EMPTY

This was measured wrong the first time and cost a recording, so it is worth
stating precisely.

The GTK chooser opens on the **Recent** shortcut, not on `$HOME`. On a profile
that has opened a file before, Recent has `parrot.png` in it and clicking the
first row at (222, 106) works — which is exactly what happens when you measure a
block by hand after having already tried it once.

**A recording always has a fresh profile.** Recent is empty, the row click
selects nothing, **Open** with no selection does nothing, the dialog closes, and
the Upload click lands on the timeline. Nothing on screen says so. The only
signal was ground truth: three events from `@parrot` in Windvane Deployment
instead of four, with no `m.image`.

The route that works, and that matches what nheko's block 17 does — type the
path:

1. **Paperclip (1378, 857)**.
2. `Ctrl+L` — the GTK location bar.
3. Type `/tmp/parrot.png`.
4. **Open (1075, 821)**.
5. **Upload (876, 644)** on the preview card.

**`Return` does not accept the location entry.** Measured twice, with the path
sitting correctly in the entry both times and the dialog still open afterwards.
Only the Open button accepts it. That is why step 4 is a click and not a
keystroke, and it is the one place in this driver where the obvious keyboard
route is the wrong one.

`install.sh` stages `parrot.png` into `/home/parrot` as well as `/tmp` anyway —
harmless, and it keeps the home-directory route available if the chooser's
default ever changes.

## Element's reaction carries a variation selector

```text
Element  reacted '👍️'   (U+1F44D U+FE0F)
nheko    reacted '👍'    (U+1F44D)
```

Same emoji to a human, different byte sequence on the wire. Anything comparing
reaction keys **across** clients has to normalise, or Element and nheko will
look like they reacted with different emoji. `matrix-truth.py` prints the raw
key deliberately, so the difference is visible rather than hidden.

## Blocks 18-23

| Block | How | Server said |
| ----- | --- | ----------- |
| Echo | `Ctrl+K` `Parrot Echo`, composer, `ping` | `echo: pong` inside 10 s |
| Join | `Ctrl+K`, type the full alias, `Return` | `Parrot Lobby JOINED` |
| Create | **+ (409, 98)** → New room **(480, 203)** → name → visibility → address → Create room | `Parrot benchmark JOINED` |
| Invite | see below | `membership: invite` for Alice |
| Leave | room info **(1327, 31)** → scroll → Leave room **(1215, 848)** → **Leave (1000, 521)** | `Parrot Lobby: not a member` |
| Idle quiet | `Ctrl+K` `Parrot Firehose`, 60 s untouched | — |
| Idle receiving | send `drip`, wait ~130 s | 24 messages, contiguous `drip 01..24` |

Joining by alias is neater here than in nheko: `Ctrl+K` with the full alias
offers **Join #parrot-lobby:parrot.test** as the preselected first result, so
`Return` joins. No separate dialog.

### Creating a room: Element defaults to PRIVATE and ENCRYPTED

The dialog opens as *Create a private room* with **Enable end-to-end encryption
already on**. Left alone it would produce an encrypted, invite-only room — which
is not what `script.md` asks for and, worse, is not what nheko produced, so the
two clients would be measured doing different work in every block after it.

Switching the dropdown **(719, 415)** to **Public room (610, 477)** does two
things: the encryption toggle disappears entirely (Element will not offer E2EE
on a public room), and a **Room address** field appears and is **required**.
nheko needed no alias, so the created rooms are not identical across clients —
`Parrot benchmark` here carries `#parrot-benchmark:parrot.test`.

| Landmark | Where |
| -------- | ----- |
| Name | focused on open — just type |
| Visibility dropdown | **(719, 415)** → Public room **(610, 477)** |
| Room address | **(600, 513)** |
| Create room | **(866, 648)** |

### The invite needs THREE steps, and step two is a confirmation

Element's invite is the same trap family as the upload:

1. **Invite to this room (616, 713)** — offered in the timeline of a
   freshly-created empty room.
2. Type `@alice:parrot.test`, then **click the suggestion (480, 350)**.
3. **Invite (1028, 261)** — this does *not* invite. It opens
   *"Invite new contacts to this room? You currently don't have any chats with
   these contacts."*
4. **Invite (910, 725)** on that confirmation is what actually sends it.

Measured: after step 3 the room's member events showed only `@parrot`. Three
clients' worth of evidence now says the same thing — **a dialog closing means
nothing in this group**; only ground truth does.

### Leave is below the fold

The room-info panel has to be **scrolled** before *Leave room* is reachable —
five wheel clicks at (1280, 700) in this layout. That makes the leave block's
coordinate depend on scroll position, so the driver must scroll a fixed amount
rather than assume the item is visible.

Element also greys out **Invite** in the lobby's room-info panel, because parrot
is an ordinary member there — the same power-level difference that changes
nheko's ⋮ menu from four items to three.
