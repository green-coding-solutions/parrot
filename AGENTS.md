# Recording a `.parrot` file — notes for an agent

`README.md` documents what Parrot *is*. This file is about producing a recording
that is worth having: one that replays on another machine, next year, and does the
thing it claims to do.

Everything below was paid for by a defect that survived a passing replay. None of
it is theory.

---

## The shape of a client directory

```text
applications/<group>/<app>/
├── usage_scenario.yml     the Green Metrics Tool entry point - the production path
├── install.sh             pinned install, run as a setup-command
├── seed-account.sh        optional: state that cannot be shipped as a file
├── profile.tar.gz         optional: a captured home, for credentials and the like
├── MEASUREMENTS.md        every landmark drive-scenario.sh is built from
├── drive-scenario.sh      the xdotool coordinates, one block per scenario step
├── record-session.sh      tears down, rebuilds, starts the recorder, drives it
├── <app>-check-0NN.png    the reference screenshots
└── <app>.parrot           the macro
```

`../script.md` holds the scenario, one `* Label: detail` line per block. The label
before the first colon is what appears in the measurement notes.

---

## The loop

1. **Bring the app up exactly as `usage_scenario.yml` does, and leave it running.**
   Not "close enough" — the layout you measure has to be the layout the recording
   will meet.
2. **Measure one interaction at a time, screenshotting after each.** Write findings
   into `MEASUREMENTS.md` as you go, not at the end.
3. **Verify every mutating action against ground truth as you measure it**, not
   after the recording. For a mail client that is the IMAP server; for anything
   else it is whatever the app is supposed to have changed.
4. Write `drive-scenario.sh`, then `record-session.sh`.
5. **Record.** Then check: 0 warnings, the right number of checkpoints, all PNGs at
   the pinned resolution, the recorded notes are the real scenario steps, and the
   ground truth matches.
6. **Replay-verify in a fresh pair of containers**, and read the RMSE column.
7. **Open the reference screenshots and compare them against another app's** for
   the same step.

Steps 3 and 7 are the ones that catch real defects. Skipping them is how a broken
recording gets committed.

---

## The rule that matters

**Verify against ground truth, not against the screenshots.**

Every serious defect in this project so far produced **0 warnings, the right number
of checkpoints, the right number of PNGs, and a passing replay** — and was visible
only on the server:

| What it looked like | What had actually happened |
| --- | --- |
| Row disappears, source count drops by one | Message moved to a *local* folder the server never sees |
| Composer closes, message really is delivered | The sent copy was filed locally; `Sent` never moved |
| "Empty trash" confirms and the list goes empty | Only `\Deleted` was set; nothing was expunged |
| Delete looks like a complete no-op | Flagged in place; visible only in `DELETED` |
| Archive step succeeds, counts all plausible | The message went into **Sent** — one menu row off |

Check flag counts, not just item counts.

### And ground truth has a blind spot

**It cannot tell you WHICH item was acted on.** Two clients read the wrong message
at step 3 while every automated signal passed: 17 checkpoints, 17 screenshots, no
warnings, replay 17/17, and exactly the right counts. Counts do not record
identity.

Comparing the same checkpoint across two apps is the only thing that catches this.
Do it once per app, on the two steps that open a specific named item.

---

## Traps

### Measuring

**Coordinates are a property of the state, not of the app.** Measure them in the
state they are used in. Things that have moved a layout out from under a driver:

- a tab bar appearing (content down 36 px)
- creating a folder (a row inserted, everything below down 28 px)
- a context menu gaining an entry for *that particular item* (25 px)
- filling a recipient field, which made the composer grow a second row (25 px)
- **writing a config value**, which promoted two folders to the top of a tree and
  moved everything else down one or two rows — in the tree *and* in the menus

The last one is the nastiest: the layout depends on setup that has not run yet
while you are measuring by hand.

