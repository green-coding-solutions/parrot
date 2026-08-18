# SchildiChat Desktop — measured landmarks

Everything here was read off a running SchildiChat 1.11.36-sc.3 in the benchmark
container at 1440x900, driven block by block through
[../script.md](../script.md). Every block that changes server state was checked
with `matrix-truth.py` rather than by looking at the screen.

SchildiChat is an Element fork, so the useful thing about this file is the
**differences**. Read [../element/MEASUREMENTS.md](../element/MEASUREMENTS.md)
first: the traps that are about Electron, about recording, or about Matrix
clients in general are written up there and are not repeated here. What follows
is what a driver written against Element would get wrong.

## Window identity

`WM_CLASS(STRING) = "schildichat", "SchildiChat"` — so `pin-windows.sh` gets
**`schildichat`**, not `schildichat-desktop`.

The binary, the Debian package and the PATH command are all
`schildichat-desktop`. Element sets exactly the same trap with the same shape,
which is worth stating plainly: **Electron names the window after the app id,
not after the executable.** A res_name that matches nothing pins nothing and
says nothing, and every coordinate then drifts per run.

## The three Electron problems are identical, and so are the fixes

Root, keyring and `/dev/shm` behave exactly as they do for Element, so
`install.sh` carries the same three fixes: uid 1001, `gnome-keyring` +
`dbus-x11` with the unlock inside the app's own session bus, and
`--password-store=gnome-libsecret`. With all three, SchildiChat comes up on its
welcome screen with no prompt.

Keeping the two on identical launch conditions is the point of having both in
the group. Any measured difference should be the fork's UI layer, not one of
them running as a different user or with a different secret-storage backend.

## Layout differences that move coordinates

| | Element | SchildiChat |
| --- | --- | --- |
| Room list rows | name + badge | name + **message preview**, so rows are taller |
| Own messages | left-aligned, same column as everyone | **right-aligned bubbles** |
| Aurora Release badge | `7999` | `8.0K` (abbreviated) |
| Composer baseline | y≈857 | y≈872 |
| Paperclip | (1378, 857) | (1277, 872) |

The room-list difference does not matter to the driver, because every block
navigates with `Ctrl+K` rather than by clicking the list — the same rule as
Element and for the same reason.

## Block 1 — Load app

Welcome screen: **Sign In (614, 329)**, Create Account (824, 329). Nothing to
dismiss.

## Block 2 — Sign in

The same homeserver-first shape as Element, at slightly different coordinates:

1. **Sign In (614, 329)**.
2. Homeserver shows `matrix.org`. **Edit (999, 241)**.
3. *Sign into your homeserver* opens with **Other homeserver already selected
   and focused** — type `http://matrix.parrot.test:8008`, no click first.
4. **Continue (714, 578)**.
5. Username is focused **(822, 357)**: type `parrot`, click **Password
   (822, 410)**, type `parrot`.
6. **Sign in (822, 504)**.

Plain HTTP accepted with no certificate warning, as in Element.

## Block 3 — Initial sync: ONE prompt, not three

Element raises a chain of three prompts that arrive one after another. **SchildiChat
raises exactly one**, immediately:

| Prompt | Answer | At |
| ------ | ------ | -- |
| Update notifications | **No** | (175, 170) |

*Show preview* would join a SchildiChat release-announcement room, adding a room
to the list and network traffic of the client's choosing to a measured run.

Confirmed by waiting a further 35 s that nothing else appears — worth doing
rather than assuming, because Element's second prompt did not arrive until well
after its room list had settled.

Badges match the corpus, with SchildiChat abbreviating the largest: **8.0K**
Aurora Release, **600** Windvane Deployment, **400** Field Photos, **20** per
filler.

## Blocks 4-6 — Navigation, scroll-back, jump to live

`Ctrl+K` opens the spotlight; the first result is preselected, so type the room
name and press `Return`. The window title confirms it:
`SchildiChat [62] | Aurora Release`.

Scroll-back is ten `Prior` presses with the pointer over the timeline. The
**jump-to-live button is at (1392, 800)** — near Element's (1392, 786) but not
the same, because the composer sits lower here.

## Block 7 — The member list is TWO steps

Element has a facepile in the header that opens the member list in one click.
SchildiChat does not:

1. **Room info (1403, 27)** — the `i` at the far right of the header.
2. **People 509 (1263, 295)** in the About list.
3. Close with **× (1411, 86)**.

Both are in-window panels, so neither ever shows up as a second window — the
checkpoint guard cannot see them, which is why the block closes the panel
explicitly before its checkpoint, exactly as Element's does.

## Blocks 8-10 — Photo room

`Ctrl+K` to *Field Photos*. The newest image is the bottom one at **(653, 690)**;
it opens an in-window lightbox showing `reservoir-at-first-light.jpg`, closed
with **× (1408, 31)**. Then five `Prior` presses.

The images render at all only because the homeserver sets
`enable_authenticated_media: false`; see ../nheko/MEASUREMENTS.md.

## Blocks 11-12 — Filter and open

