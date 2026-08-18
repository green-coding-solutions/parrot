# Calligra Words — landmarks

**Status: complete. 18 PASS / 0 FAIL, worst RMSE 0.00576, ground truth PASS, no
identical consecutive checkpoints — in a container with no added capabilities.**

All eighteen blocks were driven through a clean container first, every end state
read off the status bar, then recorded and replayed in a fresh container. The
zoom block and the floating-image block — the two that looked least
deterministic going in — both replay at exactly 0.

Recorded twice. The first recording passed everything and was still **wrong**:
block 7 stepped to the fourth `Cormorant` rather than the third, because this
find bar is incremental. See block 7 below — that is the single most useful
thing in this file.

```bash
bash applications/wordprocessors/common/setup-container.sh calligra --measure
```

Read [`../libreoffice/MEASUREMENTS.md`](../libreoffice/MEASUREMENTS.md) and
[`../collabora/MEASUREMENTS.md`](../collabora/MEASUREMENTS.md) first — several
of their findings are properties of the harness rather than of any one app.

**Four shortcuts this application does not have**, each of which looks like it
does, and each found by pressing it and reading the result rather than by
assuming:

| pressed | what actually happens | what to use |
| --- | --- | --- |
| `Ctrl+R` | **Align Right.** Silently right-aligns the paragraph the cursor is in | `Ctrl+H` |
| `Ctrl+Y` | **nothing at all** — the page count stays where the undo left it | `Ctrl+Shift+Z` |
| `Tab` in a table | inserts a **tab character** in the current cell | the **Right arrow** |
| `Escape` after inserting a picture | does not leave the shape tool | **double-click** body text |

---

## Getting a Flatpak to run at all

This took longer than the application did, and each of the four failures looks
like a different problem. Every one was reproduced with plain `bwrap` in a
throwaway container before being believed.

### The container needs three things it does not have by default — and then it didn't

The first route worked, and the conclusion drawn from it was wrong. Both are
kept here, because the wrong one is the more instructive.

```text
default                     bwrap: Creating new namespace failed: Operation not permitted
+ seccomp=unconfined        same
+ SYS_ADMIN only            bwrap: pivot_root: Operation not permitted
+ seccomp + SYS_ADMIN       bwrap: loopback: Failed RTM_NEWADDR: No child processes
                            error: ldconfig failed, exit status 256
+ NET_ADMIN as well         works
```

Every line of that is real and reproducible. What was inferred from it — *Flatpak
needs a container close to `--privileged`* — is not. **All of it is a consequence
of running the application as root.**

bwrap can build its sandbox two ways: the privileged path, which needs
`CAP_SYS_ADMIN`, and the unprivileged one, which unshares a **user** namespace
first and therefore holds `SYS_ADMIN` and `NET_ADMIN` inside it for free. It
chooses by looking at the real uid, on the assumption that root has them. A
Docker container is where that assumption breaks: uid 0, `CapEff
00000000a80425fb`, neither capability present. bwrap commits to the path it
cannot finish, and every line of the table above is the harness feeding it the
capabilities it wrongly assumed it had.

The evidence was already written down and was read as reassurance instead of as
the answer: `bwrap --unshare-all` succeeded with only seccomp relaxed, *because
`--unshare-all` includes the user namespace*. The cheap probe was not failing to
reproduce the problem — it was demonstrating the fix.

Run the application as **uid 1001** and both capabilities go away:

```text
as root,     no flags       bwrap: Creating new namespace failed: Operation not permitted
as uid 1001, no flags       bwrap: No permissions to create new namespace, likely
                            because the kernel does not allow non-privileged
                            user namespaces
as uid 1001, + seccomp      bwrap: Can't mount proc on /newroot/proc: Operation not permitted
as uid 1001, + systempaths  works, with no capabilities at all
```

| flag | what needs it |
| --- | --- |
| `--security-opt seccomp=unconfined` | Docker's default profile refuses `CLONE_NEWUSER`, for root and non-root alike. bwrap's message blames the kernel and the kernel is fine: `/proc/sys/user/max_user_namespaces` reads 126911 |
| `--security-opt systempaths=unconfined` | Docker bind-mounts over **13 paths inside `/proc`** (`kcore`, `keys`, `sysrq-trigger`, …), which makes procfs "not fully visible"; the kernel then refuses a fresh `mount("proc")` from inside a user namespace. `--unshare-pid` does *not* lift it — the check is not per-pidns |

