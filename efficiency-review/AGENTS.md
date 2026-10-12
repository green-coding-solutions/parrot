# Resource-efficiency review of a code base

You are given a software repository. Find the changes that would make it use
less energy, CPU, memory, disk and network **for the same work**. Rank them by
expected effect, and say how each one can be verified.

These rules are not general green-coding folklore. Every one of them comes from
measurements on the Green Metrics Tool cluster:

- 52 desktop applications in eight categories: code editors, word processors,
  spreadsheets, email and chat clients, PDF viewers, terminals and video
  players. Each app was driven through an identical recorded session: 220 whole
  sessions, then 926 individually measured steps.
- A database benchmark of seven engines under five workloads on three
  machines, 12 to 43 runs per cell.
- Nextcloud on PostgreSQL, MariaDB and SQLite, 31 to 78 runs per cell.

The numbers are there for calibration. They show which kinds of change moved
energy by 10x and which moved it by nothing. Use them to rank your findings, and
do not recommend what the evidence says does not matter.

When you recommend something the evidence here does not cover, label it
"not measured" and give your reasoning. Say so plainly; do not claim a factor
you cannot back.

---

## What you deliver

A report in the format at the end of this file, containing:

1. **A profile of the software.** Its runtime, whether it is interactive, a
   server or a batch job, and its **unit of work**: a request, a keystroke, a
   frame, a message, a document, a job. Every claim about efficiency is per unit
   of work.
2. **Findings, ranked by expected effect.** Each one gets `path:line`, the
   mechanism, the rule it falls under, an effect estimate with its basis, a
   confidence level, the concrete change and how to verify it.
3. **What you checked and ruled out,** so nobody checks it again.
4. **The one measurement you would run first** if only one were possible.

Do not modify the repository unless you are asked to. Do not pad the report: if
the code base has two real findings, report two.

---

## How to work

Go in this order. It is the order of expected effect, and the last steps are the
most expensive to act on.

1. **Profile.** Read the README, the build files, the dependency manifests, the
   Dockerfiles and compose files, and the shipped default configuration. Name
   the runtime (JVM, Node/Electron, browser engine, Python, native, etc.), the
   UI toolkit if any, and the unit of work. Find the test suite and any
   benchmarks too: they are usually the quickest workload you can measure (see
   "Use the test suite as the workload").
2. **What runs when nobody is using it?** (Rule 1.) This is where the largest
   and cheapest wins were in every category measured.
3. **What runs per unit of work on the hot path?** (Rules 2 to 4, and Rule 11
   for start-up.)
4. **What does it fetch, write and send that the task does not need?**
   (Rules 5 to 7.)
5. **Memory.** (Rule 8.)
6. **Runtime, dependencies, database.** (Rules 9 and 10.) Last, because these
   are the costliest changes and the evidence says most of them matter less
   than people think, with specific exceptions.
7. **Rank** with the table in "Estimating the effect", then write the report.
8. **Measure** the top findings before and after on the Green Metrics Tool
   cluster, if you have access and the owner agrees. See "Measuring on the
   Green Metrics Tool cluster". Update the report with what the runs showed.

Look at configuration as hard as at code. Half of the defects found in the
measurements were a default setting: a scrollback mode, an autosave, an update
check, a browser flag.

---

## Calibration: what the measurements say

Read this before judging any finding.

- **Energy is CPU time, and almost nothing else.**
  - Added power was 0.16 W + 0.67 W per percent of machine CPU (r = 0.997 over
    220 runs). That is about 11 W per fully busy core.
  - Step by step, every app turned CPU into energy at 10 to 17 J per
    core-second. That includes apps that render OpenGL in software.
  - If you cannot measure energy, **CPU time is an excellent proxy** on
    machines without a discrete GPU.
- **Memory held costs no measurable power.** DRAM energy did not change between
  apps holding 45 MB and 4.7 GB (median difference -0.7 mW).
- **Moving bytes costs the client nothing measurable; processing them does.**
  In chat clients, bytes explained none of the step energy (R² 0.0001). Mail
  clients that downloaded 500 MB paid for it one step later, in indexing, with
  almost no traffic.
- **The biggest hidden driver is work nobody asked for.** Most apps go quiet
  within half a second of the last input. A few keep burning 2 to 30 W while
  left alone, and that burn was most of their energy.
- **Idle burn and per-action cost are separate problems** (rho 0.21, not
  significant). Remove the background load and the idle burners acted as
  cheaply as their frugal neighbours. The background is usually the easier fix.
- **Slow and hungry go together.** Apps that were slower to respond used more
  energy (within-category rho 0.44). A latency problem is often an energy
  problem too.
- **All of this was measured on machines without a discrete GPU.** Everything
  that draws with OpenGL did so on the CPU. On hardware with a GPU, rendering
  moves off the CPU and Rule 4 applies with smaller factors. Say so when the
  target hardware differs.

---

## The rules

Each rule gives what was measured, what to look for, what to recommend, and
what not to do.

### Rule 1. Nothing runs while nobody is using the software

**Evidence.**

- Eclipse used a full core from its first second, in every quiet moment.
- Two other Java IDEs drew 15 to 18 W while left alone, about as much as while
  in use, once a trigger had switched their background work on (Rule 2). An
  older release of the same IDE platform drew 0.3 W.
- A video player drew 2.7 W while paused.
- An office suite drew 2.3 W while idle. It is a build of the same engine as
  another suite that drew nothing, and it used 28x the energy over a session.
- A chat client used 41 % of the machine (27 W for two minutes) on its welcome
  and sign-in screens, then nothing once signed in. That is a render loop on a
  static screen.
- Another chat client held CPU for exactly 10 s after every input, most likely
  a cursor-blink timer.
- Against that, 33 of 52 apps returned to rest after use, with a median
  calm-down under half a second.

**Look for.**

- Periodic timers, and loops that sleep and poll instead of waiting for an
  event.
- Animations, spinners and render loops that keep running when the content is
  static, the window is hidden or playback is paused.
- File watchers over large trees, and polling of files, sockets, HTTP
  endpoints or database tables.
- Background indexers, analysers and sync jobs with no finish condition.
- Heartbeats and health checks at short intervals.
- Busy-waits and spin locks.
- Idle callbacks that reschedule themselves unconditionally.

**Recommend.**

- Wake on events, not on timers.
- Stop animating when nothing changes. Pause work when the window is hidden,
  minimised or the media is paused.
- Back off polling intervals exponentially.
- Coalesce timers.
- Give every background job an end.

**Estimate.** One busy core costs about 11 W. A timer firing N times a second
and doing t ms of work each time adds about N x t / 1000 core-seconds per
second. The cost of the wake-ups themselves is not measured here.

