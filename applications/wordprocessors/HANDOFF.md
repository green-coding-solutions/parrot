# Handoff — word processor group

Everything an incoming session needs to carry this group forward. Read this,
then [`README.md`](README.md), then the `MEASUREMENTS.md` of whichever app you
are working on. **Read [`libreoffice/MEASUREMENTS.md`](libreoffice/MEASUREMENTS.md)
whichever app you are on** — several of its findings are properties of the
harness, not of LibreOffice.

The repository's [`AGENTS.md`](../../AGENTS.md) is the authority on how to make a
recording that is worth having. Nothing below replaces it.

---

## Where things stand

| App | Install | Landmarks | Recorded | Replay-verified |
| --- | --- | --- | --- | --- |
| LibreOffice Writer | ✅ | ✅ 18/18 | ✅ | ✅ 18 PASS, worst RMSE 0.0082, ground truth PASS |
| Apache OpenOffice | ✅ | ✅ 18/18 | ✅ | ✅ 18 PASS, worst RMSE 0.0081, ground truth PASS |
| AbiWord | ✅ | ✅ 18/18 | ✅ | ✅ 18 PASS, worst RMSE 0.0081, ground truth PASS |
| SoftMaker FreeOffice | ✅ | ✅ 18/18 | ✅ | ✅ 18 PASS, worst RMSE 0.0059, ground truth PASS |
| Calligra Words (Flatpak) | ✅ pinned, runs | ✅ 18/18 | ✅ | ✅ 18 PASS, worst RMSE 0.0063, ground truth PASS |
| Collabora Office (Flatpak) | ✅ pinned, runs | ✅ 18/18 | ✅ | ✅ 18 PASS, worst RMSE 0.0524, ground truth PASS |

**All six apps have all eighteen blocks, recorded and replay-verified.** The
group is complete as it stands; what is left is the open decisions below, not
unfinished work.

Two applications that were carried this far have been **removed from the group**:
ONLYOFFICE, which installs but aborts before Qt starts, and WPS Office, which
runs perfectly but has no OpenDocument importer and so cannot read the group's
document at all. Their `install.sh`, `usage_scenario.yml` and `MEASUREMENTS.md`
were deleted rather than kept as dead weight. Everything that was ruled out for
each is in git history, and nowhere else:

```bash
git log --diff-filter=D --stat -- applications/wordprocessors/onlyoffice \
                                  applications/wordprocessors/wps
```

Both Flatpaks need `--security-opt seccomp=unconfined` and
`--security-opt systempaths=unconfined`, and **no capabilities** — they run as
uid 1001, which is what removes `SYS_ADMIN` and `NET_ADMIN`. See *Flatpak: run
it as a non-root user* below.

### What Apache OpenOffice taught us about the template

It was picked first because it shares LibreOffice's lineage and should have been
close to a copy. **The driver is about 80 % a copy and every one of the
remaining 20 % was a silent failure.** That is the useful result: shared lineage
predicts the *shape* of the driver, not its coordinates or its shortcuts.

What transferred unchanged: the status-bar zoom double-click, `Ctrl+F12` for
Insert Table, `Ctrl+End` stopping at the end of a table, the style and size
boxes needing a triple-click, the selection staying live after the size box, and
`Table4` as free ground truth.

What did not, each costing a pass:

* the fluxbox rule matches `VCLSalFrame.DocumentWindow`, which is the res_name at
  **map** time — the settled window reports plain `VCLSalFrame`, so the property
  `xprop` shows you is exactly the one that matches nothing;
* `Ctrl+H` is unbound — Find *and* Replace are both `Ctrl+F`;
* one `Escape` leaves the menu **bar** live, so the next `Ctrl+F` is eaten as the
  `F` accelerator;
* the ODF Version Conflict modal, because AOO implements ODF 1.2 and the document
  is 1.3;
* context toolbars are separate floating X windows, and `import -window` renders
  whatever they overlap as solid black.