`Failed RTM_NEWADDR: No child processes` is still worth calling out. ECHILD has
nothing to do with the real fault and sent this off in the wrong direction twice.
On the non-root route it never appears at all: that bwrap unshares the user
namespace too, so it holds `CAP_NET_ADMIN` inside it and brings `lo` up itself.

The drop happens inside `/usr/local/bin/flatpak-session`, **not** in the
scenario's `startcommand` — the recordings store that string verbatim and
replay.py relaunches it, so putting it there would have invalidated every
`.parrot` in the group. Re-verified against the same reference images with no
re-recording: **18 PASS, worst RMSE 0.00576**, ground truth PASS, container
`CapAdd: null`, application processes owned by `parrot`.

What is left is two `--security-opt` relaxations and no capabilities, in
[`usage_scenario.yml`](usage_scenario.yml) as `docker-run-args`. Read the second
one honestly: the container can no longer escape, but an unmasked `/proc` lets
it write `/proc/sysrq-trigger` and **panic the host**. The remaining narrowing
would be a custom seccomp profile in place of `unconfined`; `systempaths` has no
equivalent, because re-masking anything inside `/proc` is what breaks the mount
again.

**`--allow-unsafe` is a CLI-mode requirement only.** `runner.py` hard-codes an
empty allowlist on purpose (see its comment at line 234), but the job runner
passes the user's
`capabilities.measurement.orchestrators.docker.allowed_run_args` and accepts any
argument that `re.fullmatch`es an entry. Allowlisting the two strings there is
how a production run avoids the flag.

### There is no D-Bus in the image, and the failure does not look like it

Before any of the above, `flatpak run` stops at

```text
error: Could not connect: No such file or directory
```

which reads like a missing file, not a missing bus. flatpak wants a **system**
bus, a **session** bus and an `XDG_RUNTIME_DIR` that exists; the window
container has no init, no logind and no dbus package.
[`../common/install-flatpak.sh`](../common/install-flatpak.sh) now installs
`dbus`/`dbus-x11` and writes `/usr/local/bin/flatpak-session`, which supplies all
three and execs its arguments:

```bash
flatpak-session flatpak run --command=calligrawords org.kde.calligra
```

That is what the `startcommand` has to go through.

### The install is pinned to an OSTree commit

```text
org.kde.calligra   3aed03805b3c9377c000e2363cc5fe9b28ef637da78b733d241d9506e087bebc   26.04.3, 2 Jul 2026
org.kde.Platform//6.10  d0d8f7888350e93c0e6d009d79c5b143f6f6dde09de28ff93a7dc8a14a848c16
```

A Flatpak ref names a **branch**, and `stable` moves — installing it unpinned is
the same mistake as an APT source with no version. `flatpak install` has no
`--commit`, so the helper installs the branch and then
`flatpak update --commit=`s onto the pin, and **reads the commit back
afterwards** and fails loudly if it does not match.

The runtime is pinned too. It is the larger half of the download and a runtime
update changes the Qt, the theme and the fonts the application draws with — which
changes every reference screenshot.

`--command=calligrawords` is required: the Flatpak's default command is
`calligralauncher`, which is the suite chooser, not Words.

## Window matching — confirmed

```text
[Calligra Words]  X=0 Y=0 WIDTH=1440 HEIGHT=900   WM_CLASS "calligrawords", "calligrawords"

xdotool search --onlyvisible --class calligrawords      -> the window
xdotool search --onlyvisible --classname calligrawords  -> the window
```

**Both halves of `WM_CLASS` are the same string**, so one value serves the
fluxbox pin rule (which matches res_name) and `--windowclass` (which matches
res_class). That is *not* true of Collabora, and it was checked here against a
live window rather than assumed — see the HANDOFF entry.

### …but the count assertion still matters

Three kinds of window carry this same class and sort **ahead** of the document:

```text
Edit menu popup       293x268 at 41,19
style combo popup     377x482 at 1054,249
Add Shape popup       306x216 at 1133,52
```

and worse, the **Insert Table dialog comes back at 1440x900 at 0,0** — the pin
rule matches it too, so it is indistinguishable from the document window by
geometry alone. This is AbiWord's Font-dialog trap again. `CP()` asserts the
match **count** as well as the size for exactly this reason.