### Rule 2. Work triggered by input size must end, and must scale sanely

**Evidence.**

- Two JetBrains IDEs ran within about 3 W of a lighter sibling until the
  session opened a 10 MB source file. From then on they drew 27 to 31 W (35 %
  of the machine) through every later step, including an 86-second pause. The
  sibling fell back to about 1 W.
- Eclipse grew from 1.0 to 9.8 GB, 3.7 GB of it while opening that one 10 MB
  file (367x the file's size).

**Look for.**

- Analysis, highlighting, indexing or linting run on open with no size
  threshold.
- Whole-document re-analysis on every edit.
- Work that is not cancelled when its input changes.
- Unbounded queues.
- Algorithms that are superlinear in document size on the edit path.

**Recommend.**

- A size threshold that switches to a lighter mode.
- Incremental algorithms.
- Debouncing.
- Cancelling outdated work.
- A test that opens a large input and asserts that CPU returns to rest.

### Rule 3. Price the hot path per unit of work

**Evidence.** Cost per unit of work, cheapest against dearest app in the same
category:

| Unit | Cheapest | Dearest | Factor |
| --- | --- | --- | --- |
| Keystroke, code editor | 0.20 J | 9.1 J | 45x |
| Keystroke, word processor | 0.17 J | 2.4 J | 14x |
| Incoming chat message | 1.9 J | 8.5 J | 4.5x |
| Megabyte of terminal output, fast-scrolled | 1.5 J | 25 J | 16x |
| Video frame, H.264 | 0.13 J | 0.92 J | 7x |
| PDF page turned forward | 0.47 J | 2.5 J | 5.4x |

Even after removing the IDEs' background, their marginal cost per keystroke was
still 3 to 5 times the lightest editor's.

Everyday steps (typing, scrolling) separated apps as much as heavy steps
(loading, syncing, saving); the difference was not significant (p = 0.73).

**Look for.** Everything that runs per keystroke, per event, per message and
per request:

- a full re-render or re-layout;
- a re-parse;
- synchronous storage writes;
- logging, telemetry or notifications per event;
- recomputing derived state from scratch.

**Recommend.**

- Incremental updates.
- Batching.
- Throttling or debouncing to the rate a human can perceive.
- Moving non-urgent work off the per-event path.

### Rule 4. Presenting costs more than computing: draw only what changed

**Evidence.**

- **Video.** The choice of player changed the cost of playing the same clip by
  up to 7x (1.6 W against 11.3 W). The codec changed it by at most 1.35x.
  Doubling the frame rate cost 1.3 to 1.5x.
- **Upscaling.** A clip with a fifth of the pixels, upscaled to the same
  window, saved only 10 to 38 %. Most of the work was putting frames on the
  screen, not decoding them.
- **Front ends.** A front end that runs a player as a child process was cheaper
  than the same player alone (1.5 W against 2.9 W).
- **Terminals.** The rendering path decided the cost, not the size of the
  software stack. A terminal with 14 dependency packages added 1.5 W, one with
  158 added 3.6 W, and one with 321 added 1.8 W.

**Look for.**

- Full-window redraws for small changes.
- A redraw per line of output instead of one per frame.
- No frame-rate cap.
- Redrawing unchanged content, or content in hidden widgets.
- Progress indicators updated faster than the eye can follow.
- Output paths that bypass damage tracking.

**Recommend.**

- Damage tracking and partial updates.
- Coalescing updates to at most the display rate, and lower for text.
- Skipping frames when nothing changed or nothing is visible.

**Do not** recommend a codec or format change before the rendering path has
been looked at.

### Rule 5. Do not fetch and process what the user may never look at

**Evidence.**

- **Eager mail clients.** Two mail clients downloaded the whole 501 MiB mailbox
  at start and then indexed it: 1.1 to 1.7 kJ in one step.
- **Lazy mail clients.** Five others fetched headers only, 0.2 to 1.3 % of the
  mailbox.
- **The trade-off.** Over the session the eager strategy cost 2.6 kJ against
  1.5 kJ. The lazy client paid per action instead: emptying the trash cost
  170 J against 6 to 8 J. Lazy wins unless the user touches most of the data.
- **Where the work runs.** Servers accounted for only 1 to 13 % of the CPU a
  session added; the client did the work. Server-side search cost the mail
  server about 1.4 core-seconds. The other clients mirrored and searched
  locally, having paid for the mirror up front.
- **Redundant fetches.**
  - One chat client loaded only the three thumbnails on screen.
  - Three fetched an image back straight after uploading it.
  - One mail client fetched a PDF attachment twice.
- **Servers pay per request, not per byte.** A chat server spent 2 to 7
  core-seconds on one sign-in that moved 1 MB, and 0.2 core-seconds serving
  18 MB of photos. The mail server's cost did scale with bytes, but at only
  about 0.04 J per MB.

**Look for.**

- A full sync or prefetch at start.
- Local full-text indexes of remote data.
- Full-size media where thumbnails would do.
- Re-downloading what was just uploaded.
- Duplicate fetches of the same resource.
- Unpaginated list endpoints.
- Chatty protocols: many small requests where one would do, and full
  re-syncs where an incremental one would do.

**Recommend.**

- Fetching on demand, with pagination.
- Server-side search where the server already has an index.
- Keeping a local copy of what was uploaded.
- Request deduplication and caching.
- Fewer, batched requests, and incremental sync.

### Rule 6. No disk writes that nobody asked for

**Evidence.** In sessions where nobody saved anything:

- A terminal wrote 2.2 GB of scrollback in 15 steps. Its profile selected
  unlimited, file-backed history; the other terminals kept 20,000 lines in
  memory.
- Two Electron mail clients wrote heavily; one wrote 2.1 GB while starting. Both
  run Chromium with `--disable-dev-shm-usage`, which moves shared memory to
  disk.
- A browser used as a PDF viewer wrote 609 MB, apparently staging an update.
- An office suite wrote 9.2 MB on every edit step, an autosave of the whole
  document.
- One word processor wrote 290 MB to export a 98-page PDF; the others wrote 4
  to 12 MB.
- A save wrote 1.1x to 3.4x the file's size, depending on the app.

Disk writes went with energy (within-category rho 0.47 to 0.50).

**Look for.**

- Unbounded logs and histories.
- Debug-level logging by default.
- Whole-file autosave on every change.
- Temporary files in export pipelines.
- Write-copy-rename-backup sequences that write a file several times.
- `fsync` after each small write.
- Flags that move memory to disk.

**Recommend.**

- Bounded ring buffers.
- Autosave on an interval, and only when something changed.
- Streaming export.
- Writing once.
- Production log levels as the default.

### Rule 7. No network traffic the task does not need

**Evidence.**

- A browser downloaded 134 MB while displaying a local PDF. It was the vendor
  build with no policy file, so update or remote-settings downloads are the
  likely cause.
- An office suite downloaded 12.5 MB at start-up although its update check had
  been switched off.
- Two IDEs exchanged about 75 kB.

That traffic, and the CPU behind it, was inside their measurements.

**Look for.**

- Update checks, telemetry, crash reporting and remote configuration.
- Feature-flag fetches.
- Assets or fonts downloaded at start.
- An "off" switch that does not cover every path.

**Recommend.**

- Opt-in, or off by default in managed, container and CI deployments.
- One switch that really disables everything.
- A test that runs offline and fails on unexpected connections.

### Rule 8. Hold what you use, give back what you are done with, and do not sell memory as energy

**Evidence.**

- **Memory held did not cost power** (see Calibration), yet it was the best
  single predictor of energy within a category. It explained 70 % of the
  differences between apps, each predicted from a fit that left it out.
  Memory measures how much machinery is running.
- **Transient UI gave its memory back.** After a composer, search results or an
  image viewer closed, 70 to 99 % of the growth was released.
- **Loaded content kept it.** Only 1 to 5 % came back.
- **Memory per MB of the opened file:**
  - 1.0 to 1.3 in the lean editors;
  - 4 to 17 in the IDEs and VS Code;
  - 367 in Eclipse;
  - for a 9 MB document, 4 in one office suite and 58 in another.
- **Repeats and caching.** Reopening the same file cost one editor 3 % of the
  first opening. It cost Eclipse 129 %, plus another 791 MB.
- **Managed runtimes** reserve a large heap up front and stay flat. Native apps
  that cache what they render keep growing, up to 2.75x over a session.

**Look for.**

- Caches with no bound.
- Documents held at many times their size.
- Duplicate in-memory copies.
- Caches that do not make a repeat cheaper.

**Recommend.** Bounds, eviction and sharing. Frame the benefit as footprint,
density and avoiding swap. The energy saving comes from removing the machinery
the memory stands for, not from the bytes.

**Do not** estimate an energy saving from a memory reduction alone.

### Rule 9. Judge a runtime by what it does at rest, not by its reputation

**Evidence.** Each app compared with the other apps of its own category:

| Property | Energy against the category | Verdict |
| --- | --- | --- |
| JVM desktop IDE | 19x | all of it idle burn (Rule 1) |
| Browser engine (Gecko) used as an app | 2.9x | a browser as PDF viewer drew 3.9 W against 0.3 to 1.0 W for native viewers |
| Plain X11 or terminal UI | 0.25x | frugal |
| Electron | 0.9x | **no penalty** |
| Qt against GTK | 0.98x | **a tie**; the sign flips by category |
| Built on a desktop platform (KDE, GNOME) | 0.96x | no effect |
| Proprietary against open source | 1.08x | no effect |
| Ships helper services (a database server, a sync daemon) | 0.57x | no effect; the services sleep |
| Number of packages pulled in | rho -0.10 | no effect |
| Install download size | rho 0.55 | real, and holds among native apps alone |
| Vendor build against distro package | 4.8x | through the runtimes they bundle; 2.5x and not significant among native apps |

Two builds of the same engine differed by up to 28x. The cause was almost
always idle behaviour or a rendering choice, not the engine.

Two more observations:

- Managed runtimes had 1.4x higher power peaks than native apps in the same
  category. That matters for capacity planning and power capping, not for
  energy.
- An app's resource profile (CPU per kJ, memory growth, peakiness,
  background share) followed its category, not its runtime family.