**Budget one working session per application.** LibreOffice took a full session.
Its measuring pass alone surfaced five silent failures, each of which produced a
plausible-looking screen and no error anywhere. AbiWord produced two more in six
blocks. Recording against unmeasured landmarks is how a macro that does nothing
passes every check it has.

---

## The loop, per app

1. Write `install.sh` (pin the version) and `usage_scenario.yml`.
2. `bash common/setup-container.sh <app> --measure`
3. Launch the app, read `WM_CLASS` and `WM_WINDOW_ROLE`, fix the `pin-windows.sh`
   arguments, rebuild, and **confirm the geometry came back as 1440x900 at 0,0**.
   An unmatched fluxbox rule is completely silent. Then **run
   `xdotool search --onlyvisible --class <what you plan to pass as
   --windowclass>` and confirm it returns the window** — fluxbox matches
   `res_name` and xdotool matches `res_class`, and they are not always the same
   string.
4. Measure one block at a time, screenshotting after each, writing
   `MEASUREMENTS.md` as you go rather than at the end.
5. Write `drive-scenario.sh` (copy LibreOffice's and re-measure every number) and
   `record-session.sh`.
6. Record. Check: 18 checkpoints, 18 PNGs, all 1440x900, no `WARNING` lines,
   ground truth PASS.
7. `bash common/verify-app.sh <app>` in a fresh container. Read the **worst
   RMSE**, not the pass count.
8. Open the reference screenshots and compare them against LibreOffice's for the
   same block. This is the only thing that catches a block that acted on the
   wrong object.

## Commands

```bash
# rebuild a container exactly as the scenario does (+ xprop for measuring)
bash applications/wordprocessors/common/setup-container.sh libreoffice --measure

# interactive measuring helpers: X, K, T, WINS, SHOT, STATUS, start_app
source applications/wordprocessors/common/measure.sh

# record end to end, then check ground truth
./applications/wordprocessors/<app>/record-session.sh

# replay in a fresh container: RMSE, duplicate screenshots, ground truth
bash applications/wordprocessors/common/verify-app.sh <app>
bash applications/wordprocessors/common/verify-app.sh <app> --normalized

# every recording must define the same blocks in the same order
./tools/check_blocks.py applications/wordprocessors
#
# It also prints per-block wall-clock. Do NOT read that as app performance:
# it is the DRIVER's elapsed time, and most of it is the `sleep` values in
# drive-scenario.sh, which were set per app to whatever that app needed to
# settle. The energy figures come from GMT, not from this table.

# rebuild the time-normalized recordings - REQUIRED after any re-recording,
# because the padding is computed across the whole group
./tools/check_blocks.py applications/wordprocessors --normalize-time

# the production path - run once before calling a recording done
cd ../green-metrics-tool && ./runner.py --uri /home/didi/code/parrot \
    --filename applications/wordprocessors/<app>/usage_scenario.yml

# rebuild the document (only if you change it - it is committed)
./applications/wordprocessors/generate_document.py
./applications/wordprocessors/generate_document.py --check
```

---

## Traps that apply to every app in this group

### fluxbox grabs Control+F1..F12

The default keys file binds them to workspace switching and grabs them at the X
server, so the application never sees them. `Ctrl+F12` is Insert Table in
LibreOffice. **It looks exactly like a crash**: the display jumps to an empty
workspace, `xdotool search` returns nothing, `import -window root` returns a
fully transparent image, and the app's processes are all still running. Nothing
in any log mentions it. `Ctrl+F1` brings it back.

Already fixed — `pin-windows.sh` writes a keys file with no keyboard bindings at
all, mouse only. Nothing in a recording uses a window-manager keybinding.

### fluxbox matches res_name, and evaluates it at MAP time

Measured against LibreOffice Writer, whose settled window reports
`WM_CLASS "libreoffice", "libreoffice-writer"`:

```text
(name=libreoffice)          pinned    0,0 1440x900
(class=libreoffice-writer)  no match  0,44 1440x875
(class=libreoffice)         no match
(name=libreoffice-writer)   no match
(title=.*Writer)            no match
```

The rule is applied when the window is mapped, before the app has set its final
res_class or title. **A rule written against what `xprop` shows you on a settled
window can match nothing at all, silently** — no error, just an unpinned window
and reference screenshots at the wrong size. Always read the geometry back.

### fluxbox and xdotool match OPPOSITE halves of WM_CLASS

`WM_CLASS` is a pair — `res_name`, then `res_class` — and the two tools this
group leans on take different halves:

| | matches | for Collabora |
| --- | --- | --- |
| `pin-windows.sh` / fluxbox `(name=…)` | **res_name** | `coda-qt` |
| `xdotool search --class` | **res_class** | `collabora` (`Collabora Office`) |
| `xdotool search --classname` | res_name | `coda-qt` |

For most apps the two halves are similar enough that one string works for both —
LibreOffice is `"libreoffice", "libreoffice-writer"`, and `libreoffice` matches
either way. **Collabora Office is `"coda-qt", "Collabora Office"`, where no
string works for both**, and using the pin rule's `coda-qt` for `--windowclass`
finds nothing:

```text
xdotool search --onlyvisible --class coda-qt        no output, rc=1
xdotool search --onlyvisible --class collabora      the window
xdotool search --onlyvisible --classname coda-qt    the window
```

The match is a case-insensitive regex, so the shorter half of a two-word
res_class is enough and avoids putting a space in the pattern.

What this cost: a whole recording run. `CP()`'s geometry query ends in a `grep`
that found nothing, and with `set -euo pipefail` the driver exited at the first
checkpoint — after the container rebuild and the app launch, with a 0-byte
`.parrot`. That is the *good* outcome. Without `pipefail` the same mistake would
have recorded eighteen checkpoints of nothing at all.

**Check the class matcher against a live window before recording, not after.**

### Menus and popups are separate X windows carrying the app's own WM_CLASS

The checkpoint capture — `timed_xmacro.py`, not `record-macro.py` itself — takes
`xdotool search --onlyvisible --class <class> | head -n1`, the **first** match
and not the largest. (`record-macro.py`'s own window search does take the
largest, but that is only used to find the app at startup.) AbiWord's zoom combo
popup is `[abiword] 116x269` and sorts *ahead* of the document window. A
checkpoint taken with one open becomes a photograph of a dropdown, and that
becomes the reference every future replay is measured against.

`drive-scenario.sh`'s `CP()` asserts 1440x900 before every checkpoint for this
reason. Keep that assertion and watch for its `WARNING` lines.

### …and some of those windows never go away

AbiWord is the worst case found so far, and it is worth checking for in every
remaining app. Its Find dialog, Replace dialog and message boxes stay
**`IsViewable` at 0,0 after being closed** — nothing is drawn on screen, but the
X window is still there, still matches the class, and sorts *ahead* of the
document. From block 8 onwards every checkpoint would have been a 478x254
photograph of a dead dialog.

The fix is the one `AGENTS.md` describes and it works end to end:

```text
--windowclass ''
--windowtitle '^(Untitled1|[*]?Parrot Field Report)$'
```

An **empty `windowclass` is meaningful** — `helpers.normalize_app_meta` preserves
it on purpose, and every consumer skips an empty value and falls through to the
title: the capture, `_find_window` in both `replay.py` and `record-macro.py`, and
`position-window.sh` (which uses `${VAR-default}`, so empty-but-set stays empty).
The title travels as an environment variable, so regex characters survive.

Anchor the regex. Unanchored, `Parrot Field Report` also matches
`Replace - *Parrot Field Report`. And cover every title the document window has
during the run — for AbiWord that is `Untitled1` before the open, then with and
without the modified `*`.

**A size assertion is not a substitute.** AbiWord's Font dialog is itself resized
to 1440x900 by the pin rule, so it is indistinguishable from the document window
by geometry alone. `CP()` in `abiword/drive-scenario.sh` asserts the title match
returns exactly one window *and* that it is 1440x900.

### Toolbar combo boxes are usually not drivable at all

Across three apps now, the pattern is that **any route through a toolbar combo
is a trap and the equivalent dialog is fine**:

| | |
| --- | --- |
| AbiWord font size box | accepts typing, shows the value, and never applies it — neither `Return` nor `KP_Enter` commits |
| AbiWord style box | popup places the *selected* entry under the pointer, scrolling the target out of reach |
| AbiWord zoom box | same repositioning |
| AbiWord export file-type box | does not open under a synthetic click at all |
| LibreOffice / OpenOffice style and size boxes | fine, but only with a triple-click, and the selection stays live afterwards |
| FreeOffice font-size and spin boxes | a triple-click does **not** select the contents, so the typed digits are APPENDED — 12 and 18 become 1218, and the only sign is an error box. `Ctrl+A` after a single click works |
| FreeOffice zoom list and style gallery | **do not** reposition — verified by reopening both with a different entry selected |

Reach for the menu or the dialog first, and re-measure any combo you do use.
Note the split: three apps clear a field with a triple-click and one needs
`Ctrl+A`, and the wrong choice is silent in both directions.

### A click on an unpainted control lands in the document

Collabora's ribbon is a web view. Its Styles gallery **sometimes** renders as a
blank white area — in a later clean pass it painted fully, every time, so this is
a rendering *race* and not a permanent defect. That makes it worse, not better:
a control that is reliably missing gets noticed, one that is usually there does
not. Clicking the empty box in it does two things, neither of them visible:

* it **clears the direct formatting** just applied (bold and 18 pt both went back
  to regular 12 pt, selection still live, nothing else changed);
* it does **not take focus**, so the next thing typed goes into the DOCUMENT.
  Typing `Heading 1` there replaced the selected sentence with the literal text
  "Heading 1" — 54,633 words down to 54,626.

The same shape of failure came from `Escape`: it closed Collabora's Navigation
panel, and the `Cormorant` meant for its search box was inserted into the title
page instead.

Two rules follow, and they are worth applying to any app whose UI is drawn
rather than composed of real widgets:

1. **Prefer the keyboard.** Collabora is LibreOffice core, so `Ctrl+1` applies
   Heading 1 with no coordinates and no dependency on the ribbon painting at all.
2. **Never `Escape` to close a panel** — use its own close button, and check the
   word count after anything that types.

`Escape` on a selected *picture* is fine and is what Collabora's block 13 uses;
the contextual Picture tab leaving the tab strip confirms it. FreeOffice is the
opposite — there `Escape` does not deselect a picture and a click in body text
is needed.

### The shortcut you are sure of is the one that costs a pass

Every app in this group has redefined at least one keystroke that "everybody
knows", and **not one of them reports an error when you press it**:

| | |
| --- | --- |
| AbiWord, Calligra | `Ctrl+R` is **Align Right**, not Replace. It silently reformats the paragraph the cursor is in — on a centred title page that is nearly invisible |
| Calligra | `Ctrl+Y` is **nothing at all**. Redo is `Ctrl+Shift+Z`, and the page count just stays where the undo left it |
| Apache OpenOffice | `Ctrl+H` is **unbound** — Find *and* Replace are both `Ctrl+F` |
| Calligra | `Tab` in a table inserts a **tab character**; the **Right arrow** moves cells |
| LibreOffice, OpenOffice, Collabora | `Ctrl+End` stops at the **end of a table**, so `Ctrl+Return` there is a silent no-op. Press it twice |
| AbiWord, TextMaker, Calligra | one `Ctrl+End` is enough — pressing it twice would be wrong |

Open the app's own Edit menu and **read the accelerators off it** before writing
any into a driver. That is a thirty-second check that has now caught four
separate defects, each of which produced a plausible screen and no error.

### Flatpak: run it as a non-root user and the capabilities disappear

The two Flatpak entrants used to carry `--security-opt seccomp=unconfined`,
`--cap-add SYS_ADMIN` and `--cap-add NET_ADMIN`, which is close to
`--privileged`. **Both capabilities are gone.** They were never really about
Flatpak; they were about running the application as root.

`bwrap` — and so every `flatpak run` — can build its sandbox two ways: the
privileged path, which needs `CAP_SYS_ADMIN`, and the unprivileged one, which
unshares a **user** namespace first and therefore holds both `SYS_ADMIN` and
`NET_ADMIN` inside it for free. It picks between them by looking at the real
uid, on the reasonable assumption that root has those capabilities. **A Docker
container is the case where that assumption is false** — uid 0, but
`CapEff 00000000a80425fb`, with neither capability in it. bwrap commits to the
path it cannot finish, and the only way to rescue it is to hand the whole
container the capabilities it was wrongly assumed to have.

The same bwrap invocation as **uid 1001** takes the unprivileged path and needs
nothing from the container. So `install-flatpak.sh` creates a `parrot` user and
`/usr/local/bin/flatpak-session` drops to it — inside the wrapper, so that the
`startcommand` the recordings store verbatim does not change and no `.parrot`
had to be re-made.

Two `--security-opt` relaxations remain, and both were confirmed necessary one
at a time in throwaway containers:

| Flag | Why, and how the failure looks |
| --- | --- |
| `seccomp=unconfined` | Docker's default profile refuses `CLONE_NEWUSER`, for **root and non-root alike**. Without it, uid 1001 gets `bwrap: No permissions to create new namespace, likely because the kernel does not allow non-privileged user namespaces` — a message that is wrong about the kernel. `/proc/sys/user/max_user_namespaces` reads 126911 |
| `systempaths=unconfined` | Docker bind-mounts over **13 paths inside `/proc`** (`kcore`, `keys`, `sysrq-trigger`, …). That makes procfs "not fully visible", and the kernel then refuses a fresh `mount("proc")` from inside a user namespace: `bwrap: Can't mount proc on /newroot/proc: Operation not permitted`. `--unshare-pid` does **not** lift it — the check does not care which pid namespace you are in |

Read the second one honestly. It is a much smaller grant than `SYS_ADMIN` — the
container can no longer escape — but an unmasked `/proc` means it can write
`/proc/sysrq-trigger` and **panic the host**. Escape traded for denial of
service, in a throwaway container running code we ship.

The obvious next narrowing is a **custom seccomp profile** (Docker's default
plus `unshare`/`clone` with `CLONE_NEWUSER`) instead of `unconfined`. It buys a
smaller syscall surface at the cost of shipping a profile file that is pinned to
a Docker version. Not done; `systempaths` has no equivalent narrowing, because
re-masking anything inside `/proc` is exactly what breaks the mount again.

**`--allow-unsafe` is a CLI-mode requirement only.** `runner.py` hard-codes an
empty allowlist — deliberately, per the comment at `runner.py:234` — so any
`docker-run-args` needs the flag locally. The **job runner does not**:
`lib/job/run.py` passes
`capabilities.measurement.orchestrators.docker.allowed_run_args`, and
`lib/scenario_runner.py:1669` accepts any argument that `re.fullmatch`es an
entry there. For a production run, allowlist the two strings for the measuring
user and drop the flag:

```json
"orchestrators": { "docker": { "allowed_run_args": [
    "--security-opt seccomp=unconfined",
    "--security-opt systempaths=unconfined"
] } }
```

`setup-container.sh` **reads `docker-run-args` out of the scenario** and passes
it to `docker run`, the same way it reads the setup-commands: a measuring
container built with different flags from the benchmark's is not the container
being measured. It is all per-service, so nothing changes for the six
non-Flatpak apps.

### Combo boxes reposition themselves

AbiWord's toolbar zoom combo positions its popup so the **currently selected
entry** lands under the pointer. The same click therefore hits a different item
once the selection changes — it set 75 % when asked for 100 %, then `Whole
Page`, silently each time. Prefer menus, which do not move. Check every combo.

### Every step in script.md is ONE line, however long

`record-macro.py` skips blank and `#` lines and nothing else. The typed block was
originally a step with its three lines indented underneath; the recorder consumed
each as its own checkpoint note — 21 items against 18 blocks, and every label
from "Type paragraph" onwards attached to the wrong block. The recording would
have had the right checkpoint count and wrong labels on all of them.

**The number of `* ` lines in `script.md` must equal the number of `CP` calls in
every `drive-scenario.sh`.** Check it before recording:

```bash
grep -c '^\*' applications/wordprocessors/script.md
grep -c 'CP "' applications/wordprocessors/<app>/drive-scenario.sh
```

### There is no "close app" block

A checkpoint is a screenshot of the application window, so a block whose action
destroys that window has nothing to photograph. The script ends at Export PDF.
The PDF viewer and email client groups end the same way.

### Ground truth is the only real check — and it had a blind spot of its own

Every defect this group has produced was invisible in the screenshots. Run
`check-result.sh`; a plain GMT run does not.

**But a passing check is not the same as a correct document.** Calligra Words
inserts a *tab character* when you press Tab in a table instead of moving to the
next cell, so all three words landed in cell 1:

```xml
<text:p>Alpha<text:tab/>Beta<text:tab/>Gamma</text:p>
```

and `check-result.sh` reported `ok table cell Alpha`, `ok table cell Beta`,
`ok table cell Gamma` — because its test was `">Alpha<" in content`, and
`>Alpha<` matches `>Alpha<text:tab/>`. Two empty cells beside it, three ticks.

That is "counts do not record identity" *inside the ground truth itself*. The
check now parses the table and requires the three words in three **separate
cells of one row**. If an already-verified app fails that on its next run, it is
a real defect that was hidden, not a regression in the check.

The lesson generalises: **a substring test on XML asserts almost nothing.** When
the thing you care about is structure — which cell, which paragraph, which style
— parse it.

### An incremental find bar steps one match too far

Step 8 of the loop — open the reference screenshots beside another app's for the
same block — is the one people skip, and it is the only thing that caught this.

Calligra's block 7 replayed at 18 PASS with no warnings and ground truth PASS,
and it was **on the wrong match**. Its find bar is *incremental*: typing
`Cormorant` already selects match 1, so typing plus three `Next` clicks lands on
match **four**. Every other application in the group needs three clicks because
its find dialog does not move until told to.

Nothing automated can see this. `check-result.sh` asserts the document contents,
which are identical either way; the screenshot check compares a recording against
itself. It showed up as a different *sentence* under the highlight:

```text
provisional conduit downstream of Cormorant   match 3   LibreOffice, OpenOffice,
                                                        AbiWord, Collabora
evaporator feeding Cormorant                  match 4   Calligra, before the fix
```

and was then pinned down exactly by counting occurrences in the shipped ODT.

**Check whether the find bar is incremental before choosing the click count**,
and always compare block 7's screenshot against another app's. The document is
committed and identical everywhere, so the highlighted sentence must be too.

Note that `libreoffice-check-018.png` is byte-identical to `017` — exporting a
PDF does not change the document view, so that block's *screenshot* cannot tell a
successful export from nothing happening. Only ground truth covers it. Expect the
same in other apps.

---

## Traps in the tooling you will use

* **`docker exec` needs `-i`** to accept a heredoc on stdin. Without it the
  command runs and silently produces nothing.
* **`pkill -f <pattern>` matches the shell's own command line**, so a compound
  command containing the pattern kills itself and everything after it silently
  does not run. It has now caught three different sessions —
  `pkill -f record-macro.py` (exit 144), `pkill -f textmaker` (exit 143), and
  `pkill -f collabora`, where an `rm -rf` after it never ran and the next hour was
  spent explaining a directory that should not have existed. Use the bracket
  trick: `pgrep -f "collabor[a]"` does not match the literal `collabor[a]` in its
  own argv.
* **`--measure` deletes `/usr/bin/xmessage`, deliberately.** Installing
  `x11-utils` for `xprop` pulls `xmessage` in; fluxbox's `fbsetbg` cannot set the
  wallpaper in this image and calls `xmessage` to say so, leaving a 1017x107
  dialog on screen for the whole session. The stock image has no `xmessage`, so
  the benchmark never sees it — the measuring container has to match.
* **A recording takes about 12 minutes**, a `verify-app.sh` about 10. Run them in
  the background and watch for `=== recorded ===` / `RESULT`.
* Watch out for **stale state between measuring passes**. LibreOffice's Document
  Recovery, in particular, replaces the document with a recovery window after any
  unclean exit; that is now off in its profile, but expect equivalents elsewhere.

---

## Do not compare the apps with `usage_scenario.yml`

Each app carries **two** scenarios, and picking the wrong one produces a number
that looks fine and means something else:

| File | Replays | Answers |
| --- | --- | --- |
| `usage_scenario.yml` | `<app>.parrot` | what this app costs at its own pace |
| `usage_scenario_normalized.yml` | `<app>-normalized.parrot` | how the apps compare |

**96–99 % of every recording in this group is deliberate `wait`.** The drivers
were paced per app to whatever that app needed to settle, which mixes the app's
genuine slowness with a human's safety margin, and nothing separates them
afterwards. Un-normalized totals:

```text
libreoffice  445s    abiword     753s    calligra   1131s
openoffice   558s    freeoffice  741s    collabora  1173s
```

Block 3 is the clean demonstration: ten `Page Down` presses, no dialogs, nothing
ambiguous — `sleep 0.5` in LibreOffice's driver and `sleep 1.2` in Calligra's and
Collabora's. Every scenario is a single flow command, so GMT reports one phase
covering the whole replay. Compare those six figures and you are largely ranking
how patient each driver is.

`./tools/check_blocks.py applications/wordprocessors --normalize-time` pads every
block out to the longest that block takes in *any* recording in the group, as one
`wait` inserted immediately before the block's checkpoint — so the timing of the
actions inside a block is untouched and only the settled idle at the end of it
grows. All six then run **1269.515 s** with every block identical, verified:

```python
all(abs(x - y) < 1e-3 for x, y in zip(block_totals[a], block_totals[b]))  # True
```

The cost is real and has to be stated wherever a normalized figure is: every app
now pays the **slowest** app's idle in every block, so these are not "what this
app costs a user". They are like-for-like and nothing else.

The reference screenshots and the ground truth are shared between the variants —
normalizing only inserts idle before a checkpoint — so `verify-app.sh <app>
--normalized` checks a padded recording against exactly the same evidence.

**Regenerate after any re-recording.** The padding is computed across the whole
group, so a single new recording silently invalidates all six normalized files.

---

## The document

[`parrot-report.odt`](parrot-report.odt) is committed and byte-identical on every
machine (`sha256 ac2cbe2f…`).
[`generate_document.py`](generate_document.py) built it; run it twice and compare
digests if you doubt it.

| | |
| - | - |
| Size | 8.7 MiB |
| Pages | 98 in LibreOffice, OpenOffice and Collabora; **97 in AbiWord and TextMaker**; **120 in Calligra**, which does not apply the document's fonts |
| Words | 54,607 (`54,607 words, 361,913 characters` in Writer's status bar) |
| Figures | 12 PNGs, ~740 KiB each |
| Tables | 3 — so the Insert Table dialog defaults to the name `Table4` |
| Fonts | Liberation Serif / Liberation Sans — **every `install.sh` must install `fonts-liberation`**, or the document repaginates and the fixed Page Down counts land elsewhere |
| `Cormorant` | exactly 120, the replace-all anchor |
| `Shearwater` | zero before the run |

Different apps paginate it differently. That is why the script counts keystrokes
and never names a page number.

[`parrot.png`](parrot.png) (745 KiB) is the separate figure block 13 inserts.

`install.sh` **copies** both to `/tmp` rather than symlinking: the scenario saves
over the document, and a symlink would write into the checkout.

### What check-result.sh asserts

120 `Shearwater` / 0 `Cormorant`; the three typed lines present as text, not just
as line count; the typed block carrying a heading style; 13 pictures; 4 tables;
`Alpha`/`Beta`/`Gamma` cells; 13 paragraphs starting a new page; and a 100-page
PDF.

Counting `fo:break-before="page"` directly does **not** work — the document
defines one automatic style carrying it and references that from all twelve
chapter headings, and Writer rewrites the automatic styles on save. Count
paragraphs that *reference* a break-carrying style.

---

## Open decisions

1. **A second DOCX pass**, or ODT only. ODT was chosen because Apache OpenOffice
   cannot write DOCX at all and AbiWord's and Calligra's OOXML export is rough —
   it is the only format all six both read and write. The cost is that it
   flatters the LibreOffice family, and that it excluded the two applications
   that have since been dropped. A second pass in DOCX would have to leave
   OpenOffice out of the write half, so it is not a like-for-like re-run of this
   one.
2. **The two Flatpaks need `/proc` unmasked.** The capabilities are gone — the
   application runs as uid 1001, so bwrap takes its unprivileged path and needs
   neither `SYS_ADMIN` nor `NET_ADMIN`. What is left is
   `--security-opt seccomp=unconfined` and `--security-opt systempaths=unconfined`,
   neither of which grants a capability. The residual risk is narrow and real: an
   unmasked `/proc` lets the container write `/proc/sysrq-trigger` and panic the
   host. Accept it, or narrow the seccomp half with a custom profile — see
   *Flatpak: run it as a non-root user* above. `--allow-unsafe` is only needed for
   local `runner.py`; the job runner takes an `allowed_run_args` allowlist
   instead.
3. **Collabora runs with Chromium's own sandbox disabled.** It is QtWebEngine and
   Chromium refuses to start as root, which everything in this container is. That
   is a sandbox turned off *inside* a Flatpak sandbox inside a throwaway
   container, so the practical exposure is small — but it is off, and it is off
   permanently via a `flatpak override`.
4. **Two blocks are driven differently from `script.md`, both deliberately.**
   Collabora's block 1 ends on the start screen rather than an editable page,
   because creating a document leaves two indistinguishable windows; Calligra's
   block 6 is one `Ctrl++` and one `Ctrl+-` rather than 150 % and 100 %, because
   its zoom widget is inert and 150 % does not exist. Reasoning is in each app's
   `MEASUREMENTS.md`.

The Flatpak runtime cost stays in the figure — that is a deliberate decision, not
an oversight, and `install-flatpak.sh` is now tested end to end for both apps.

## Already settled, do not relitigate

* ODT for both opening and saving.
* Cursor moves by `Ctrl+Home` / `Ctrl+End` / `Page Down`, never by page number.
* The typed text is autocorrect-proof by construction, so autocorrect is left
  **on** — it is what a user runs, and no rule fires on that text.
* Autosave off wherever a profile can carry it.
* Undo is exercised on a page break only: a page break is one undo unit
  everywhere, a typed paragraph is not.
* No spell check, word count, track changes, comments or mail merge — AbiWord
  and Calligra Words cannot do all of them, and the script is the intersection.
* PDF by whichever route the app offers, including print-to-file.
