# Benchmarking code editors

Eleven editors driven through the same eighteen-step editing session on the same
project: a small Python package plus one 10 MB generated source file. **All
eleven replay 18/18.**

Nothing is downloaded at measurement time and nothing leaves the container, so a
recording made today replays identically next year and on another machine.

## Editors under test

The "starts at" column says what is on screen when the editor comes up on its
own defaults, because that is what the first block of a recording has to deal
with.

| Editor | Version | Source | Starts at |
| ------ | ------- | ------ | --------- |
| [Visual Studio Code](vscode/) | 1.132.0 | `update.code.visualstudio.com`, pinned URL | three-page onboarding: sign-in, theme picker, agents — then Restricted Mode banner + Welcome tab + chat panel |
| [IntelliJ IDEA](intellij/) | 2025.3 | `download.jetbrains.com`, pinned tarball | user agreement, data sharing, project trust — then README.md and a Trial tab, with a JCEF balloon that never fades |
| [PyCharm](pycharm/) | 2025.3 | `download.jetbrains.com`, pinned tarball | the same three JetBrains dialogs, then README.md, a Trial tab and *two* balloons — the second announcing a Python interpreter |
| [Vim](vim/) | 9.1.697 | Ubuntu 24.04, pinned package | a bash prompt in a full-screen xterm; block 1 is typing `vim` |
| [Neovim](neovim/) | 0.9.5 | Ubuntu 24.04, pinned package | the same prompt; block 1 is typing `nvim` |
| [GNU nano](nano/) | 7.2 | Ubuntu 24.04, pinned package | the same prompt; block 1 is typing `nano`, and the shortcut bar is on screen from then on |
| [Sublime Text](sublime/) | build 4200 | `download.sublimetext.com`, build-pinned .deb | straight into the editor — the only one here with nothing to dismiss |
| [GNU Emacs](emacs/) | 29.3 | Ubuntu 24.04, pinned package | the splash screen; the only editor that then *refuses* the 10 MB file until you answer `y` |
| [Eclipse IDE](eclipse/) | 4.36 (2025-06) | `archive.eclipse.org`, pinned tarball | a workspace-chooser dialog, then a full-window Welcome page, then an **empty** workspace — the only editor here with no way to be handed a folder |
| [Android Studio](androidstudio/) | 2025.1.3 Narwhal 3 | `dl.google.com`, pinned tarball | usage-statistics consent, project-trust prompt — then README.md with a What's New panel taking the right third |
| [JupyterLab](jupyterlab/) | 4.6.2 in Firefox 153.0.3 | PyPI + `ftp.mozilla.org`, pinned tarball | Firefox's own *Welcome* modal, then a "notified about Jupyter news?" prompt — the only editor here with no window of its own |

Editors that live in a terminal — Vim, Neovim, GNU nano — run inside a
full-screen xterm pinned to a fixed font and size, so the character grid is
159x47 on every machine. "Start the application" for those is typing its name at
the shell prompt, and every later step is sent to the terminal.

JupyterLab has no window of its own either, but for the opposite reason: it is a
server plus a web application, so what is driven is **Firefox showing
`127.0.0.1:8888/lab`**. Its row therefore includes the browser, which is the
honest way to count it — nobody uses JupyterLab without one. Both halves are
pinned, and the server is started by a setup-command that waits for the port, so
no block ever measures it booting.

## Before you trust a run: the image

Every scenario here declares `image: ribalba/xwindow-server`, and GMT **pulls
that image unconditionally** — there is no flag that makes it prefer a local
build (`--dev-cache-build` governs building, not pulling). So a production run
measures whatever is in the registry, and `make build` on this machine is
overwritten by the next `runner.py`.

The published image currently carries `note_label`, so the notes GMT stores are
the short label before the colon — `* Load app` rather than the whole script
line. It has not always been: an image predating that feature stores a paragraph
per phase, which the checks survive (the recording replays 18/18 either way) but
which makes a report unreadable. `make push` fixes it. Confirm before believing a
run:

```bash
make build
docker run --rm ribalba/xwindow-server python3 -c \
  "import sys; sys.path.insert(0,'/usr/local/bin'); from helpers import note_label; print(note_label('* A: b'))"
# expect: * A          — an ImportError means the image predates the feature
```

`verify-editor.sh` and `record-session.sh` both use the local image and never
pull, so they see whatever `make build` last produced. That is the asymmetry to
keep in mind: a recording made here and a benchmark run by GMT are not
guaranteed to be running the same `replay.py`.

## The project