---

## What is established about the application

### It does not apply the document's fonts

This was the open question and it is settled. The document declares
`Liberation Sans` and `Liberation Serif` in both `content.xml` and `styles.xml`,
via `fo:font-family` and `svg:font-family`. Calligra renders body text in a
sans-serif face and its character panel reports the family as **`DejaVu Sans`**.

It is **not** a missing font, and the obvious diagnosis was wrong:

```text
fc-list | grep -ci liberation                       container:  12
flatpak run --command=fc-list ... | grep -ci ...     sandbox:    24
flatpak run --command=fc-match ... "Liberation Sans"
  -> LiberationSans-Regular.ttf:  "Liberation Sans"  "Regular"
flatpak run --command=fc-match ... "Liberation Serif"
  -> LiberationSerif-Regular.ttf: "Liberation Serif" "Regular"
```

The decisive test: selecting a paragraph and setting `Liberation Serif` by hand
**renders it in Liberation Serif immediately**, and it reflows from nine lines to
eight. The font is present, resolvable and usable — Calligra's ODF import simply
does not apply the family from the styles.

That is why it paginates the document to **120** pages where LibreOffice,
OpenOffice and Collabora make it 98 and AbiWord and TextMaker 97.

**Not a blocker, but it has to be said out loud in the README.** `script.md`
counts keystrokes and never names a page, so the driver survives it. But
Calligra is laying out a materially different document from the others, and
nobody should read its energy figure as like-for-like layout work.

---

## The eighteen blocks

Ground truth throughout is the status bar: `Page n of 120`, the line number, and
`Saved` / `Modified`. There is **no word count** anywhere in Calligra's status
bar, which is why several blocks below lean on `check-result.sh` instead.

The status bar sits at **y≈860**, not 882 — the document view has a horizontal
scrollbar under it. Opening the find bar pushes it up to y≈829.

```text
 1  Load app       Use This Template 1371,883      -> blank editable page, Page 1 of 1
 2  Open document  Ctrl+O, path, Return (~70 s)    -> Page 1 of 120, Line 1
 3  Page through   ten Next                        -> Page 5-6 of 120, Line 166
 4  Jump to end    Ctrl+End (~45 s)                -> Page 120 of 120, Line 5178
 5  Jump to start  Ctrl+Home                       -> Page 1 of 120, Line 1
 6  Zoom           Ctrl++ then Ctrl+-              -> 141 %, then exactly 100 %
 7  Find word      Ctrl+F, 3x Next                 -> "120 matches found", Page 4-5, Line 141
 8  Replace all    Ctrl+Home, Ctrl+H, Replace All  -> "No matches found"
 9  Type paragraph Ctrl+End, Return, 3 lines       -> Page 120 of 120, Line 5183
10  Bold a line    Shift+Home, Ctrl+B              -> docker B lit
11  Resize         docker size box, 18             -> visibly larger, selection live
12  Apply heading  docker style combo > Heading 1  -> "Heading 1 22pt"
13  Insert image   Add Shape > Image > click       -> floating shape, page count unchanged
14  Insert table   Insert a table > Insert Custom  -> Page 120-121 of 121
15  Page break     Ctrl+End, Ctrl+Return           -> Page 121-122 of 122
16  Undo and redo  Ctrl+Z, Ctrl+Shift+Z            -> 121, then 122
17  Save           Ctrl+S, no dialog               -> `Saved`
18  Export PDF     File > Export as PDF            -> 122 pages, 5.3 MB
```

### Block 1 — the template chooser is in the same window

```text
  left rail    Recent Documents / Custom Document / Blank Documents
  list         Blank Document (pre-selected) / Colorful Document /
               Fax Template / Professional Letter
  Always use this template   checkbox  1130,197
  Use This Template          1371,883
  Open Existing Document     127,883
```

Clicking `Use This Template` turns **the same window** into the document view.
It does not open a second one — which is why Calligra's block 1 can end on a
genuine editable page and Collabora's cannot. Note the zoom: Calligra opens at
**Fit Page Width**, not 100 %.

### Block 2 — the document window is reused

`Ctrl+O` opens a Qt file dialog, 632x412 at 394,226, titled
`Open Document — Calligra Words`.

```text
  File name field   708,562        Open   975,562
```

The portal is **not** available in this container —