**Recommend.** Flag bundling a second heavy runtime to do a small job, such as
an embedded browser engine for one view. Then apply Rules 1 to 4 to whatever
runtime is in use.

**Do not** recommend any of these for energy:

- rewriting away from Electron;
- swapping Qt and GTK;
- dropping desktop integration;
- trimming the package count;
- removing helper daemons.

The data says none of them matter.

### Rule 10. The database engine matters where the database is the work

**Evidence, database-bound.** Seven engines under HammerDB and BenchBase-style
workloads. Every engine got the same container limits (4 CPUs, 8 GB) and the
same tuning tier. Energy above idle per operation:

| Workload | MySQL against PostgreSQL | MariaDB against PostgreSQL |
| --- | --- | --- |
| TPC-C | 2.6x to 3.3x | 1.7x to 1.9x |
| CH-benCHmark (mixed) | 2.7x to 3.0x | 0.9x |
| YCSB | 1.7x | 0.95x to 1.0x |
| Wikipedia | 1.6x | 1.1x |
| TPC-H (small scale) | 1.3x to 1.5x | 1.6x to 1.8x |

- **PostgreSQL beat MySQL in every workload, on every machine,** in both
  tuning tiers tried, a basic and an extended one. No engine was run with its
  defaults.
- **The power drawn was about the same; the work done was not.** In TPC-C,
  MySQL drew 32.5 W against PostgreSQL's 31.9 W and completed a third of the
  transactions.
- **MariaDB** was level with PostgreSQL on three workloads.
- **For analytics (TPC-H),** SQL Server and Oracle needed about half the energy
  per query of PostgreSQL.

**Evidence, not database-bound.** Nextcloud ran the same browser scenarios
against three backends:

- **During use,** PostgreSQL, MariaDB and SQLite were within 0.99x to 1.09x of
  each other.
- **Only schema creation at install differed:** PostgreSQL cost 1.2x to 1.4x
  MariaDB, SQLite 0.7x to 0.8x.

**Recommend.**

- **MySQL to PostgreSQL** (or to MariaDB where MySQL compatibility matters)
  when the database is a large share of the system's CPU: DB-bound services,
  batch jobs, reporting.
- **Show that share first,** from the code (query volume per request, heavy
  queries, batch jobs) or from a measurement.
- **Where the database is mostly idle,** a switch costs a migration and saves
  nothing measurable. Look at what the application asks the database to do
  instead.
- **For single-user or embedded use,** SQLite needs no server running.

### Rule 11. Start-up is a unit of work too

**Evidence.**

- One video player's start alone cost 1.0 kJ, a fifth of its whole session.
- A browser used as a PDF viewer spent 100 to 150 J each on starting, opening
  the file and jumping to a page. Native viewers spent 1 to 20 J.
- One IDE's start cost 829 J more than another's, although it was the cheaper
  of the two over the session.
- While starting, one mail client wrote 2.1 GB to disk and two IDEs wrote 348
  to 462 MB.