[`workspace/`](workspace/) is copied to `/root/project` by
[`common/seed-workspace.sh`](common/seed-workspace.sh) before every run —
including before every *replay*, because the scenario writes to four of these
files and a second run must start from the same bytes as the first.

```text
project/
├── constants_block.txt          the ten lines the typing step types
├── README.md
├── src/
│   ├── __init__.py
│   ├── component_library.py     generated, 337,537 lines, 10,006,238 bytes
│   ├── inventory.py
│   ├── price_calculator.py      128 lines - the file the first twelve steps edit
│   └── legacy/
│       ├── orders.py            4 x LEGACY_SKU
│       ├── pricing.py           4 x LEGACY_SKU
│       └── shipping.py          4 x LEGACY_SKU
└── tests/
    └── test_price_calculator.py
```

### `src/price_calculator.py` is shaped for the scenario

Three properties are load-bearing. Changing them does not break the file, it
breaks the *comparison* — quietly, in one editor and not another.

**`calculate_total` starts at line 110.** No editor here shows more than ~41
lines at 1440x900, so "scroll to the function" is a real scroll everywhere
rather than a no-op in the editors with a taller viewport.

**All four `tax_rate` occurrences are at or below line 110.** Editors disagree
about where a search starts — VS Code searches from the cursor, others from the
top of the buffer — and with nothing above the function both behaviours land on
the same first hit.

**`tax_rate` is never part of a longer word, and nothing spells it in another
case.** Whole-word matching is on in some editors and off in others, and VS
Code's find is case-insensitive by default while Vim's is not. A `TAX_RATE`
constant would be replaced by half the comparison and left alone by the other
half, and both halves would look right on screen.

`tax = subtotal * tax_rate` and `return subtotal + tax` are each unique in the
file, which is what lets [`common/check-result.sh`](common/check-result.sh)
assert on them.

### The ten typed lines have no brackets, quotes, colons or indentation

```python
BATCH_SIZE = 500
RETRY_LIMIT = 3
...
```

That is not laziness about writing realistic code. Typing `(` gets you `()` in
VS Code and IntelliJ and `(` in nano; typing a line ending in `:` triggers a
reindent in Vim and nothing in Sublime; typing `"` produces one character in
some editors and two in others. Ten lines of flat constant assignments are the
largest piece of real Python that every editor in this comparison turns into the
*same bytes*, which is the only way "type ten lines of code" can be one
measurement instead of eleven.

Note what is being made uniform: the **text**, not the editors. Nothing is
turned off to achieve it.

## Every editor runs on its own defaults, with one exception

No editor here is configured, with a single named exception below. No telemetry
switch is flipped and no dialog is suppressed. The macros click through whatever
each editor puts in front of them — VS Code's three-page onboarding, IntelliJ's
user agreement and project-trust prompt — because getting past those is part of
what loading that editor costs, and an editor configured into a state nobody
actually installs is not the editor anyone is choosing between.

**The exception: `"editor.largeFileOptimizations": false` for VS Code.** VS
Code turns syntax highlighting off for a file it considers large, and "large" is
not only about bytes — its limit trips at 20 MB *or* 300,000 lines, whichever
comes first. The generated module is 10 MB but **337,537 lines**, so it crosses
the line-count limit and everything from block 13 on rendered as an
undifferentiated grey wall, while all ten other editors still coloured the same
file. That setting turns it back on. There is a real argument for leaving the
default alone — not tokenising 337,000 lines is exactly how VS Code stays
responsive on a file this size — so the cost is recorded here rather than
hidden: VS Code's blocks 13 to 18 now include work its default avoids.

**Two things that look like configuration and are not.** Android Studio's block
1 closes the *What's New* tool window, and IntelliJ's and PyCharm's block 1
close the *Trial* tab. Both are recorded clicks that cost real time in the
measurement, not settings written behind the benchmark's back, and both exist
for a reason stronger than tidiness — see
[androidstudio/MEASUREMENTS.md](androidstudio/MEASUREMENTS.md) and
[common/FOCUS.md](common/FOCUS.md).

The same goes for behaviour further in. IntelliJ saves your buffer on a timer;
VS Code holds it until you ask. That difference shows up in the "Save file" step
and in the ground-truth report, and it is a **result**, not a problem to
configure away. The scenario fixes the *actions*, and lets each editor cost what
it costs — including when one needs three clicks where another needs none.

The one thing imposed from outside is the network, and it is imposed on the
harness rather than on any editor: see [`common/go-offline.sh`](common/go-offline.sh).

### `src/component_library.py` is 10 MB of real source code