**A window's reported origin is not its visible corner.** `xdotool
getwindowgeometry` reported a position 45 px below the top of the decorated frame
for one toolkit's dialogs. An offset derived by subtracting the frame's position
off a screenshot put the click on the dialog's bottom margin — where nothing
happens and the dialog stays up, silently, because the click *did* land on the
dialog. Derive offsets by clicking and reading back.

**With a menu open, the menu bar is live.** Moving the pointer along it switches to
whichever item is under the cursor. A "hover the row above, then click" helper
whose hover lands back on the menu bar switches menus and fires the wrong action.

**A tooltip can become the reference screenshot.** The recorder captures
`xdotool search --onlyvisible --class <class> | head -n1` — the *first* match, not
the largest — and toolkit tooltips carry the application's own `WM_CLASS`. A
tooltip sorts before the main window, so a checkpoint taken with one on screen is a
228x45 picture of the tooltip. xdotool leaves the pointer wherever it last clicked.

Two defences, both required:

```bash
park() { X mousemove <somewhere inert>; sleep 1; }   # before every checkpoint

CP() {                     # and assert what would be captured
  sleep "${2:-3}"; park
  geo="$(Q "w=\$(xdotool search --onlyvisible --class <class> | head -n1);
            xdotool getwindowgeometry --shell \$w | grep -E '^(WIDTH|HEIGHT)='")"
  case "$geo" in *"WIDTH=1440"*"HEIGHT=900"*) ;;
                 *) echo "  WARNING: '$1' would capture $geo" ;; esac
  X key --clearmodifiers Scroll_Lock; sleep 2
}
```

**Silent no-ops are the norm.** An action with nothing configured behind it accepts
the click and does nothing. So does one that operates on a list the app has not
loaded yet. Always confirm externally.

### Driving

**Window management is not an input event.** `xdotool windowactivate`,
`windowfocus`, `windowraise` and `windowsize` are never recorded by `xmacrorec2`,
so a macro built on them types into nothing on replay. Click to focus instead, and
pin geometry with `common/pin-windows.sh` so absolute clicks are safe.

**`pin-windows.sh` must run before `entrypoint.sh`.** fluxbox reads
`~/.fluxbox/apps` once at startup and will not replace an existing file.

**Scope the pin rule when dialogs share the main window's class.** Otherwise they
match the full-screen rule, get moved to 0,0 and are stacked *underneath* the main
window — a modal prompt that is invisible, unclickable and looks like a hang.
`pin-windows.sh` takes an optional `role` argument for this.

**Pinning the main window is not enough if the macro clicks a dialog.** fluxbox's
`CascadePlacement` positions each new window by *how many* are already mapped, so a
dialog's position depends on what else the app happened to open. Betterbird's SMTP
password prompt lands at `491,415` normally and at `492,429` when a "Sending
Message" progress window is also up — 14 px lower, which is enough for the recorded
`OK` click to miss the button. The prompt is then never answered, the send never
completes, the composer is still open when the checkpoint fires, and the check
comes back at RMSE 0.696 with a **black rectangle** where the composer sits
(`import -window` on an obscured window returns unpainted area as black).

The signature is distinctive and worth recognising:

- every earlier check pixel-identical, one check catastrophically wrong;
- the **same** RMSE on every failure, even against a freshly recorded reference —
  deterministic once triggered, but only triggered sometimes;
- a large black region in the captured image.

If a macro clicks a dialog at absolute coordinates, that dialog needs a position
rule of its own, or the state behind it needs seeding so the dialog never appears.
Seeding is the better answer: it removes the interaction rather than stabilising
it.

Two things that cost time on the way to that conclusion:

- **More slack does not fix a wrong position.** 25 s of extra wait before the
  clicks changed nothing, because the click was in the wrong *place*, not at the
  wrong *time*. Distinguish the two before re-recording: a timing failure varies,
  a placement failure gives the **same RMSE every time**.
- **Check the checkbox is actually ticked.** A comment claiming the client
  pre-ticked "remember this password" was simply wrong — it was an empty box, so
  typing the password stored nothing and the prompt came back on every run.
  Screenshot the dialog rather than trusting the comment.

**"Go to the top" must move the selection, not just the cursor.** `Ctrl+Home` moves
the cursor and leaves the selection alone in some list widgets, so the view scrolls
back on the next re-render. `Home` moves both. And the list needs keyboard focus
first — often only a *row click* gives it that; clicking a folder or a scrollbar
does not.

**Three clients now have had the same defect: the list scrolls to its first unread
message when the folder finishes populating, which is AFTER the click that
selected the folder.** Any "go to the top" sent in between is undone, and the next
row click opens the wrong message. Assume every client does this until you have
watched one that does not, and end any step that opens a large folder with
*row click → `Home` → row click*.

Adding time does not fix it — one of these went 25 s → 45 s → still failing.
The list has to be put back at the top **after** it has settled, not waited at.

**Some things are not a keystroke.** "Scroll to the bottom without opening
anything" is impossible with `End` where selection changes open the item. A
*middle click* on a `QScrollBar` trough jumps the thumb there absolutely — one
click for a 2,100-row list, and the selection never moves.

**Confirmation dialogs need clicking, not `Return`.** But do not click a dialog's
body first — that dismisses some modals.

**Wait for a window that will still be there.** A composer titled `(unnamed)` until
the subject is typed means `wait_gone "unnamed"` returns immediately and the
checkpoint can be taken with the composer still open.

**Never edit a driver while it is running.** bash reads a script incrementally; an
edit that changes byte offsets corrupts the run in flight. If you must patch a
running driver, the change has to be byte-length-preserving and written in place
(`open(p,'r+b')`) — `sed -i` replaces the inode and the running shell keeps reading
the old one.

### Checking

**Read the RMSE column, not the pass count.** A check that passes at 0.195 against
a 0.2 threshold will fail on another machine. `common/verify-client.sh` prints the
worst three.

**Distinguish a thin margin from rot.**

- *Timing* margin → re-record with more slack. Waits are baked into the recording,
  so never raise the threshold.
- *A region drawn from the wall clock* → mask it with `CHECK_IGNORE_RECT`, in the
  client's `usage_scenario.yml` **and** in `common/verify-client.sh`. Two sources
  seen so far: a side panel listing the next seven days, and the timestamps on
  items the scenario itself creates during the run.

Mask narrowly. Blanking a whole column also hides the static values that would
catch a list which had scrolled or re-sorted.

**`REPLAY_IGNORE_CHECKS` skips checks; it does not continue past failures.** It is
a debugging aid for a driver, not a way to get a recording verified.

**Do not let `set -e` skip the ground-truth check.** A verification script under
`set -euo pipefail` dies on any `grep` that legitimately matches nothing — and if
that grep sits *above* the ground-truth check, the run ends after printing
`17/17 passed` and never reports the mailbox at all. That is exactly the shape of
failure this whole file is about: a green result covering a check that never ran.
Put `|| true` on every diagnostic pipeline, and keep the ground-truth check first
if you can.

### The scenario file is the production path, and it is not what you tested

`common/verify-client.sh` *mirrors* `usage_scenario.yml`; it does not run it. Three
things live in both and drift silently:

- the `pin-windows.sh` arguments,
- which seeder runs, and in what order,
- `CHECK_IGNORE_RECT`, and any other `environment:` entry.

**Setup-commands get no shell.** GMT runs them as

```python
d_command = ['docker', 'exec', name, *shlex.split(cmd, posix=False)]
```

`posix=False` **keeps quotes as literal characters**, so
`pin-windows.sh … 'kmail-mainwindow.*'` passes the apostrophes through and produces
a fluxbox rule that matches nothing — the window is never pinned and the first
check fails on a size mismatch. There is no shell, so a bare `*` is not expanded
either: write the argument unquoted. Add `shell: bash` to the command object if you
genuinely need shell syntax.

**GMT's exit code is not a pass/fail signal.** A run whose flow raised
`CalledProcessError` — a failed screenshot check — still exited **0** and printed a
normal cleanup. The reliable signals in the log are:

```bash
grep -c "MEASUREMENT SUCCESSFULLY COMPLETED" run.log   # 1 = the flow completed
grep -ci "FAIL ref="                          run.log  # must be 0
grep -c  "PASS ref="                          run.log  # must equal the block count
```

Note the check lines appear **three times each** in a GMT log — once streamed, once
in the exception's captured stdout, once in stderr — so divide before comparing to
the block count.

Validate argv handling without touching the GMT database:

```bash
python3 -c "
import shlex, subprocess
cmd = 'bash /tmp/repo/.../pin-windows.sh app 1440 900 Class role.*'
print(subprocess.run(['docker','exec','c',*shlex.split(cmd, posix=False)]))"
```

### Repository

**`<!-- -->` in `script.md` is recorded as checkpoint notes.** `record-macro.py`
skips blank and `#` lines only, so an HTML comment block is consumed as note text
and every block ends up named after your prose — with the correct block count and a
passing replay. Keep explanations in `README.md`.