- Start-up memory was mostly heap, not the program's own files. Memory growth
  at launch was a median 0.52x the installed size, and above 1x in 18 of 52
  apps.

**Look for.**

- Eager initialisation of every module or plugin.
- Indexing, cache warming, migrations or schema checks on every start.
- Update checks and remote configuration fetched before the first
  interaction.
- Splash animations.

**Recommend.**

- Lazy initialisation.
- Deferring non-essential work until after the first interaction, or until the
  software is idle.
- Caching the results of start-up work across runs.

This matters most for short-lived processes, where start-up is most of the run:
CLI tools, serverless functions, containers started per job, one process per
request.

---

## Things that did not predict energy

Do not put these in a report as energy findings. They may still matter for
maintenance, security or footprint; say so if you mention them.

- The UI toolkit (Qt, GTK).
- Electron as such.
- The license.
- Desktop-environment integration.
- How many packages or libraries the dependency tree has, or how deep it is.
  Only the bytes installed showed a weak effect.
- Helper services that start, do their work and sleep.
- How new the project is.
- Memory size on its own (Rule 8).
- The video codec, compared with the renderer (Rule 4).

---

## Estimating the effect

Rank findings with this table, then adjust by how often the code path runs.

| Kind of change | Largest effect measured |
| --- | --- |
| Stop continuous background work (Rules 1, 2) | 19x a category's session energy; 28x between builds of one engine; +26 W sustained |
| Cheaper hot path per unit of work (Rule 3) | 4x to 45x per unit |
| Cheaper rendering path (Rule 4) | up to 7x per frame |
| Lazy data strategy (Rule 5) | 1.7x per session, and 500 MB less traffic |
| Cheaper start-up (Rule 11) | a fifth of a session; 100 to 150 J against 1 to 20 J per open |
| Database engine, DB-bound (Rule 10) | 1.3x to 3.3x per operation |
| Database engine, not DB-bound (Rule 10) | nothing measurable (1.09x at most) |
| Unneeded writes (Rule 6) | gigabytes per session; energy rho about 0.5 |
| Unneeded traffic (Rule 7) | up to 134 MB per session |
| Memory footprint (Rule 8) | no direct energy effect |
| Toolkit, Electron, license, package count | none |

**Conversions.** On a six-core server-class machine with no GPU:

- one fully busy core is about 11 W at the wall;
- a core-second is 10 to 17 J;
- one percent of the whole machine's CPU is about 0.67 W.

Scale these to the target hardware, and state that you did.

**Where the difference sits depends on the workload.** Use this to decide
which code paths to read first:

| Kind of software | Where most of the difference between apps was |
| --- | --- |
| Mail and chat clients | start-up and sync (72 to 75 %) |
| Office applications | everyday edits (71 to 72 %) |
| Terminals | rendering output (96 %) |
| Video players | playback |

**Servers and batch jobs.** Energy per operation follows throughput. Engines
that drew the same power did three times more or less work. A change that
raises throughput at equal power is an efficiency gain. For interactive
software, idle and background behaviour dominate instead.

---

## Verifying a recommendation