[`common/generate-large-file.py`](common/generate-large-file.py) writes it at
seed time: 7,500 sections of 45 lines each, every one a class with a docstring,
a `@property`, cached computation, an f-string, a raised exception and a
comprehension, plus a module-level factory function. 337,537 lines,
10,006,238 bytes.

**It is code, not a data table, and that is the point.** A 10 MB list of tuples
is nearly free to tokenise, fold and index, so it would measure an editor's
ability to scroll a large buffer and nothing else. Ten megabytes of real Python
makes the tokeniser, the folding-region scanner, the symbol index and the
inspections all do the work they exist to do — which is exactly where these
eleven editors differ from one another.

Generated rather than committed, for the same reason the mail benchmark ships
its corpus as an image layer: what matters is that every machine ends up with
the same bytes. The output is pure ASCII from integer arithmetic — no clock, no
randomness, no compression — so two machines cannot disagree about it, and a
10 MB blob in git would cost every clone forever.

Two invariants the generator asserts on itself before writing:

- **No line exceeds 79 characters.** The narrowest editing surface here is VS
  Code's, at roughly 95 columns once the chat panel has taken its share. A line
  that wrapped there but not in Vim's 159-column terminal would put a different
  number of screen rows between two checkpoints.
- **Every section is exactly 45 lines**, so "page down ten times" lands
  predictably and line 120000 is the same place in every editor.

`LEGACY_SKU` appears nowhere in it, so the project-wide replace at the end of the
scenario costs what the three small files cost and not what a 10 MB file costs.

## The scenario

[`script.md`](script.md) — eighteen steps, in one sitting:

```text
* Load app              * Undo replace
* Open file             * Insert comment
* Scroll to function    * Save file
* Find identifier       * Reopen file
* Select line           * Open large file
* Duplicate line        * Go to line
* Undo duplicate        * Page down
* Replace all           * Go to start
                        * Type block
                        * Global replace
```

