# Benchmarking word processors

Six word processors driven through the same eighteen-step editing session
against the same committed 98-page document. Nothing is downloaded at
measurement time and the document is byte-identical on every machine, so a
recording made today replays identically next year and on another machine.

## Progress

| App | Install | Landmarks | Recorded | Replay-verified |
| --- | --- | --- | --- | --- |
| LibreOffice Writer | ✅ | ✅ 18/18 | ✅ | ✅ 18 PASS, worst RMSE 0.0082, ground truth PASS |
| Apache OpenOffice | ✅ | ✅ 18/18 | ✅ | ✅ 18 PASS, worst RMSE 0.0081, ground truth PASS |
| AbiWord | ✅ | ✅ 18/18 | ✅ | ✅ 18 PASS, worst RMSE 0.0081, ground truth PASS |
| SoftMaker FreeOffice | ✅ | ✅ 18/18 | ✅ | ✅ 18 PASS, worst RMSE 0.0059, ground truth PASS |
| Calligra Words | ✅ pinned, runs | ✅ 18/18 | ✅ | ✅ 18 PASS, worst RMSE 0.0063, ground truth PASS |
| Collabora Office | ✅ pinned, runs | ✅ 18/18 | ✅ | ✅ 18 PASS, worst RMSE 0.0524, ground truth PASS |

Every one of the six is installed from a pinned version, driven through all
eighteen blocks, recorded, and replayed in a fresh container.

## Word processors under test