Give every finding a way to check it. These rules exist because each was broken
once and produced a confident, wrong number. The Green Metrics Tool's
[best practices](https://docs.green-coding.io/docs/measuring/best-practices/)
cover the same ground from the tool's side.

1. **Measure per unit of work.** A timed benchmark that reports only energy
   rewards the system that does less work.
2. **Subtract the run's own idle, and check that idle really is idle.**
   - The test machine's idle draw ranged from 20.4 to 22.3 W across runs, in
     step with temperature (0.48 W per degree), so raw totals from different
     days do not compare. Subtracting each run's own quiet phase made replicate
     runs agree 8 times more closely.
   - A database still initialising during the "idle" phase inflated it by
     11.5 W and made that backend look 1.8x to 4x cheaper than it was.
   - A warming-up chat server added 1.6 to 2.2 W.
   - When a server is involved, subtract a phase recorded before any container
     starts.
3. **Compare on the same machine.** Rankings transferred between machines (rank
   correlation 0.89); absolute numbers did not (36 % lower on the second
   machine).
4. **Know the noise before calling a difference.**
   - Run replicates.
   - Per step, the same app differed by 0.34 W at the 90th percentile.
   - Per session, the smallest resolvable difference was 0.11 to 0.71 W,
     depending on the category.
5. **Keep instrumentation out of the result, or subtract it.** One screenshot
   check cost 5.1 J, which was 45 to 82 % of the measured energy of the eleven
   lightest apps. Per-container energy attribution read 1.7x to 2.7x too high
   for the lightest apps, because it charged them a share of the idle machine.
6. **Measured phases must last equally long** when comparing timed phases. Idle
   power is drawn for as long as a phase is open, so length alone moves energy.
7. **Report every resource.** Only in one category of eight was the energy
   winner also lightest on CPU, memory, disk and network together. Within a
   category, energy tracked CPU (rho 0.98) but only loosely tracked memory
   (0.50), disk writes (0.47) and network (0.37).
8. **Check that the optimised version still does the work.** A cheaper result
   can mean work that silently did not happen. Examples: a video player
   suspiciously cheap in playback, a step that passed its checks while the
   action it measured never took place. Verify the output, not only the cost.
9. **Measure the scenario users actually run,** not only start-up. Peaks came
   in actions, not at launch.
10. **Compare per step, not only per session.** A session total can hide a step
    that got worse. One IDE was cheaper than another over the session and 829 J
    dearer at start. One terminal beat another overall and cost 107 J more on
    fast scrolling.
11. **Disk writes are the noisiest resource.** Replicates differed by 35 % at
    the median, and writeback can land up to 30 s later, in the next phase.
    Compare disk writes over several phases or the whole run.
12. **Container memory includes the page cache.** Reading or writing a file
    raises it, so a memory figure is not a heap size.
13. **CPU-package energy (RAPL) is a good stand-in for wall power.** It tracked
    the added wall power with r = 0.9996 and covered 79 % of it; the rest was
    power-supply loss that scaled with it. RAPL-only figures rank correctly;
    divide by about 0.79 to estimate wall power.

To measure, use the Green Metrics Tool cluster (next section). Without it, CPU
time from cgroup statistics, `perf stat` or `/usr/bin/time` is a good proxy
(see Calibration). Never report proxy numbers as energy.

---

## Measuring on the Green Metrics Tool cluster

The Green Metrics Tool (GMT) runs a `usage_scenario.yml` from a Git repository
on a dedicated measurement machine. It records energy, CPU, memory, disk and
network for every phase. Use it to check that an optimisation saves what you
claim.

The workflow:

1. Write a scenario.
2. Push a baseline and a change.
3. Submit both several times on one machine.
4. Wait for the runs.
5. Check that the runs did the work.
6. Compare.

**Documentation.** The Green Metrics Tool is documented at
<https://docs.green-coding.io>. Where the documentation, or the live API
reference, disagrees with this file, they win; they are kept current.

| Topic | Pages |
| --- | --- |
| How a measurement works | [Measurement process](https://docs.green-coding.io/docs/prologue/measurement-process/), [Measurement phases](https://docs.green-coding.io/docs/prologue/measurement-phases/) |
| Writing the scenario | [usage_scenario.yml](https://docs.green-coding.io/docs/measuring/usage-scenario/), [Variables](https://docs.green-coding.io/docs/measuring/usage-scenario/#variables), [Custom metrics](https://docs.green-coding.io/docs/measuring/usage-scenario/#custom-metrics) and their format under [SCI](https://docs.green-coding.io/docs/measuring/carbon/sci/), [Notes](https://docs.green-coding.io/docs/measuring/usage-scenario/#read-notes-stdout-format-specification) |
| Getting software into containers | [Containerizing applications](https://docs.green-coding.io/docs/measuring/containerizing-applications/), [Interacting with applications](https://docs.green-coding.io/docs/measuring/interacting-with-applications/), [Resource limits](https://docs.green-coding.io/docs/measuring/resource-limits/) |
| Special kinds of software | [GUI applications](https://docs.green-coding.io/docs/measuring/measuring-gui-applications/), [Websites](https://docs.green-coding.io/docs/measuring/measuring-websites/), [AI/ML applications](https://docs.green-coding.io/docs/measuring/measuring-ai-ml-applications/) |
| Running GMT locally | [Installation](https://docs.green-coding.io/docs/installation/), [Measuring locally](https://docs.green-coding.io/docs/measuring/measuring-locally/), [runner.py switches](https://docs.green-coding.io/docs/measuring/runner-switches/), [Debugging](https://docs.green-coding.io/docs/measuring/debugging/) |
| The hosted cluster | [Hosted service](https://docs.green-coding.io/docs/measuring/measuring-service/), [Measurement cluster](https://docs.green-coding.io/docs/measuring/measurement-cluster/), [Cluster status](https://metrics.green-coding.io/cluster-status.html), [Private repositories](https://docs.green-coding.io/docs/cluster/private-repositories/) |
| Reading the metrics | [Metric providers](https://docs.green-coding.io/docs/measuring/metric-providers/metric-providers-overview/), [Units](https://docs.green-coding.io/docs/general-info/units-and-dimensions/), [Overhead of the providers](https://docs.green-coding.io/docs/measuring/metric-providers/overhead-of-measurement-providers/) |
| Comparing runs | [Comparing measurements](https://docs.green-coding.io/docs/measuring/comparing-measurements/), [Statistical significance](https://docs.green-coding.io/docs/measuring/comparing-measurements/#statistical-significance) |
| Measuring well | [Best practices](https://docs.green-coding.io/docs/measuring/best-practices/) |
| The API | [API overview](https://docs.green-coding.io/docs/api/overview/), [live API reference](https://api.green-coding.io/docs) |
| When something fails | [Troubleshooting](https://docs.green-coding.io/docs/help/troubleshooting/), [FAQ](https://docs.green-coding.io/docs/help/faq/) |

### Before you start

- **A token is optional.**
  - **Without one** you submit as the public default user. That user may use
    only machine 7, only the `one-off` schedule mode and no `docker-run-args`,
    and a run may take at most 3,600 s. Its runs are visible to anyone, so
    submit only code that may be public.
  - **With one,** the machines, schedule modes and allowed arguments are
    whatever that user was granted. Read the token from `GMT_AUTH_TOKEN` or
    `~/.gmt/token`, and send it as the `X-Authentication` header. Never print,
    log or commit it.
- **The API** is at `https://api.green-coding.io`, with a live reference at
  <https://api.green-coding.io/docs>.
  - Responses are JSON: `{"success": true, "data": ...}`.
  - An empty result is HTTP 204 with no body.
- **The cluster clones from the Git remote, not from your working tree.**
  - Everything the scenario needs must be pushed: the branch, the scenario file
    and any image it uses.
  - **Ask the repository owner before you push anything.**
  - Push to a branch of your own, never to the default branch.
- **Cluster time is shared.** Submit only what the owner agreed to.
  - Use only the `one-off`, `variance` and `statistical-significance` schedule
    modes.
  - The others (`daily`, `weekly`, `commit`, `tag` and their variants) create a
    watch-list entry that keeps submitting runs after you are gone.

### 1. Write the scenario

A `usage_scenario.yml` is a Docker Compose file plus a `flow`. Each flow step
becomes a **phase** of its own and is measured separately. GMT adds phases of
its own:

| Phase | What runs |
| --- | --- |
| `[BASELINE]` | the machine with no containers |
| `[INSTALLATION]` | image pulls and builds |
| `[BOOT]` | containers starting |
| `[IDLE]` | containers up, flow not started |
| `[RUNTIME]` | the whole flow |
| `[REMOVE]` | teardown |

A skeleton for a service under load. Adapt it; do not copy it blindly:

```yaml
name: myapp efficiency check
author: <your name or agent id>
description: A load generator drives myapp; one phase per kind of work, plus an idle phase

custom_metrics:
  ops:
    unit: request          # stored as custom_ops, summed per phase

services:
  app:
    image: ghcr.io/org/myapp@sha256:<digest>   # pinned and pushed, or use build:
    cpus: 4
    mem_limit: 4g
    healthcheck:
      test: ["CMD-SHELL", "curl -fs http://localhost:8080/health"]
      interval: 5s
      retries: 30
  load:
    image: <load generator image>@sha256:<digest>
    depends_on:
      app:
        condition: service_healthy

flow:
  - name: Warm up
    container: load
    commands:
      - type: console
        command: <a short run of the workload>
  - name: Idle with app running
    container: load
    commands:
      - type: console
        command: sleep 60
  - name: Run workload
    container: load
    commands:
      - type: console
        shell: bash
        log-stdout: true
        note: measured workload
        command: n=$(<run the workload, print only the number of completed requests>); echo "$(date +%s%6N) ops=$n"
  - name: Verify output
    container: load
    commands:
      - type: console
        shell: bash
        command: <check the work really happened; exit non-zero if not>
```

Rules for the scenario:

- **One kind of work per phase, and count it.**
  - Either give each phase a fixed amount of work, or a fixed duration plus a
    work counter.
  - The counter is a stdout line `<Unix time in microseconds> <key>=<integer>`
    for a key declared under `custom_metrics`. Set `log-stdout: true` on that
    command. The time must fall inside the phase.
  - GNU `date +%s%6N` prints that time. Busybox has no `%N`; use
    `$(date +%s)000000`.
- **Give idle its own phase** when a finding is about idle burn: a step that
  only sleeps while the software is up.
- **Make `[IDLE]` idle.** Wait for readiness with a healthcheck and
  `depends_on` with `condition: service_healthy`. Put warm-up work in a flow
  step before the measured ones. Then check `[IDLE]` against `[BASELINE]` in
  the results.
- **Before and after differ only in the change under test.** Same scenario
  file, same images except the one rebuilt, same resource limits, same data,
  same variables. Pin image digests and dependency versions.
- **Phases that end on a clock must last equally long** on both sides.
- **Check inside the scenario that the work happened.** End with a flow step
  that verifies the output (a count, a checksum, a query) and fails the run
  otherwise. A cheaper run that did less work is the most common false win.
- **Keep instrumentation out of the measured phases,** or identical on both
  sides.
- **Flow step names** may contain only letters, digits, spaces and `. _ ( ) -`.
- **Commands get no shell** unless they carry `shell: bash`. Without it, quotes
  are passed through as literal characters, and `*`, `$VAR` and pipes are not
  interpreted.
- **Variables.** Every `__GMT_VAR_<NAME>__` placeholder in the file must get a
  value at submission, or the run fails before it starts. Name secrets
  `__GMT_VAR_SECRET_<NAME>__`; they are stored encrypted.
- **`docker-run-args`** entries must be on the submitting user's allow list.
  Otherwise the run fails during `[BOOT]` with almost no output. Avoid them
  unless needed.
- **Nothing local-only.** Images are pulled from a registry or built from the
  repository with `build:`. An image that exists only on your machine fails
  the run.
- **The repository is mounted read-only** at `/tmp/repo` in every container
  (`folder-destination` changes the path). Anything that writes into the
  source tree has to work on a copy.
- **Setup steps can be hidden** with `hidden: true` on the flow step. They
  still run inside `[RUNTIME]`, so compare the measured phases, not
  `[RUNTIME]`.
- **GUI applications** need their input recorded and replayed. See
  [Measuring GUI applications](https://docs.green-coding.io/docs/measuring/measuring-gui-applications/).

### Use the test suite as the workload

The project's own tests are often the quickest way to a measurable workload:

- they already exercise the code paths that matter;
- they already run with one command, usually in a CI image;
- they are the same on both sides of a change.

Tests are also the natural way to watch energy over time. The same test
scenario, run on every commit, shows which change made the software dearer.

How to package them:

- **Build the image the tests run in,** with `build:` from the repository's own
  Dockerfile, or use the CI image pinned by digest.
- **Work on a copy of the repository.** Test runners write caches and build
  output, and `/tmp/repo` is read-only. Copy it in a hidden flow step, or build
  it into the image.
- **Keep building out of the measured phases.** Compiling, installing
  dependencies and creating fixtures belong in a hidden step or in the image.
  Otherwise the measurement is mostly the build.
- **One phase per suite** (unit, integration, benchmarks), so a regression
  shows where it lives.
- **Count the tests run.** Emit the count as a custom metric, and fail the run
  when it differs from the expected number. A side that ran fewer tests is not
  cheaper.
- **Make the run deterministic.** Use a fixed number of workers, a fixed seed
  and order, no network, no retries and no flaky tests.
- **Prefer benchmark tests** (pytest-benchmark, JMH, `go test -bench`,
  `cargo bench`, criterion, hyperfine). They repeat one hot path many times,
  which is exactly what Rule 3 asks about. Fix their iteration count rather than
  their duration, or count the iterations.
- **Know what tests cannot see.**
  - They exit when done, so they miss idle burn (Rule 1). Add a phase that
    starts the software and leaves it alone.
  - They often mock the database and the network, so they miss Rules 5, 7
    and 10. Measure those with a scenario that uses the real thing.

```yaml
name: myapp test suites
author: <your name or agent id>
description: The project's own test suites, one phase each, with the number of tests counted

custom_metrics:
  tests:
    unit: test

services:
  tests:
    image: myapp-tests
    build:
      context: .
      dockerfile: ci/Dockerfile      # the image CI runs the tests in
    cpus: 4
    mem_limit: 4g
    command: sleep infinity           # keep the container up; the flow does the work

flow:
  - name: Prepare
    container: tests
    hidden: true
    commands:
      - type: console
        shell: bash
        command: cp -a /tmp/repo /work && cd /work && <install, build, warm caches>
  - name: Unit tests
    container: tests
    commands:
      - type: console
        shell: bash
        log-stdout: true
        command: cd /work && n=$(<run the unit tests with fixed workers and seed; print only the number run>) && echo "$(date +%s%6N) tests=$n"
  - name: Benchmarks
    container: tests
    commands:
      - type: console
        shell: bash
        log-stdout: true
        command: cd /work && <run the benchmarks with a fixed iteration count>
```

**Watching energy over time.** Both of these need the owner's agreement:

- **On the cluster,** the `commit` and `tag` schedule modes rerun the scenario
  on every new commit or tag. That needs a token that grants those modes.
- **In CI,** [Eco CI](https://github.com/green-coding-solutions/eco-ci-energy-estimation)
  adds an energy figure to every CI job on GitHub, GitLab or Jenkins. Results
  appear on the [CI dashboard](https://metrics.green-coding.io/ci-index.html).
  Eco CI estimates energy from CPU utilisation and a power model of the runner,
  so it shows trends, not measured values. Confirm a trend on the cluster
  before reporting it as a saving.

### 2. Smoke-test locally (optional)

If GMT is installed locally
([installation](https://docs.green-coding.io/docs/installation/),
[measuring locally](https://docs.green-coding.io/docs/measuring/measuring-locally/)),
prove the scenario runs before spending cluster time. The flags are explained
under [runner.py switches](https://docs.green-coding.io/docs/measuring/runner-switches/),
and failures under [Debugging](https://docs.green-coding.io/docs/measuring/debugging/).

```bash
python3 runner.py --uri /path/to/repo --filename usage_scenario.yml \
  --dev-no-save --dev-no-sleeps
```

`--dev-no-save` skips the metric providers and the database. Success is this
line:

```text
Run finished | --dev-no-save was active and nothing was written to DB
```

Do not judge by the exit code: GMT exits 0 even when a flow step failed. Never
report numbers from a local run.

### 3. Choose a machine

`GET /v1/machines` lists the machines. Pick one and run **every** before and
after run on it; numbers from different machines do not compare. A machine that
is available but powered off is woken up automatically.

The [Measurement cluster](https://docs.green-coding.io/docs/measuring/measurement-cluster/)
page describes each machine. The [cluster status](https://metrics.green-coding.io/cluster-status.html)
page shows its queue and full configuration. As of 2026-09-30:

| id | Machine | Notes |
| --- | --- | --- |
| 7 | CO2 Profiling, Esprimo P956, Intel i5-6500 | An off-the-shelf Ubuntu with default settings; wall-power meter. **The only machine available without a token.** |
| 14 | CO2 Benchmarking 2.0, TX1330 M2 | Tuned for reproducibility; wall-power meter. |
| 6 | Micro Benchmarking, TX1330 M2 | Tuned for reproducibility, 2 ms sampling. **No wall-power meter:** only RAPL (CPU package and DRAM) and per-container network. No per-container CPU, memory or disk. |
| 13 | High Performance Benchmarking, TX1330 M4 | Suggested for servers, databases and batch jobs. |
| 11 | ML/AI Benchmarking, GTX 1080 | GPU work. |
| 12 | GUI Benchmarking, TX1330 M3 | Desktop software on X11 or Wayland, with a monitor attached. |
| 15 | GUI High Performance Benchmarking, TX1330 M4, Xeon E-2176G | Desktop software in a virtual X server. The source of most numbers in this file. |

Every machine except 7 is marked PREMIUM and needs a token that grants it.

### 4. Submit

`POST /v1/runs/add` queues runs and returns their job IDs with HTTP 202:

```bash
curl -s -X POST https://api.green-coding.io/v1/runs/add \
  -H "X-Authentication: $GMT_AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "myapp baseline, usage_scenario.yml",
    "repo_url": "https://github.com/org/myapp",
    "branch": "main",
    "commit_hash": "<full SHA of the baseline>",
    "filename": "usage_scenario.yml",
    "machine_id": 13,
    "schedule_mode": "one-off",
    "usage_scenario_variables": {}
  }'
# {"success": true, "data": [123456]}
```

Without a token, leave out the `X-Authentication` header and use
`"machine_id": 7`.

| Field | Notes |
| --- | --- |
| `name` | Free text, shown in the dashboard. Say which side (baseline or change) and which variables. |
| `repo_url` | **Without `.git`.** Runs are grouped by exact URL, so the two spellings never meet. |
| `branch`, `filename` | Required. `filename` is relative to the repository root. |
| `commit_hash` | Optional. Pins the exact commit, so each side measures exactly the code you mean. |
| `schedule_mode` | `one-off` is 1 run, `variance` 3, `statistical-significance` 10. Which modes you may use depends on the user; without a token, only `one-off`. |
| `usage_scenario_variables` | `{"__GMT_VAR_NAME__": "value"}`. |
| `email` | Optional; mail on completion. |

**Replicates and order.**

- Run at least three per side.
- Submit them one at a time and alternately (baseline, change, baseline,
  change, ...), not all baseline runs first. That way slow drift in the
  machine's idle power hits both sides alike.
- To withdraw a job that has not started, send `PUT /v1/job` with
  `{"job_id": <id>, "action": "cancel"}`.

### 5. Wait

`GET /v2/jobs?job_id=<id>` returns one row per job:

```text
[job_id, run_id, name, url, filename, variables, branch, machine, state, updated_at, created_at, categories]
```

- `state` goes from `WAITING` to `RUNNING`, then to `FINISHED` or `FAILED`
  (or `CANCELLED`).
- `run_id` is filled once the run exists.
- The queue can take hours. Poll every ten minutes or so, and never resubmit a
  job that is still waiting.

### 6. Check that the run did the work

- `GET /v2/run/<run_id>`: `failed` must be false. Read `logs` for errors.
- `GET /v1/warnings/<run_id>`: explain every warning.
- `GET /v1/notes/<run_id>`: the notes your commands printed.
- Your verification step passed.
- `[IDLE]` power is close to `[BASELINE]` (step 7).

To list a repository's runs:

```text
GET /v2/runs?uri=<repo url>&uri_mode=exact&branch=<branch>&machine_id=<id>&failed=false&limit=50
```

Each row is:

```text
[run_id, name, uri, branch, created_at, warnings, filename, variables, machine, commit_hash, end_measurement, failed, machine_id, relations]
```

A person can open a run at `https://metrics.green-coding.io/stats.html?id=<run_id>`.

### 7. Read the numbers

`GET /v1/phase_stats/single/<run_id>` returns every metric for every phase:

```text
data.data[<phase>].data[<metric>] =
  {"type": "TOTAL" or "MEAN", "unit": ..., "data": {<detail>: {"data": {<run_id>: {"mean": ...}}}}}
```

- Phases are named as in the flow, without numbering.
- `<detail>` is a container name, `[MACHINE]`, `[SYSTEM]` or a CPU package.

| Metric | Unit | What it is |
| --- | --- | --- |
| `psu_energy_ac_<provider>_machine` | uJ | the whole machine at the wall; the provider depends on the machine ([mcp](https://docs.green-coding.io/docs/measuring/metric-providers/psu-energy-ac-mcp-machine/), [ipmi](https://docs.green-coding.io/docs/measuring/metric-providers/psu-energy-ac-ipmi-machine/)) |
| `psu_power_ac_<provider>_machine` | mW | mean wall power |
| `cpu_energy_rapl_msr_component`, `memory_energy_rapl_msr_component` | uJ | the CPU package and DRAM ([RAPL](https://docs.green-coding.io/docs/measuring/metric-providers/cpu-energy-rapl-msr-component/)); one detail per CPU package |
| `phase_time_syscall_system` | us | the phase's length |
| `cpu_utilization_cgroup_container` | 1/100 % of the machine | per container ([docs](https://docs.green-coding.io/docs/measuring/metric-providers/cpu-utilization-cgroup-container/)) |
| `memory_used_cgroup_container` | bytes, mean | per container; includes the page cache ([docs](https://docs.green-coding.io/docs/measuring/metric-providers/memory-used-cgroup-container/)) |
| `disk_total_write_cgroup_container`, `disk_total_read_cgroup_container` | bytes | per container ([docs](https://docs.green-coding.io/docs/measuring/metric-providers/disk-io-cgroup-container/)) |
| `network_total_cgroup_container` | bytes | per container, sent plus received ([docs](https://docs.green-coding.io/docs/measuring/metric-providers/network-io-cgroup-container/)) |
| `custom_<key>` | your unit | your work counter, summed over the phase |

Which metrics a run has depends on the machine. Machine 6 has no wall-power
meter and no per-container CPU, memory or disk figures. Units are explained
under [Units and dimensions](https://docs.green-coding.io/docs/general-info/units-and-dimensions/).

For each run and each measured phase, compute:

- **Added energy:** `dE = E - P_ref x T`, where E is the phase energy, T its
  length and P_ref the reference power.
- **Per unit of work:** `dE / ops`.
- **P_ref:** the `[IDLE]` power. If `[IDLE]` is more than about 1 W above
  `[BASELINE]`, something was busy before the flow started. Use `[BASELINE]`
  instead and say why.
- **Core-seconds of a container:** `utilization / 10000 x cores x T`.

This helper does it for one run and one phase. It needs Python 3 and the
standard library only. It uses the wall-power meter where the machine has one
and the CPU package plus DRAM (RAPL) otherwise, and says which. It works without
a token too, for runs the default user can see:

```python
#!/usr/bin/env python3
"""Added energy and energy per unit of work for one phase of one GMT run.

usage: gmt_result.py <run_id> "<phase name>" [custom_<key>]
"""
import json
import os
import sys
import urllib.request

API = os.environ.get("GMT_API_URL", "https://api.green-coding.io")
TOKEN_FILE = os.path.expanduser("~/.gmt/token")
TOKEN = os.environ.get("GMT_AUTH_TOKEN") or (open(TOKEN_FILE).read().strip() if os.path.exists(TOKEN_FILE) else "")


def get(path):
    headers = {"X-Authentication": TOKEN} if TOKEN else {}
    with urllib.request.urlopen(urllib.request.Request(API + path, headers=headers)) as r:
        if r.status == 204:
            raise SystemExit(f"{path}: no data (wrong run ID, or a run this user cannot see)")
        return json.load(r)["data"]


def total(stats, phase, metric):
    """One metric's mean in one phase, summed over its details (CPU packages, containers)."""
    m = stats["data"].get(phase, {}).get("data", {}).get(metric)
    if not m:
        return None
    return sum(next(iter(d["data"].values()))["mean"] for d in m["data"].values())


def energy_metrics(stats):
    """Wall power if the machine has a meter, otherwise CPU package plus DRAM (RAPL)."""
    for name in stats["data"]["[RUNTIME]"]["data"]:
        if name.startswith("psu_energy_ac_") and name.endswith("_machine"):
            return "wall", [name]
    return "RAPL CPU package + DRAM", ["cpu_energy_rapl_msr_component", "memory_energy_rapl_msr_component"]


def summed(stats, phase, metrics):
    values = [v for v in (total(stats, phase, m) for m in metrics) if v is not None]
    if not values:
        raise SystemExit(f"none of {metrics} in phase {phase}")
    return sum(values)


run_id, phase = sys.argv[1], sys.argv[2]
work = sys.argv[3] if len(sys.argv) > 3 else None
s = get(f"/v1/phase_stats/single/{run_id}")
source, energy = energy_metrics(s)
power = [m.replace("_energy_", "_power_") for m in energy]

E = summed(s, phase, energy) / 1e6                              # uJ -> J
T = total(s, phase, "phase_time_syscall_system") / 1e6         # us -> s
P_base = summed(s, "[BASELINE]", power) / 1e3                  # mW -> W, no containers
P_idle = summed(s, "[IDLE]", power) / 1e3                      # containers up, flow not started
ops = total(s, phase, work) if work else None

out = {
    "phase": phase, "energy_source": source, "T_s": round(T, 2), "E_J": round(E, 1),
    "P_baseline_W": round(P_base, 2), "P_idle_W": round(P_idle, 2),
    "dE_above_idle_J": round(E - P_idle * T, 1),
    "dE_above_baseline_J": round(E - P_base * T, 1),
    "ops": ops,
}
if ops:
    out["J_per_op_above_idle"] = (E - P_idle * T) / ops
    out["J_per_op_above_baseline"] = (E - P_base * T) / ops
if P_idle - P_base > 1.0:
    out["warning"] = "[IDLE] is more than 1 W above [BASELINE]: something is busy in IDLE, prefer the baseline figures"
for k, v in s["data"][phase]["data"].items():
    if k.startswith(("cpu_utilization_cgroup_container", "memory_used_cgroup_container",
                     "disk_total_write_cgroup_container", "network_total_cgroup_container")):
        out[k] = {det: next(iter(d["data"].values()))["mean"] for det, d in v["data"].items()}
print(json.dumps(out, indent=1))
```

**Cross-check with `GET /v1/compare?ids=<id>,<id>,...`.**

- **Two branches** of one repository, on one scenario file and one machine,
  give the "Branch" comparison. **Two commits on one branch** give "Commit".
- For each phase and metric, the entry at `data.data[<phase>].data[<metric>].data[<detail>]`
  holds a Welch t-test (`p_value`, `is_significant`). Below it, each side
  carries its `mean`, `stddev` and `values`.
- `p_value` is null when a side has only one run.
- It compares raw values, not energy above idle and not per unit of work, so
  use it as a cross-check of your own figures.
- A combination it cannot handle comes back as plain text, not JSON:
  "Compare endpoint cannot handle this set of IDs directly".
- The cases and the test are described under
  [Comparing measurements](https://docs.green-coding.io/docs/measuring/comparing-measurements/).

**Time series.** `GET /v1/measurements/single/<run_id>` returns them, but they
are deleted after about 31 days on this cluster. Phase statistics are kept.
Fetch time series right away if you need them.

### 8. Decide and report

- Claim an effect only when the before and after replicates do not overlap and
  the difference beats the noise (Verifying a recommendation, point 4).
- Report energy per unit of work, and CPU, memory, disk and network beside it.
- For an idle-burn fix, report the idle phase on its own.
- Put the run IDs of both sides in the finding's "Measured" line, with
  dashboard links.
- If the numbers do not show the effect, say so and lower the finding's
  confidence. A result that shows no effect is still a result.

---

## Report template

```markdown
# Resource-efficiency review: <project>, <commit>

## Profile
- What it is / runtime / toolkit:
- Interactive, server or batch:
- Unit of work:
- Where the difference is likely to sit (see "Estimating the effect"):

## Findings (ranked)

### 1. <one-line title>
- Where: `path/to/file.ext:123` (and related locations)
- Mechanism: what runs, when, how often, and why it is not needed
- Rule: <number and name>
- Expected effect: <range>, based on <rule evidence / arithmetic / not measured>
- Confidence: high / medium / low, and why
- Change: <concrete change>
- Trade-offs: <behaviour, UX, correctness, migration cost>
- Verify: <scenario, metric, unit of work, expected direction, noise to beat>
- Measured: <before and after run IDs with the result, or "not measured yet">

## Checked and ruled out
- <area>: <why it is fine>

## Measure first
<the one measurement that would confirm or kill the top finding>
```