Those are only the labels. Each line continues after a colon with the exact
instruction — which identifier, which line number, which text to type — because
"undo the paste" leaves the number of undo commands up to whoever holds the
keyboard, and VS Code needs two where a modal editor needs one. See
[Script labels](../../README.md#script-labels).

## Ground truth

[`common/check-result.sh`](common/check-result.sh) reads the files on disk after
the replay. It exists because nearly every step in this scenario has a way of
looking right and being wrong:

| What it looks like | What actually happened |
| --- | --- |
| The pasted line is gone after the undo | One `Ctrl+Z` too few — an empty indented line is still there |
| "Replaced 12 occurrences" | The edit was applied in memory and never written to any file |
| The replace-all was undone | It was undone in the visible screenful, and `vat_rate` survives below the fold |
| The file was saved | Autosave had already written it, so the save step measured nothing |
| The comment was inserted before the return | It went in at column 0 in one editor and column 4 in another |

The last row is why the check is exact rather than a `grep -q`: two different
files are not a comparison.

Whether the large file reaches the disk at all is **reported rather than
asserted**. The scenario types ten lines into it and never asks for a save, so
that is a property of the editor: IntelliJ, PyCharm, Android Studio and
JupyterLab write them out on a timer, the other seven hold them in a dirty
buffer. Both are correct behaviour, and it is the explanation for a "Save file"
step that appears to cost nothing.

But **what** was written is asserted, and that assertion was added the hard way.
The old report read:

```text
on disk:  10006248 bytes, 337547 lines
seeded:   10006238 bytes, 337537 lines
```

337547 = 337537 + 10 is exactly the arithmetic a human checks, and it agreed
perfectly. The ten lines were **empty**. The Returns had arrived and every
character had been dropped, so the file was ten *bytes* larger, not ten lines.
All three JetBrains editors shipped that. The check now asserts the first and
last line of the block by content.

## Did the recording do anything at all?

[`common/check-screens.sh`](common/check-screens.sh) answers the question no
screenshot check can. A replay compares each checkpoint against **its own**
reference — so if a recording froze and five checkpoints captured the same
image, five identical references match five identical captures and the run
reports a clean pass over blocks that did nothing:

```text
androidstudio-check-014.png  d2a43215fff2fd7f803b9b07b2e3f101
androidstudio-check-015.png  d2a43215fff2fd7f803b9b07b2e3f101
androidstudio-check-016.png  d2a43215fff2fd7f803b9b07b2e3f101
androidstudio-check-017.png  d2a43215fff2fd7f803b9b07b2e3f101
androidstudio-check-018.png  d2a43215fff2fd7f803b9b07b2e3f101
```

That is a real recording that passed 18/18. A screenshot check asks "does this
look like it did when I recorded it"; it cannot ask "did the recording do
anything", because a recording that did nothing is perfectly reproducible.

Two consecutive checkpoints legitimately can match — Save file after Insert
comment leaves the pixels alone in several editors, and that is a result worth
keeping — so it reports every identical pair and fails only on a run of three or
more, which nothing in `script.md` can honestly produce.

```console
$ bash applications/codeeditors/common/check-screens.sh --all
androidstudio  ok    1 identical pairs, longest run 2, 2 repeated images
eclipse        ok    0 identical pairs, longest run 1, 1 repeated images
...
```

## How it is wired up

Each editor's `usage_scenario.yml` declares one service:

```text
  ┌──────────────────────────────────────┐
  │ window-container                     │
  │   Xvfb + fluxbox                     │
  │   the editor under test              │
  │   /root/project   (seeded per run)   │
  │   replay.py                          │
  └──────────────────────────────────────┘
```

Setup order matters and is the same everywhere:

1. `install.sh` — pinned download, and a profile written from scratch
2. `common/seed-workspace.sh` — the project, restored
3. `common/pin-windows.sh` — window geometry, **before** `entrypoint.sh`,
   because fluxbox reads `~/.fluxbox/apps` once at startup
4. `entrypoint.sh`

## Running one

```bash
# the production path
cd ../../../green-metrics-tool && ./runner.py --uri /home/didi/code/parrot \
    --filename applications/codeeditors/vscode/usage_scenario.yml

# replay in a fresh container: checks, worst RMSE, then the files on disk
bash applications/codeeditors/common/verify-editor.sh vscode

# bring the container up and stop, for measuring or re-recording
bash applications/codeeditors/common/verify-editor.sh vscode --setup

# re-record from scratch
./applications/codeeditors/vscode/record-session.sh

# every recording must define the same blocks in the same order
./tools/check_blocks.py applications/codeeditors

# pad every block to the longest that block takes anywhere, for side-by-side runs
./tools/check_blocks.py applications/codeeditors --normalize-time
```

### Reading the block table

`check_blocks.py` prints seconds per block, and those seconds are **mostly the
settle time baked into each recording**, not the editor working. A checkpoint
cannot be taken until the screen has stopped changing, and an IDE that indexes a
10 MB module needs longer to stop changing than a terminal does — so the column
is a lower bound on "how long until this editor was ready", not a stopwatch on
the edit itself.

What the numbers are actually for is energy: GMT measures each block as a phase,
and the interesting quantity is what the machine drew during it. Two editors
sitting idle for the same ten seconds do not cost the same. Use
`--normalize-time` when you want the wall-clock removed from the comparison
entirely.

`verify-editor.sh` does not keep its own copy of each editor's setup — it reads
`usage_scenario.yml` and runs that service's own setup-commands, reproducing
GMT's `shlex.split(cmd, posix=False)` argv handling. The email-client harness
mirrors its scenarios by hand and the two drift; there is nothing here to drift.

## Where the eleven differ

Seconds per block, read with the caveats above. Four cells carry an asterisk.
None of them is a defect in the editor — three are limits of what the harness
could make comparable, and one is an editor that cannot keep up with the
keyboard. All four are spelled out so the numbers are not read as something they
are not.

| Block | vim | nvim | nano | emacs | sublime | vscode | idea | pycharm | studio | eclipse | jupyter |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| Load app | 25.7 | 25.8 | 25.8 | 33.6 | 35.4 | 49.6 | 151.7 | **171.6** | 87.8 | 132.4 | 55.7 |
| Open file | 7.9 | 7.8 | 10.2 | 10.4 | 12.1 | 12.1 | 13.9 | 13.9 | 17.6 | 22.0 | 19.1 |
| Scroll to function | 7.4 | 7.3 | 7.3 | 7.4 | 10.9 | 11.7 | 11.1 | 11.2 | 26.4 | 13.5 | 11.5 |
| Find identifier | 6.5 | 6.5 | 7.6 | 8.6 | 7.5 | 7.5 | 8.5 | 8.5 | 11.4 | 15.7 | 10.6 |
| Select line | 7.3 | 7.3 | 9.8 | 11.7 | 9.4 | 9.5 | 9.5 | 9.5 | 12.0 | 11.5 | 9.5 |
| Duplicate line | 7.3 | 7.3 | 9.7 | 7.4 | 9.5 | 9.5 | 9.5 | 9.5 | 12.5 | 9.5 | 9.5 |
| Undo duplicate | 6.3 | 6.3 | 7.9 | 6.3 | 7.3 | 7.4 | 7.4 | 7.4 | 9.1 | 7.4 | 7.4 |
| Replace all | 6.8 | 6.8 | 13.0 | 13.0 | 14.1 | 14.0 | 13.2 | 13.1 | 18.6 | 19.3 | 20.6 |
| Undo replace | 6.3 | 6.3 | **11.6** | 6.3 | 6.3 | 6.3 | 7.3 | 7.3 | 9.1 | 8.4 | 8.3 |
| Insert comment | 11.4 | 11.4 | 12.5 | 13.7 | 12.5 | 12.5 | 14.5 | 14.5 | 17.3 | 17.6 | 17.5 |
| Save file | 6.4 | 6.4 | 8.3 | 6.7 | 6.3 | 6.3 | 6.3 | 6.3 | 7.7 | 7.3 | 7.3 |
| Reopen file | 10.0 | 10.0 | 12.3 | 14.0 | 13.0 | 13.0 | 17.1 | 17.0 | 19.1 | 25.1 | 22.3 |
| Open large file | 25.9 | 25.9 | 28.2 | 37.8 | 29.0 | 29.0 | 38.0 | 45.1 | **53.9** | 45.9 | 56.2 |
| Go to line | 13.5 | 13.5 | 15.5 | 16.1 | 14.5 | 14.5 | 25.5 | 27.5 | 22.7 | 20.6 | 18.6* |
| Page down | 16.0 | 16.0 | 16.0 | 16.0 | 15.9 | 15.9 | 21.6 | 22.9 | 16.9 | 15.9 | 15.9 |
| Go to start | 11.3 | 11.3 | 11.3 | 11.3 | 10.3 | 10.3 | 12.7 | 13.8 | 11.3 | 13.3 | 11.3 |
| Type block | 17.7 | 17.7 | 16.6 | 17.0 | 17.5 | 17.6 | 43.3* | 44.9* | 20.8 | 17.1 | 17.0 |
| Global replace | 19.2 | 19.2 | 60.1 | 63.4 | 62.7* | 24.2 | 32.4 | 32.5 | 34.3 | 37.2 | **114.9** |
| **Total** | 212.7 | 212.6 | 283.6 | 300.7 | 294.1 | 270.7 | 443.4 | 476.8 | 408.3 | 439.6 | 433.2 |

**Global replace splits the group in two.** Vim and Neovim do it with one
`:argdo` in 19 seconds. VS Code, IntelliJ, PyCharm, Android Studio and Eclipse
have a project-wide replace and land between 24 and 37. nano, Emacs, Sublime and
JupyterLab have none at all and open, replace and save three files by hand —
60 seconds and up, with JupyterLab paying browser latency on every one of those
steps.

**`*` on IntelliJ's and PyCharm's type-block** — and this one is a finding, not
a harness limit. Every other editor here takes the ten lines at 45 ms a
character without losing anything. The JetBrains **2025.3** platform does not:
driven at 45 ms it accepts six lines and then stops dead in the middle of the
seventh, or — if the pause between lines is lengthened instead — takes every
character and drops the *Returns*, welding lines together. Both failures leave a
file with the right line count. 120 ms a character is the slowest cadence that
was needed and the fastest that works, so those two cells contain a rate chosen
for the IDE rather than by it, and are not comparable with the rest of the row.
Android Studio, on the older 251 platform, takes 45 ms like everyone else — the
difference is the platform version, not the vendor. See
[common/FOCUS.md](common/FOCUS.md).

**`*` on Sublime's global replace** — Sublime *has* a project-wide replace and it
works by hand, but it could not be made to replay; that cell is its file-by-file
cost. See [sublime/MEASUREMENTS.md](sublime/MEASUREMENTS.md).

**`*` on JupyterLab's go-to-line** — JupyterLab has no go-to-line at all: no
keybinding, no menu item, no command-palette entry. That cell measures a
scrollbar click and a line click, which is the only way to get there. It lands
the caret on line 120000 exactly, so the two blocks after it stay comparable.
See [jupyterlab/MEASUREMENTS.md](jupyterlab/MEASUREMENTS.md).

**Undo is not one thing.** nano needs four undos to revert a replace-all —
one per occurrence — where every other editor here treats the batch as a single
operation. Emacs, Vim and Neovim need one undo for the duplicated line where the
other eight need two.

**Four editors autosave.** The three IntelliJ-platform IDEs — IntelliJ, PyCharm,
Android Studio — and JupyterLab write the ten lines typed into the 10 MB file to
disk without being asked. Vim, Neovim, nano, Emacs, Sublime, VS Code and Eclipse
leave the buffer dirty. That is why an autosaving editor's "Save file" step can
cost nothing: by the time `Ctrl+S` arrives there may be nothing left to write.
The ground-truth check reports which happened rather than configuring either
away.