```text
Call for getting org.freedesktop.portal.FileChooser version failed
  QDBusError("org.freedesktop.DBus.Error.ServiceUnknown", ...)
```

— and that turns out to be good news: Qt falls back to its own dialog, which is
in-process and deterministic, rather than to a portal whose appearance depends
on what is running outside the sandbox. Do not "fix" it by adding a portal.

The blank document from block 1 is **reused**, so there is still exactly one
window afterwards. Verified by listing windows, not assumed.

### Block 6 — the deviation, and it is smaller than expected

`script.md` asks for 150 % and then 100 %. Calligra has no 150 %:

| route | result |
| --- | --- |
| type `150%` into the status-bar zoom box, `Return` | box reads `150%`, **canvas unchanged** |
| type `400%` | box reads `400%`, **canvas unchanged** |
| pick `100.0%` from the box's dropdown while zoomed in | box reads `100.0%`, **canvas unchanged** |
| `Ctrl++` / `Ctrl+-` | **works, canvas redraws** |

Checked against a forced repaint and against the View menu, whose own zoom row
still read `Fit Page Width` while the status bar claimed `400.0%` — the two are
simply out of sync, because the value never reached the canvas.

The steps are a root-two progression — 25, 33.3, 50, 66.7, 100, 141.4, 176.6,
200, 282.8, 400 — so even a working list could not hit 150.

**The route taken: one `Ctrl++`, then one `Ctrl+-`.** From the `Fit Page Width`
the document opens at, that lands on **141 %** — the nearest step there is to
150 % — and then on **exactly 100 %**, which is precisely what the second half of
the block asks for. So only the first half deviates, and the canvas genuinely
redraws both ways (verified by reading the page, not the label).

That is a better outcome than the "one step out and one step back" this was
originally going to settle for, and it was only discovered by measuring what
`Ctrl+-` actually lands on instead of assuming it returns to Fit Page Width.

Two further things about that zoom box, if anyone tries to use it anyway:

* **its contents change with the current zoom.** At Fit Page Width the list has
  thirteen rows including `176.6%`; at another zoom it has twelve and `176.6%` is
  gone. Every row's y coordinate moves with it.
* the popup is a separate X window carrying `WM_CLASS "calligrawords"`, 114x184,
  and it sorts **ahead** of the document in `xdotool search`.

### Block 7 — the find bar moves the status bar

`Ctrl+F` opens a bar along the **bottom**, below the status bar, which it pushes
up from y≈860 to y≈829.

```text
  close X   20,857      Find field  234,857
  Next     445,857      Previous    525,857      Options  608,857
```

Typing `Cormorant` turns the field green and reports **`120 matches found`** —
exactly what the document contains, and free ground truth.

**TWO clicks on `Next`, not three — the bar is incremental.** Typing already
selects match 1, so typing plus three clicks lands on match **four**, one past
what `script.md` asks for. Every other application in the group needs three
clicks because its find dialog does not move until told to.

The first recording had three, and **nothing automated caught it**: 18 PASS, no
warnings, ground truth PASS. `check-result.sh` asserts the document contents,
which are identical either way, and the screenshot check compares a recording
against itself. It was found by opening `calligra-check-007.png` beside
`libreoffice-check-007.png` and seeing a different sentence under the highlight,
then counting occurrences in the shipped ODT to be certain:

```text
provisional conduit downstream of Cormorant   match 3   LibreOffice, OpenOffice,
                                                        AbiWord, Collabora
evaporator feeding Cormorant                  match 4   Calligra, before the fix
```

That is step 8 of the loop — compare the reference screenshots against another
app's — earning its place.

### Block 8 — Ctrl+H, and Ctrl+R is a trap

`Ctrl+R` is **Align Right**. Pressed expecting Replace, it right-aligned the
title page — the title and subtitle shifted, the style box gained a `+` for the
direct formatting, and the title bar gained a `*`. On a centred title page that
is very nearly invisible. One `Ctrl+Z` reverted it completely (the Edit menu's
Undo went grey, which is how that was confirmed).

`Ctrl+H` opens the same bar as block 7 with a second row, which moves everything
up by one row:

```text
  close X   21,829      Find field  250,829
  Replace field  253,857     Replace  457,857     Replace All  539,857
```

Calligra reports no "N replacements made" box. The confirmation is the match
counter going to **`No matches found`** and both fields turning pink.