**An empty `windowclass` is meaningful** and must be preserved end to end — it means
"match on title alone", needed when an app gives dialogs the same `WM_CLASS` as its
main window.

**An app that shows a dialog before its real window needs `startupwindowclass`.**
`replay.py` waits for the recording's window before playing the first event, so an
app whose window only appears after the macro has clicked a startup dialog away —
the JetBrains IDEs and their user agreement — deadlocks on that wait and dies with
"the app did not map a window in 90s". The startup matcher names a window that only
proves the process is up; positioning and Checks keep the recording's own matcher.
See the README section "Apps whose window appears only after the macro clicks".

**Never rewrite `WM_NORMAL_HINTS` wholesale.** `freeze-window-size.py` reads the
window's hints back and changes only the size fields. Writing a fresh structure
drops `win_gravity`, and with it the difference between "put the client here" and
"put the frame here": every Qt window silently moved 1,23 down under fluxbox, hung
off the bottom of the screen, and `import -window` returned 1439x877 where the
reference was 1440x900. Apps that get their geometry from `pin-windows.sh` are
immune — an undecorated window has no offset to lose — which is why only the
`pdf_viewers` group broke.

**Check the image is current before you trust anything.** `ribalba/xwindow-server`
silently reverted to an 8-week-old build mid-project, losing features the
recordings depended on:

