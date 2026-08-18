# The checkpoint takes focus away from the application it photographs

This is the single most expensive thing anyone working on this group needs to
know, it is invisible in every screenshot, and it cost four recordings before it
was understood. It is written here rather than in one editor's notes because it
is a property of the **harness**, not of any editor.

## What happens

Every checkpoint captures a screenshot, and both the recorder and the replayer
raise and focus the window first — `timed_xmacro.py:_capture_screenshot` and
`replay.py:222`:

```sh
xdotool windowraise "$win"
xdotool windowfocus "$win"
sleep 0.1
import -window "$win" "$SNAPSHOT_OUT"
```

`xdotool windowfocus` sets X input focus to the **top-level frame**. On a Java
application that is not the same as focusing anything inside it: Swing's focus
owner ends up unset. The window has focus; no component in it does.

Measured directly, straight after a checkpoint:

```text
$ xdotool getwindowfocus getwindowname
project – component_library.py          <- the frame
```

...and after `Ctrl+G`, which should have handed focus to a popup:

```text
$ xdotool getwindowfocus getwindowname
project – component_library.py          <- still the frame, not "Go to Line:Column"
```

## Why it is so hard to see

IntelliJ keeps working. Keystrokes bound to **actions** — `Return`, `Page Down`,
`Ctrl+Home`, `Ctrl+G`, `Ctrl+Shift+R` — are dispatched by the IDE's own action
system against the *selected editor*, and they all still arrive. Only two things
fail:

| | |
| - | - |
| Plain printable characters | go through `TypedAction`, which needs a focused editor component. Dropped, silently. |
| Focus transfer to a popup | the popup opens and draws, but never receives keyboard focus. |

So a block that presses `Ctrl+G`, types `120000` and presses `Return` produces:
a popup that opens, digits that go nowhere, and a `Return` that falls through to
the editor. The popup then sits over the file **for the rest of the run**.

And because that popup is a separate top-level window overlapping the frame,
every subsequent screenshot comes out byte-for-byte identical, with a black
rectangle where the popup is. Five checkpoints, one image, eighteen passes:

```text
androidstudio-check-014.png  d2a43215fff2fd7f803b9b07b2e3f101
androidstudio-check-015.png  d2a43215fff2fd7f803b9b07b2e3f101
androidstudio-check-016.png  d2a43215fff2fd7f803b9b07b2e3f101
androidstudio-check-017.png  d2a43215fff2fd7f803b9b07b2e3f101
androidstudio-check-018.png  d2a43215fff2fd7f803b9b07b2e3f101
```

A replay compares each checkpoint against **its own** reference. Five identical
references matched five identical captures, and the run reported 18 PASS 0 FAIL.
IntelliJ and PyCharm shipped the same defect at checks 14–17.

## The fix, and the fix that is a trap

**Click into the editor first.** A real click gives Swing a focus owner, and
everything transfers normally from there. It is a genuine user action, it is
recorded, and because `replay.py` perturbs focus exactly the same way the
recorder does, the recorded click does the same job on replay.

```sh
X mousemove 900 400 click 1; sleep 2
K ctrl+g; sleep 5
T '120000'; sleep 2
K Return
```

**Do not add `Ctrl+A` to "clear the field first".** It looks like the safe way
to deal with a pre-filled popup. If focus is ever *not* in the popup it selects
all 337,537 lines of the open file, and the `Return` after it replaces every one
of them with a newline. That is not hypothetical — it is what the second
recording of Android Studio did, and `check-result.sh` caught it:

```text
on disk:  1 bytes, 1 lines
seeded:   10006238 bytes, 337537 lines
```

The popup pre-selects its own contents anyway.

## Which blocks are exposed

Any block whose first keystroke after a checkpoint either types into the editor
or opens a popup that must receive text. In practice:

| Block | First keystroke | Seen to fail |
| - | - | - |
| 2, 12, 13 | `Ctrl+Shift+N` | yes — IntelliJ, once |
| 4, 10 | `Ctrl+F` | not yet |
| 8 | `Ctrl+R` | not yet |
| 14 | `Ctrl+G` | **always**, all three JetBrains editors |
| 17 | types directly | **always**, all three |
| 18 | `Ctrl+Shift+R` | not yet |

Block 14 and block 17 fail every time; the rest fail occasionally. Blocks 14 and
17 therefore carry the click permanently. The others are left alone and are
caught by verification when they do go wrong — which is the point of the two
checks below.

## What now catches it

Neither of these existed when the broken recordings were made.

**`check-screens.sh`** fails a recording in which three or more consecutive
checkpoints are the same image. A screenshot check answers "does this look like
it did when I recorded it"; it cannot answer "did the recording do anything",
because a recording that did nothing is perfectly reproducible.

**`check-result.sh`** now *asserts* the two sentinel lines of the typed block
when the editor has written the large file to disk, instead of printing a count.
The old report was:

```text
on disk:  10006248 bytes, 337547 lines
seeded:   10006238 bytes, 337537 lines
```

337547 = 337537 + 10 is exactly the arithmetic a human checks, and it agreed
perfectly — while the ten lines were **empty**, because the Returns had arrived
and the characters had not. The file was ten *bytes* larger, not ten lines.