Its Replace All **does wrap** — checked by running it with the cursor at line 12
of a 120-page document and getting every match — but the block still does
`Ctrl+Home` first, as the rest of the group does, so the number is the whole
document's.

### Block 13 — the image is a floating shape, and that is a deviation

Calligra Words has **no Insert menu** (the menu bar is File / Edit / View /
Styles / Settings) and no inline-picture command; the docker's `Insert` group is
page breaks and sections. Hovered every icon in it to be sure:

```text
1153,394  Insert non-breaking space etc. (Alt+Shift+C)
1179,394  Insert a page break (Ctrl+Return)
1205,394  Insert new section
1231,394  Configure current section
1257,394  Insert paragraph between sections
```

The only route is **Add Shape → Image**, which *arms a tool* rather than opening
a dialog — the character controls in the docker grey out and nothing else
happens. A single click on the canvas then places the shape and raises an
`[Image Options]` file dialog:

```text
  Add Shape  1297,37     Image  1168,142     click the canvas  400,570
  Name field  815,562    OK  947,644
```

The result is a **floating shape over the text**, not an inline image. So the
page count does not change where every other application in the group gains a
page, and the picture overlaps the paragraphs beneath it.

`check-result.sh` counts `Pictures/` entries, so it passes either way — but the
layout is genuinely different and the README says so.

Getting back to the text tool afterwards: `Escape` does **not** do it, and
neither does clicking the text-tool icon in the left rail (it is inert while a
shape is selected). A **double-click on body text** does, confirmed by the
docker heading changing from `Shape handling` back to `Text editing`.

### Block 14 — Tab does not move between cells

`Insert a table` (1066,394) opens a grid picker whose first row is
`Insert Custom...` (1125,417), and that gives a dialog with numeric fields —
much better than a grid coordinate. The dialog is pinned to 1440x900, so:

```text
  Number of columns  170,51        Number of rows  170,80
  OK  1301,877                     Cancel  1388,877
```

Then the trap. **`Tab` inserts a tab character**:

```xml
<text:p>Alpha<text:tab/>Beta<text:tab/>Gamma</text:p>
```

All three words in cell 1, cells 2 and 3 empty. On screen it looked like a
plausible narrow table. `Ctrl+Tab` does nothing at all. **The Right arrow moves
to the next cell** — verified by typing into cell 2 and reading it back out of
the saved ODT.

This one is worth dwelling on because **the ground-truth check passed it**. The
old assertion was `">Alpha<" in content`, which matches `>Alpha<text:tab/>`
happily. `check-result.sh` now parses the table and requires Alpha, Beta and
Gamma in three *separate* cells of one row.

### Block 15 — one Ctrl+End

Like AbiWord and TextMaker, and unlike LibreOffice and OpenOffice: the first
`Ctrl+End` leaves the table and reaches the end of the document.
`Page 120-121 of 121` → `Page 121-122 of 122`.

### Block 16 — Ctrl+Y is not redo

`Ctrl+Z` undoes the break, 122 → 121. `Ctrl+Y` then does **nothing** — no error,
no change, the page count simply stays at 121. Redo is `Ctrl+Shift+Z`, which the
Edit menu states plainly and which takes it back to 122.

### Block 18 — a Page Layout dialog comes first

`File > Export as PDF...` (80,231) raises `[Page Layout]`, 541x290 at 573,311 —
ISO A4, portrait, already correct — and only opens the file dialog after it is
accepted at `979,554`. Then the usual Qt dialog at 394,226 with its Name field
at 708,562.

**122 pages**, 5.3 MB. That is 120 + one page for the table + one for the page
break; the floating image adds none. `expected-pdf-pages` carries the 122.

---

## Ground truth from the measuring pass

```text
  ok   Shearwater x120 (want 120)          ok   Cormorant x0 (want 0)
  ok   typed: The kestrel circled above the reservoir befo...
  ok   typed: Three technicians logged the reading and fil...
  ok   typed: Nothing in the record explained the drop in ...
  ok   typed block carries a style (P10)
  ok   pictures x13 (want 13)              ok   tables x4 (want 4)
  ok   Alpha / Beta / Gamma in three separate cells of one row
  ok   paragraphs starting a new page x13 (12 chapters + 1 inserted), from 2 break style(s)
  ok   pdf 122 pages, 5391 KiB (want 122)
RESULT PASS
```