```bash
make build
docker run --rm ribalba/xwindow-server python3 -c \
  "import sys; sys.path.insert(0,'/usr/local/bin'); from helpers import note_label; print(note_label('* A: b'))"
# expect: * A
```

**`tools/check_blocks.py <dir>` must report that every `.parrot` defines the same
blocks in the same order.** That is what makes the energy figures comparable.

---

## State that cannot be shipped as a file

Some apps store configuration as a **runtime-generated identifier** — a database row
id, a keyring handle — rather than a name. Those cannot go into a committed profile:
the value is regenerated on every install, so a captured one is *valid but wrong* on
the next machine, and wrong silently.

Five runs of one identical setup produced five different ids for the same folder.

The fix is a `seed-account.sh` setup-command that **resolves the value at run time**:
bring the backing store up, look the thing up by *name*, write the id it finds, shut
the store down. Every run resolves its own. Two ordering rules learned the hard way:

- config-file edits must happen **after** the service has stopped — it rewrites its
  own config on shutdown and will revert them;
- database writes must happen **before**, while the service is up.

And check what the app actually *reads*. One documented config key was faithfully
honoured over D-Bus and completely ignored by the code path that mattered, which
consulted a different mechanism entirely.

---

## Commands

```bash
# record end to end - tears down and rebuilds both containers first
./applications/<group>/<app>/record-session.sh

# replay in a fresh pair of containers; prints checks, worst RMSE, ground truth
bash applications/<group>/common/verify-client.sh <app> [args]

# structural comparison across every recording in a directory
./tools/check_blocks.py applications/<group>
./tools/check_blocks.py applications/<group> --normalize-time

# the production path - run this at least once before calling a recording done
cd ../green-metrics-tool && ./runner.py --uri /home/didi/code/parrot \
    --filename applications/<group>/<app>/usage_scenario.yml
```

Watch any of it at <http://localhost:6080/vnc.html> when the container maps 6080.