`Ctrl+K`, type `windvane`, and exactly one room matches — `Windvane Deployment`
with its `600` badge and `#windvane-deployment:parrot.test`. `Return` opens it.

## Block 13 — Send message

Composer at **(900, 872)**. The sent message appears as a **right-aligned
bubble**, which is where the reply and edit blocks then have to aim.

## Blocks 14-16 — The context menu is a CLICK target here

Element's menu opens with React focused, so its driver uses `Down`/`Return` and
counting matters. SchildiChat's menu is clicked directly, because the menu is
positioned against the message and both are at fixed positions in a recording.

Other-people's messages — 8 items:

| Item | y |
| ---- | - |
| React | 291 |
| Reply | 330 |
| Reply in thread | 368 |
| Quote | 407 |
| Forward | 445 |
| Share | 484 |
| Report | 523 |
| View source | 561 |

Own messages insert **Edit** as the fourth item and append **Remove**: React
355, Reply 393, Reply in thread 432, **Edit 470**, Quote 509, Forward 547,
Share 586, View source 624, Remove 663.

The emoji picker has a **Quick Reactions** row, so no search is needed: 👍 at
**(866, 693)**.

### SchildiChat sends a reply fallback; Element does not

Ground truth for the same block in the two clients:

```text
Element      [reply] 'Agreed, going out today'
SchildiChat  [reply] '> <@nadia:parrot.test> Ship it when the smoke tests are green.\n\nAgreed, going out today'
```

Both are correct — the fallback is the older Matrix convention and Element has
dropped it. It matters here for one practical reason: **`matrix-truth.py`
truncates what it prints**, so the SchildiChat line looks like the body is the
single word `Agreed`. It is not; the full text is in the event, and the
room-list preview shows it. Do not "fix" a block on the strength of that line.

## Block 17 — Upload: the same file-chooser trap as Element

The chooser is GTK, **1124x822 at 1,45**, and opens on **Recent, which is empty
on a fresh profile**. See Element's write-up for why that silently attaches
nothing on a recording. The working route is identical:

1. **Paperclip (1277, 872)**.
2. `Ctrl+L` for the location bar.
3. Type `/tmp/parrot.png`.
4. **Open (1075, 821)** — `Return` does not accept the location entry.
5. **Upload (876, 648)** on the preview card.

Step 5 is the one that sends. Without it the server receives nothing while the
composer looks busy — the same second-step confirmation Element and nheko both
have.

## Blocks 18-19 — Echo and join

`Ctrl+K` to *Parrot Echo*, composer, `ping`, and `pong` arrives.

For the join, `Ctrl+K` and the full address offers **"Join
#parrot-lobby:parrot.test"** as the preselected first result, so `Return` joins.
No dialog, same as Element.

## Block 20 — Create room: private and encrypted by default, and the invite is TWO steps

The create dialog defaults to **Private room (invite only)** with **Enable
end-to-end encryption ON**, exactly as Element does. Left alone that produces an
invite-only E2EE room, which is not what `script.md` asks for and not what the
other clients produce.

1. **+ (390, 131)** next to *All rooms* → **New room (450, 216)**.
2. Type `Parrot benchmark`.
3. Visibility dropdown **(719, 419)** → **Public room (574, 487)**.
4. Switching to Public removes the encryption toggle and makes **Room address
   (595, 528)** mandatory: type `parrot-benchmark`.
5. **Create room (866, 646)**.

Then the invite. Element needs three clicks because its second Invite is a
confirmation; **SchildiChat needs two**:

6. **Invite to this room (929, 720)**.
7. Type `@alice:parrot.test`, click the **suggestion row (471, 400)**.
8. **Invite (1028, 269)**.

Verified against the server rather than the dialog closing:

```text
@alice:parrot.test  invite
@parrot:parrot.test join
```

## Block 21 — Leave is one click, not below a fold

Element buries *Leave room* under a room-info panel that has to be scrolled.
SchildiChat puts it in the room-name menu:

1. **Room-name chevron (605, 28)**.
2. **Leave (649, 458)** — last item, in red.
3. Confirm **Leave (993, 525)**.

## Blocks 22-23 — Idle

`Ctrl+K` to *Parrot Firehose*, settle, 60 s untouched. Then `drip` in the
composer and 130 s while the bot posts `drip 01`..`drip 24`, one every 5 s.
Verified contiguous.

## Ground truth for the whole run

```text
4 message(s) from @parrot:parrot.test in Windvane Deployment
  [m.image  ] 'parrot.png'
  [edit     ] ' * Thank you so much indeed'
  [reply    ] '> <@nadia:parrot.test> Ship it ...\n\nAgreed, going out today'
  [m.text   ] 'Thank you so much'
1 reaction(s)  @parrot reacted '👍️' -> 'Ship it when the smoke tests are green.'
1 edit(s)      @parrot replaced ... -> 'Thank you so much indeed'
Parrot Lobby       not a member      (joined in 19, left in 21)
Parrot benchmark   JOINED            (@alice invited)
24 drip message(s), contiguous drip 01 .. drip 24
```