| Word processor | Licence | Version | Install source |
| -------------- | ------- | ------- | -------------- |
| [LibreOffice Writer](https://www.libreoffice.org/) | open (MPL 2.0) | 4:24.2.7-0ubuntu0.24.04.6 | Ubuntu 24.04 `libreoffice-writer` |
| [AbiWord](https://www.abisource.com/) | open (GPL 2.0) | 3.0.5~dfsg-3.2build4 | Ubuntu 24.04 `abiword` |
| [Calligra Words](https://apps.kde.org/calligra.words/) | open (GPL 2.0) | 26.04.3 (2 Jul 2026) | Flathub `org.kde.calligra` |
| [Collabora Office](https://www.collaboraoffice.com/) | open (MPL 2.0) | desktop suite | Flatpak |
| [Apache OpenOffice Writer](https://www.openoffice.org/) | open (Apache 2.0) | 4.1.16-3 | `archive.apache.org` deb tarball, pinned by SHA-256 |
| [SoftMaker FreeOffice TextMaker](https://www.freeoffice.com/en/download/linux) | **closed** | FreeOffice 2024, package rev 3702 | upstream deb |

One of the six is closed source. ONLYOFFICE and WPS Office were carried through
install and partway through measuring before being dropped — ONLYOFFICE never
starts, and WPS has no OpenDocument importer. Both are gone from the tree; git
history has what was ruled out.

### Notes on the awkward ones

**Calligra Words** comes from Flathub rather than apt. Ubuntu 24.04 packages
3.2.1, the Qt5 series; Flathub carries 26.04.3, which is Qt6 and has the
reworked interface. Measuring the Flatpak means measuring current Calligra, at
the cost of the Flatpak runtime being in the figure — which is a real part of
what a Flatpak costs a user, and applies to Collabora Office too.

It also **does not apply the document's fonts**. `parrot-report.odt` declares
Liberation Sans and Liberation Serif; Calligra renders body text in a sans-serif
face and its character panel reports the family as `DejaVu Sans`. This is not a missing
font — `fc-match` inside the sandbox resolves both families, and setting
Liberation Serif by hand renders it correctly and reflows the paragraph — it is
Calligra's ODF import not reading the family from the styles. The visible
consequence is that it paginates the document to **120** pages where LibreOffice
and OpenOffice make it 98 and AbiWord and TextMaker 97. The driver survives it,
because `script.md` counts keystrokes and never names a page, but **Calligra's
figure is not like-for-like layout work** and should not be read as though it
were.

Its zoom control is also inert: typing a value into the status-bar box or
picking one from its dropdown leaves the canvas untouched, and only `Ctrl++` /
`Ctrl+-` actually zoom. Its steps are a root-two progression — 25, 33.3, 50,
66.7, 100, 141.4, 176.6, 200 — with **no 150 %**. Block 6 is therefore driven as
one `Ctrl++` and one `Ctrl+-`, which from the `Fit Page Width` it opens at lands
on **141 %** (the nearest step to 150 %) and then on **exactly 100 %**. Only the
first half of that block deviates from `script.md`.

Its **image is a floating shape**, not an inline picture: Calligra Words has no
Insert menu and no inline-picture command, so the only route is Add Shape →
Image, which arms a tool and drops a shape where you click. The picture floats
over the text and adds no page, where every other app in the group gains one.
Both deviations are set out in
[calligra/MEASUREMENTS.md](calligra/MEASUREMENTS.md).

**Collabora Office** is not simply a rebadged LibreOffice any more. The current
desktop suite is Collabora Online's web-technology UI running offline, packaged
as a Flatpak, with no Java. That makes it the one entrant in the group rendering
its interface with web technology, which is exactly the architectural spread
that makes the comparison worth running. Collabora say the desktop suite is not
yet enterprise-supported and expect that during 2026.

Confirmed in the container: it is **QtWebEngine**, declaring
`base=app/io.qt.qtwebengine.BaseApp` and `command=coda-qt`, and its window
reports `WM_CLASS "coda-qt", "Collabora Office"` rather than anything
LibreOffice-shaped. Chromium refuses to start as root, so the install disables
its sandbox — see [collabora/MEASUREMENTS.md](collabora/MEASUREMENTS.md).

It is also the most faithful of the newcomers: **98 pages** and the correct
Liberation fonts, matching LibreOffice and OpenOffice exactly, against AbiWord
and TextMaker at 97 and Calligra at 120 in the wrong font. It opens documents in
a read-only **Viewing** mode that has to be switched to Editing before anything
in blocks 3-18 can be driven.

Two things about it are worth knowing before reading its figure. It **autosaves**,
so the document on disk is already rewritten before block 17 presses Ctrl+S —
that write is in somebody's measurement whether or not it is wanted. And its
**block 1 ends on the start screen rather than an editable page**, which is a
deliberate deviation from `script.md`: Collabora opens one window per document
and never reuses an empty one, so creating a blank document to satisfy block 1
leaves two 1440x900 windows with the same `WM_CLASS`, and from that point neither
the recorder nor `replay.py` can tell which one to photograph. The start screen
is this application's launch state and block 1 measures a launch.

**SoftMaker FreeOffice** does **not** ask for a product key on first launch —
this was tested, see below. It does put two modal dialogs in front of the
document, and it opens a welcome document rather than a blank one.

**Apache OpenOffice** has not had a feature release since 2014; 4.1.16 is a
maintenance update. It is here for the historical comparison, not because anyone
should use it. It is also the reason the script is ODT rather than DOCX. Debian
dropped it, so it comes from the upstream tarball.

### Considered and not included

| | Why not |
| - | ------- |
| Hancom Office (Hangul) | A Linux build exists and is widely used in Korea, but there is no public trial download to install from. |
| Microsoft Word | No native Linux build. Only reachable through Wine/CrossOver or the browser, neither of which measures the same thing as the others. |
| Google Docs, Word for the web | Browser plus network. Non-reproducible, and it would be measuring the browser. |
| FocusWriter | No tables, no images. Cannot do most of the script. |
| LyX | A document processor over LaTeX. Different interaction model end to end. |
| Ted | Not packaged for Ubuntu 24.04. |
| Gnumeric, Scribus | Spreadsheet and DTP, not word processors. |

### Popularity

Debian popcon data from <https://popcon.debian.org>:

```text
package                      inst     vote     old      recent
libreoffice-core             119231   29128    44775    45309
libreoffice-writer           117394   28788    44065    44531
libreoffice                  14816    4        19       2
pandoc                       12996    2780     9115     1096
scribus                      3494     321      3001     172
gnumeric                     3043     830      1937     276
lyx                          2126     227      1767     132
abiword-common               1515     252      1123     72
abiword                      1445     252      1121     72
calligrawords                826      71       712      42
calligra                     474      20       205      17
openoffice.org               282      0        0        0
focuswriter                  220      44       163      13
ted                          146      127      19       0
wordgrinder                  121      0        0        0
collabora-office             0        0        0        0
onlyoffice-desktopeditors    0        0        0        0
softmaker-freeoffice         0        0        0        0
textmaker                    0        0        0        0
wps-office                   0        0        0        0
```

The zeroes at the bottom are packages Debian does not carry. The two of them
still in the group — SoftMaker FreeOffice and Apache OpenOffice — are installed
from upstream here. The distribution is far more lopsided than the PDF
readers or the email clients — LibreOffice Writer is on 117k machines and the
next open-source word processor is on 1.4k.

## What was tested

### SoftMaker FreeOffice does not want a key on first launch

The forums say the trial ends after roughly ten days without a free product key,
which would mean an email address and an online activation in the middle of a
benchmark. Installed and launched in `ribalba/xwindow-server` to find out what
actually happens on a fresh container:

```text
first launch
  1. "User interface"  modal — choose Ribbon or classic menus and toolbars
  2. "User info"       modal — name, company, address; cancellable
  3. "Welcome to TextMaker.tmdx - TextMaker"

second launch, same container
  1. "Untitled 2 - TextMaker"  — straight into an editable document
```

No licence prompt, no key entry, no network check that blocks startup. Every run
starts from a fresh container, so the ten-day trial clock never reaches day one —
FreeOffice will never ask.

Dismissing the two dialogs once writes settings under `/root/.config` and
`/root/.local/share`, and neither reappears on the next launch. So they can go
into a seeded profile the way the email clients carry `profile.tar.gz`, and the
measured recording starts from an editable document like everybody else's.

Two things still have to be handled in the recording rather than the profile: it
reopens `Welcome to TextMaker.tmdx` alongside the new document, and it keeps a
"Welcome to FreeOffice!" sidebar open down the right-hand side, which takes about
a fifth of the window width.

### The document renders and paginates

`parrot-report.odt` was converted to PDF with LibreOffice 25.8.7.3 to confirm the
hand-written ODF is valid, the figures embed, the tables draw and the pagination
lands where intended.

## The document

[`parrot-report.odt`](parrot-report.odt) is committed, the way the PDF group
commits [`20yearsofKDE.pdf`](../pdf_viewers/20yearsofKDE.pdf).
[`generate_document.py`](generate_document.py) is what produced it, so the
document can be changed and rebuilt rather than hand-edited.

| | |
| - | - |
| Size | 8.7 MiB |
| Pages | 98, as LibreOffice paginates it |
| Words | 54,607 |
| Figures | 12 PNGs, one per chapter, ~740 KiB each at 1200×770 |
| Tables | 3, four columns by six rows |
| Structure | 12 chapters (`Heading 1`), 4 sections each (`Heading 2`) |
| Fonts | Liberation Serif body, Liberation Sans headings |
| `Cormorant` | exactly 120 occurrences |
| `Shearwater` | zero occurrences |
| sha256 | `ac2cbe2fc3091691d08d6abb3853987e6b2145b5a91bc25a8b38d8475bb0375d` |

[`parrot.png`](parrot.png) is the separate figure the scenario inserts from disk
during the run — 745 KiB, from the same generator under a different seed so it is
visibly not one of the twelve already in the document.

The generator is deterministic: every random choice comes from `SEED`, every zip
entry carries a frozen timestamp, and nothing is read from the clock or the
network. Two runs produce the same bytes:

```bash
./generate_document.py && sha256sum parrot-report.odt
./generate_document.py && sha256sum parrot-report.odt   # same digest
./generate_document.py --check                          # assert the anchors
```

`Cormorant` is the find-and-replace anchor, spread evenly through the body so
"replace all" does an identical, assertable amount of work in every app.
`Shearwater` is absent before the replace, so the result is checkable afterwards.
Neither token appears in the generator's vocabulary, so neither can turn up by
accident.

The prose is real English assembled from a fixed vocabulary and twelve sentence
templates. It reads as a plausible engineering field report and, more to the
point, contains nothing any autocorrect will rewrite.

**The container needs `fonts-liberation` installed.** If Liberation Serif is
missing the app substitutes something else and the document paginates
differently, which would put a different number of Page Down presses into each
recording.

**The document is copied to `/tmp` in setup, not symlinked out of the checkout.**
The script saves over it, so the checkout would be dirty after every run.

## The harness

```text
common/
├── setup-container.sh   rebuild window-container from an app's usage_scenario.yml
├── pin-windows.sh       deterministic window geometry, and no window-manager key grabs
├── measure.sh           helpers for measuring landmarks by hand
├── check-result.sh      ground truth: what the run left on disk
└── verify-app.sh        replay in a fresh container, report RMSE and ground truth

<app>/
├── usage_scenario.yml   the Green Metrics Tool entry point - the production path
├── install.sh           pinned install, run as a setup-command
├── MEASUREMENTS.md      every landmark drive-scenario.sh is built from
├── drive-scenario.sh    one block per script.md line, each ending in a checkpoint
├── record-session.sh    tears down, rebuilds, starts the recorder, drives it
├── <app>-check-0NN.png  the reference screenshots
└── <app>.parrot         the macro
```

`setup-container.sh` **reads the setup-commands out of the scenario file** and
runs them through `shlex.split(cmd, posix=False)`, which is what GMT does. It
does not keep its own copy. The email client group's verify script keeps a
hand-written copy of each scenario's setup and that copy drifts silently — at
which point the thing being recorded is not the thing being measured.

`check-result.sh` is the assertion that matters. Every defect this group has
produced so far was invisible in the screenshots: a replace-all that reported a
count and changed nothing, a page break the window manager swallowed, a typed
line that landed in a table cell. A screenshot check answers "does this look
like it did when I recorded it"; only the saved document answers "did the run do
the work".

```bash
# record end to end - rebuilds the container first, then checks ground truth
./applications/wordprocessors/libreoffice/record-session.sh

# replay in a fresh container; prints checks, worst RMSE, ground truth
bash applications/wordprocessors/common/verify-app.sh libreoffice

# structural comparison across every recording in the group
./tools/check_blocks.py applications/wordprocessors

# the production path - run this at least once before calling a recording done
cd ../green-metrics-tool && ./runner.py --uri /home/didi/code/parrot \
    --filename applications/wordprocessors/libreoffice/usage_scenario.yml
```

### Two scenarios per app, and picking the wrong one is silent

Each app carries **two** usage scenarios. They build the same container, run the
same setup, and check against the same reference screenshots and the same ground
truth. They differ only in which recording they replay.

| File | Replays | Use it for |
| --- | --- | --- |
| `usage_scenario.yml` | `<app>.parrot` | what the app costs at its own pace |
| `usage_scenario_normalized.yml` | `<app>-normalized.parrot` | **comparing apps against each other** |

The reason the second one exists: **96–99 % of every recording in this group is
deliberate `wait`**, and each driver was paced to whatever that app needed to
settle. Un-normalized, the six runs span 445 s (LibreOffice) to 1173 s
(Collabora) — a 2.6× spread that is mostly the driver's safety margin rather
than the application. Each scenario is a single flow command, so GMT reports one
phase covering the whole replay; comparing those figures across apps largely
ranks how patient each driver is.

`tools/check_blocks.py --normalize-time` pads every block out to the longest that
block takes in *any* recording in the group, as a single `wait` inserted
immediately before the block's checkpoint. Action timing inside a block is
untouched — only the settled idle at the end of it grows. All six then run
**1269.515 s**, with every one of the eighteen blocks occupying identical
wall-clock in each.

What that costs: every app now pays the slowest app's idle in every block, so the
normalized figures are *not* "what this app costs a user". They are a
like-for-like comparison and nothing else. Report which variant produced a number.

Regenerate after **any** re-recording — the padding is computed across the whole
group, so one new recording changes all six files:

```bash
./tools/check_blocks.py applications/wordprocessors --normalize-time
bash applications/wordprocessors/common/verify-app.sh <app> --normalized
```

All six padded recordings were replayed in fresh containers against the same
reference screenshots and the same ground truth:

| App | Normalized replay | Un-normalized, for comparison |
| --- | --- | --- |
| LibreOffice Writer | 18 PASS, worst RMSE 0.00824 | 0.0082 |
| Apache OpenOffice | 18 PASS, worst RMSE 0.00808 | 0.0081 |
| AbiWord | 18 PASS, worst RMSE **0.01054** | 0.0081 |
| SoftMaker FreeOffice | 18 PASS, worst RMSE 0.00589 | 0.0059 |
| Calligra Words | 18 PASS, worst RMSE 0.00576 | 0.00576 |
| Collabora Office | 18 PASS, worst RMSE 0.01021 | 0.01021 |

Ground truth PASS for all six. Five reproduced their un-normalized figure to
three significant figures; **AbiWord is the only one that moved**, 0.0081 →
0.01054. That is still 19× under the 0.2 threshold, and the likeliest cause is
the text caret being captured at a different blink phase now that more idle
precedes each checkpoint — but it is the one number that responded to the
padding at all, so watch it rather than assume.

The identical-consecutive-checkpoint counts are unchanged by normalizing, because
the reference images are: LibreOffice 1, AbiWord 2, FreeOffice 3, the rest none.
Every one is already explained in that app's `MEASUREMENTS.md`, together with
what covers the block instead — for the blocks whose end state *is* their start
state, a perfect replay and a dead one produce the same image, and only the
ground truth can tell them apart.

## Why the script looks the way it does

The rule is the intersection, not the union: **every step must be something all
six can do.** That is what pushed several obvious steps out.

* **ODT everywhere, for both opening and saving.** DOCX is what people actually
  exchange, and it is what TextMaker is tuned for — but
  Apache OpenOffice cannot *write* DOCX at all, and AbiWord's and Calligra's
  OOXML export is rough. ODT is the only format all six both read and write.
  The cost is that it flatters the LibreOffice family. A second DOCX run is the
  honest comparison to make next, though it would have to leave OpenOffice out of
  the write half.
* **The cursor is placed with Ctrl+Home, Ctrl+End and Page Down, never by page
  number.** The same ODT paginates differently in six layout engines, so "go to
  page 81" is not the same instruction twice. Fixed keystroke counts are.
* **The typed text is autocorrect-proof.** No apostrophes, quotes, double
  hyphens, ellipses, ordinals, fractions, URLs, or lines starting with a dash or
  a digit — every one of those is silently rewritten, differently, by each app's
  autocorrect. Every sentence already starts with a capital, so
  auto-capitalisation is a no-op. This is the same problem the code editors had
  with auto-close and auto-indent, solved the same way: by not typing anything
  any of them will touch.
* **Autocorrect and autosave are off in the seeded profile** wherever the app
  lets a profile carry the setting. The typed text survives autocorrect either
  way, but a background autosave would put a write in the middle of somebody
  else's measurement.
* **Undo is exercised on a page break only.** "Undo five times" is not one
  instruction: typing a paragraph is one undo unit in some apps and one per word
  in others. A page break is a single undo unit everywhere.
* **Spell check is not in the script.** Every app ships a different dictionary,
  so the number of flagged words differs, and the correction dialog is an
  open-ended interaction rather than a bounded step.
* **Word count, track changes, comments and mail merge are not in the script.**
  AbiWord and Calligra Words cannot do all of them, and the intersection rule
  wins.
* **Every step is one line, however long.** The typed block was originally
  written as a step followed by its three lines indented underneath, which reads
  far better. `record-macro.py` skips blank and `#` lines and nothing else, so it
  consumed each of those three as its own checkpoint note: 21 items against 18
  blocks, and every note from "Type paragraph" onwards attached to the wrong
  block. The recording would have had the right number of checkpoints and the
  wrong labels on all of them. There is no continuation syntax — if a step needs
  three sentences, it gets one long line.
* **There is no "close the app" step.** Neither the PDF viewer nor the email
  client group ends by quitting, and a checkpoint is a screenshot of the
  application window — so a block whose action removes that window has nothing
  left to photograph. The script ends at Export PDF.

* **PDF comes out by whichever route the app offers.** A direct "export as PDF"
  and a "print to file" that writes a PDF are the same user intent and the same
  deliverable, so both are in scope and the step is written to allow either.
  Forcing every app down one route would measure whose menu happens to match,
  not what producing a PDF costs.
* **The Flatpak runtime is in the figure, not factored out.** Calligra and
  Collabora are installed the way their projects ship them, and what that costs
  to start and run is part of what a user pays for choosing them.
* **The two Flatpaks run as an unprivileged user, everything else runs as root.**
  Not tidiness: `bwrap` picks its privileged sandbox path when the real uid is 0,
  and a container is where uid 0 does *not* imply `CAP_SYS_ADMIN`. Running the
  application as uid 1001 puts it on the unprivileged path, which is what lets
  their containers drop `SYS_ADMIN` and `NET_ADMIN` entirely. What is left is two
  `--security-opt` relaxations; the reasoning and the residual risk are in
  [`HANDOFF.md`](HANDOFF.md).

## Still open

1. **A second DOCX pass**, or ODT only — every app here can write DOCX except
   Apache OpenOffice.
