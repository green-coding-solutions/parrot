# JupyterLab 4.6.2 in Firefox 153.0.3 — measured landmarks

JupyterLab is the only editor in this group with no window of its own. It is a
server plus a web application, so what is measured is **JupyterLab rendered by
Firefox**, and the row in the block table includes the browser. That is not a
distortion to apologise for — it is what using JupyterLab costs.

| | |
| - | - |
| `WM_CLASS` | `("Navigator", "firefox")`, role `browser` |
| Editor viewport | 39 lines |
| Wheel scroll | **5.6 lines per click** — Firefox scrolls by pixels, not lines |
| Page down | 40 lines |
| Autosave | **yes** |
| Worst RMSE on replay | **0.0037** — the tightest in the group |

The window is pinned on `(name=Navigator) (class=firefox) (role=browser)`.
`("firefox", "Firefox")` is a 10x10 helper Gecko also maps, so the res-name
alone would pin the wrong window.

## The apt pin the rest of the repo uses has rotted

`applications/firefox/install.sh` — used by the `pdf_viewers` group — installs
`firefox=151.0~build2` from `packages.mozilla.org`. That does not resolve any
more:

```text
E: Version '151.0~build2' for 'firefox' was not found
```

Mozilla's apt repository keeps only the last handful of builds; today it starts
at 152.0.5. This install.sh therefore takes Firefox from
`ftp.mozilla.org/pub/firefox/releases/`, which keeps every release forever and
publishes a `SHA256SUMS` next to each one — the same reasoning that makes VS
Code's version-pinned download URL usable where `packages.microsoft.com` is not.

## Two things that shape every block

**Finding does not move the caret.** CodeMirror's search panel highlights every
match, scrolls the first one into view and reports `1/4` — and leaves the cursor
exactly where it was. Escape then scrolls the view *back* to the cursor. So the
"search, Escape, Home, Shift+End" pattern that VS Code, IntelliJ, Sublime,
Eclipse and Android Studio all share does not work here at all: it selects a
line at the top of the file.

Lines are reached instead by scrolling a measured number of wheel clicks and
clicking the line. Sixteen clicks puts line 90 at the top; line 117 is then at
y=642 and line 118 at y=660. That is only reproducible because
`pin-windows.sh` fixes the window at 1440x900 — it is the most
geometry-dependent driver in the group.

**JupyterLab has no "go to line".** Not a keybinding, not a menu item, not a
command-palette entry:

```text
$ grep -roh "codemirror:[a-z-]*" share/jupyter/lab/static/ | sort -u
codemirror:delete-line
codemirror:fold-all
...
codemirror:toggle-comment
codemirror:unfold-all
```

The bundle ships CodeMirror's `gotoLine` code — it appears twice in the
JavaScript — but registers no command for it. `Alt+G`, CodeMirror's own default
binding, does nothing. Searching the command palette for "go to" returns no
results, and the `Ln 1, Col 1` status-bar indicator is not clickable.

### What block 14 does instead, and how to read its number

A click on the scrollbar track, which GTK warps the thumb to, then a click on
the line. `1398,413` is 35.5% down a 700 px track and puts line **119981** at
the top of the view; the second click lands on the 20th row, which is line
**120000** exactly — the status bar confirms `Ln 120000, Col 1`.

So the caret ends up precisely where every other editor's does, and **blocks 15
and 16 are directly comparable**. What is not comparable is block 14's own
number: it measures two mouse clicks against everyone else's typed line number.
Read that cell as "JupyterLab cannot do this step", not as "JupyterLab does this
step in N seconds".

## The steps

| # | Step | Input |
| - | ---- | ----- |
| 1 | Load app | Firefox's *Welcome* → Continue · Jupyter news → No |
| 2 | Open file | File > Open from Path… · `src/price_calculator.py` |
| 3 | Scroll to function | 16 x wheel-down → top line 90 |
| 4 | Find identifier | `Ctrl+F` · `tax_rate` → 1/4, caret unmoved |
| 5 | Select line | click line 117 at y=642 · `Home` (smart, col 5) · `Shift+End` |
| 6 | Duplicate line | `Ctrl+C` · `End` · `Return` · `Ctrl+V` |
| 7 | Undo duplicate | `Ctrl+Z` **x2** |
| 8 | Replace all | `Ctrl+F` · field · `tax_rate` · chevron · field · `vat_rate` · Replace All |
| 9 | Undo replace | `Escape` · `Ctrl+Z` **x1** |
| 10 | Insert comment | `Ctrl+Home` · re-scroll · click line 118 · `Home` · text · `Return` |
| 11 | Save file | `Ctrl+S` |
| 12 | Reopen file | tab ✕ at 704,131 · File > Open from Path… |
| 13 | Open large file | File > Open from Path… · `src/component_library.py` |
| 14 | Go to line | scrollbar click · line click — **see above** |
| 15 | Page down | `Next` x10 → L120000 to L120400 |
| 16 | Go to start | `Ctrl+Home` |
| 17 | Type block | the ten lines, each + `Return` |
| 18 | Global replace | file by file — no project-wide replace exists |

## Smaller things worth knowing

**`Ctrl+F` reaches JupyterLab, not Firefox.** CodeMirror takes the key first, so
the browser's own find bar never appears. `Alt+W` — what the File menu offers
for Close Tab — does **not** work, because Alt is Firefox's menu-bar
accelerator and the browser gets it first; block 12 clicks the tab's ✕ instead.

**The replace row's expanded state is per document.** Each of the three files in
block 18 needs its own chevron click, unlike Eclipse where the row stays open
once toggled. The find field also starts empty in each new document, so there is
no cross-file history to corrupt the replacement — the trap that caught IntelliJ
cannot happen here.

**JupyterLab autosaves.** The ten lines typed into the 10 MB file are on disk at
the end of the run — 337,547 lines against the seeded 337,537 — without the
scenario ever asking for a save. It shares that with Android Studio; Eclipse, VS
Code, Sublime, Vim, Neovim, nano and Emacs all leave the buffer dirty.

**A killed Firefox poisons the next run.** `pkill` rather than a clean exit
leaves a crash flag, and Firefox then reopens with an `about:sessionrestore` tab
in front of JupyterLab — a second tab no reference image has. The recording
rebuilds the container for this reason; it is also why `install.sh` clears
`~/.mozilla` and `~/.cache/mozilla` on every setup pass.
