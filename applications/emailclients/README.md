# Benchmarking email clients

Seven email clients driven through the same scenario against the same local
mailbox: a deterministic ~500 MB IMAP corpus served by Dovecot, with Postfix
accepting the mail the scenario sends.

Nothing leaves the Docker network and nothing is downloaded at measurement time,
so a recording made today replays identically next year and on another machine.

## Clients under test

Every install and launch below was run in this container and checked against a
screenshot. The "starts at" column says what is on screen when the client comes
up, because that is what the first block of a recording has to deal with.

| Client | Version | Source | Starts at |
| ------ | ------- | ------ | --------- |
| [Mozilla Thunderbird](thunderbird/) | 153.0.1 ESR | Mozilla tarball | mail view, connecting; asks for the password once |
| [Betterbird](betterbird/) | 140.12.0esr-bb24 | New Life Linux PPA | mail view, connecting; asks for the password once |
| [Claws Mail](clawsmail/) | 4.2.0 | Ubuntu 24.04 | mail view with the account in the folder tree |
| [GNOME Evolution](evolution/) | 3.52.3 | Ubuntu 24.04 | scanning folders; password pre-filled, confirm once |
| [KMail (Kontact)](kmail/) | 23.08.5 | Ubuntu 24.04 | mailbox, account collapsed — the profile carries the account |
| [Mailspring](mailspring/) | 1.23.0 | GitHub release | "Welcome to Mailspring"; onboarding needs the internet |
| [BlueMail](bluemail/) | 1.140.14 | packages.bluemail.me | welcome screen — no scripted seeding possible |

Thunderbird is installed from Mozilla's tarball rather than apt because Ubuntu
24.04's `thunderbird` package is `2:1snap1-0ubuntu3`, a stub that installs the
snap — useless in a container with no snapd. Mozilla's apt repository publishes
only Firefox.

### Popularity

Debian popcon data from <https://popcon.debian.org>, for context on which of
these are worth measuring:

```text
package                   inst     vote     old      recent
evolution-data-server     72949    51047    14384    7510
evolution                 61909    7027     44645    10232
kmail                     28453    11807    12515    4127
thunderbird               28211    12603    10933    4673
mutt                      24213    2874     17794    3533
kontact                   2784     318      2318     148
alpine                    1836     282      1495     59
claws-mail                1252     470      671      110
neomutt                   823      237      544      42
sylpheed                  400      120      222      58
aerc                      236      53       176      7
balsa                     143      11       122      10
betterbird                0        0        0        0
bluemail                  0        0        0        0
himalaya                  0        0        0        0
mailspring                0        0        0        0
trojita                   0        0        0        0
```

Betterbird, Mailspring and BlueMail read as zero because Debian does not package
them; they are installed from upstream here. `evolution-data-server` outranks
`evolution` itself because other GNOME components pull it in.

## How it is wired up

Every `usage_scenario.yml` declares two services on a private network:

```text
                    network: parrot-mail
  ┌───────────────────────┐        ┌──────────────────────────────┐
  │ mail-container        │        │ window-container             │
  │                       │◀───────│  Xvfb + fluxbox              │
  │ Dovecot   143 / 993   │  IMAP  │  the email client under test │
  │ Postfix   587 / 465   │◀───────│  replay.py                   │
  │                       │  SMTP  │                              │
  │ ~500 MB Maildir       │        │                              │
  └───────────────────────┘        └──────────────────────────────┘
     alias: mail.parrot.test
```

The mail server is a separate container on purpose: the Green Metrics Tool
measures per container, so server cost stays out of the client's figure. The
client container `depends_on` the mail container, and GMT sets services up in
dependency order — so by the time the client is created, the server is serving
and has passed its own smoke test.

`mail.parrot.test` resolves because the mail service declares it as a Docker
network alias, which also makes it match the certificate the server issues
itself.

### The mail server is a prebuilt image

`ribalba/parrot-mailserver` carries the packages, the configuration and the whole
corpus, so starting it takes about five seconds instead of the three and a half
minutes it costs to generate 13,481 messages — a cost that would otherwise be
paid on every one of the seven client benchmarks, on every repetition.

It also closes a reproducibility hole: the generator is deterministic on a given
machine, but the PNG attachments go through zlib, whose compressed output is not
guaranteed identical across zlib versions. A different zlib would shift
attachment sizes, and with them the message sizes recorded in every Maildir
filename. Shipping the bytes means every machine syncs exactly the same mailbox.

```bash
make mailserver          # build and load locally
make check-mailserver    # start it and run the smoke test
make push-mailserver     # publish
```

Bump `MAIL_TAG` in the `Makefile` when the corpus changes; the tag is what the
scenarios pin. Every `usage_scenario.yml` also carries the from-scratch
alternative as a comment, which is what you want when iterating on the corpus
itself. See [`mailserver/README.md`](mailserver/README.md) for the details,
including the Dovecot index pre-warming.

### Getting the CA to the client

The mail container mints a throwaway CA on every run, so no certificate or
private key is committed and nothing expires. The client cannot read it off a
shared volume — GMT does not create named volumes — so instead Dovecot is
configured to send leaf **and** CA in the handshake, and
[`common/client-setup.sh`](common/client-setup.sh) recovers the CA with
`openssl s_client -showcerts` and installs it into the system trust store.

## The mailbox

[`mailserver/generate_corpus.py`](mailserver/generate_corpus.py) writes a
Maildir++ tree that is byte-for-byte identical on every run. Every random choice
is derived from a fixed seed plus the message's own folder and index, and every
date comes from a frozen epoch rather than the clock — so any message can be
regenerated in isolation, and two runs produce the same bytes, with the same
filenames, including the flag and size parts.

To confirm it, generate twice and compare. Both runs must print the same digest
(it depends on `--target-mb`, so compare like with like):

```bash
for d in a b; do
  ./generate_corpus.py --root /tmp/$d/Maildir --target-mb 500 --fresh
  (cd /tmp/$d && find Maildir -type f | sort | xargs -d '\n' sha256sum | sha256sum)
done
```

13,481 messages across 12 folders:

| Folder | Messages | Folder | Messages |
| ------ | -------- | ------ | -------- |
| INBOX | 2100 (66 unread) | Sent | 940 |
| Lists/parrot-dev | 3600 (432 unread) | Junk | 260 (182 unread) |
| Archive/2024 | 1850 | Trash | 130 (13 unread) |
| Archive/2023 | 1650 | Lists/announce | 520 (21 unread) |
| Archive/2025 | 1500 | Projects/Aurora | 540 |
| Projects/Borealis | 380 | Drafts | 11 |

Total size is driven to the `--target-mb` figure by sizing the attachments: the
generator first measures how many bytes the message text needs, then spreads the
remainder over the ~580 attachment-bearing messages with a long-tailed
distribution. At the default target it lands within a fraction of a percent:

```text
[corpus] message text: 50.1 MiB, 582 attachment slots
[corpus] done: 13481 messages, 500.8 MiB (target 500 MiB) in 172.4s
```

Messages are `multipart/alternative` (plain + HTML, quoted-printable) with
threading headers, mailing-list headers where appropriate, and a realistic mix
of read, unread, flagged and answered flags. Attachments are **real, openable
files** — PDFs with selectable text, valid PNGs, real ZIP archives, CSV and log
files — because the scenario opens one of them in the client under test.

Everything is written with CRLF line endings and its size stated in the Maildir
filename (`,S=…,W=…`), which is what a real LMTP delivery produces and saves
Dovecot from restating 13,481 filenames on first access.

### Anchors

The scenario refers to specific messages. They are pinned to fixed positions so
a recorded macro keeps working, and
[`mailserver/smoke_test.py`](mailserver/smoke_test.py) asserts every one of them
over IMAP before a benchmark is allowed to start.

| Anchor | Where | Subject |
| ------ | ----- | ------- |
| newest, unread | INBOX #1 | `Re: Release checklist for Aurora 4.2` |
| reply target | INBOX #2 | `Staging cluster credentials rotated` |
| largest (12 MB ZIP) | INBOX #3 | `Design assets bundle - Borealis rebrand` |
| PDF attachment (2.6 MB) | INBOX #7 | `Quarterly infrastructure review - final PDF` |

"Position #n" means the nth newest by sent date — what every client shows by
default. It is deliberately *not* IMAP sequence order: unread messages live in
the maildir's `new/` directory and are assigned UIDs after the read ones, so
sequence order is not date order.

The search term is **`Windvane`**: 9 messages contain it in the body, 3 of those
also in the subject, spread over INBOX, Archive/2024, Archive/2025,
Projects/Aurora and Sent. It appears nowhere else in the corpus, so the hit count
is a stable assertion for clients that search full text (9) and for clients whose
quick-filter only searches subjects (3).

`alice.brenner@parrot.test` and the other `@parrot.test` personas are aliased
onto the benchmark mailbox by Postfix, so mail the scenario composes is delivered
straight back and shows up in the inbox.

### Account

| | |
| - | - |
| Address | `parrot@parrot.test` |
| Username | `parrot` (or `parrot@parrot.test` — both work) |
| Password | `parrot` |
| Display name | `Robin Parrot` |
| IMAP | `mail.parrot.test:143` (no encryption) or `:993` (TLS) |
| Submission | `mail.parrot.test:587` (plain/STARTTLS) or `:465` (TLS) |

All of it lives in [`account.env`](account.env).

**The default account uses no encryption, and that is a deliberate compromise.**
It is the only setting all seven clients can be pre-configured for without a
human accepting a certificate mid-measurement, which keeps the comparison about
the client rather than about whose trust dialog appears when. The server always
offers all three modes; set `PARROT_MAIL_SECURITY` to `starttls` or `tls` in
`account.env` to measure the TLS path instead. Do it for every client or none —
TLS on a 500 MB sync is a real and unevenly distributed cost.

## The scenario

[`script.md`](script.md) — seventeen steps a normal person actually performs:

```text
* Load app
* Sync account
* Read newest
* Scroll to bottom
* Read second
* Open PDF attachment
* Search account
* Open result
* Clear search
* Move to Archive
* Delete message
* Flag message
* Mark five unread
* Open Archive 2024
* Reply and send
* Compose and send
* Empty trash
```

Those are only the labels. Each line in `script.md` continues after a colon with
the exact instruction — which message, which subject, which text to type:

```text
* Reply and send: reply to message 2 with the body text `Thank you so much` and send it
* Compose and send: compose a new message to `alice.brenner@parrot.test` with the
  subject `Parrot benchmark` and the body text `Thank you so much`, then send it
```

The recording checklist shows the whole line, so the same step really is the same
step in all seven clients; replay emits only the label, so the measurement notes
stay readable. That split is a Parrot feature — see
[Script labels](../../README.md#script-labels).

Being this specific matters more here than in a single-application recording.
"Reply to the second message and send it" leaves the reply text, and therefore the
message size, up to whoever holds the mouse — and seven people-sized differences
across seven clients is not a comparison.

The first sync is inside the measurement on purpose — downloading 500 MB of
headers and bodies is a large part of what an email client costs, and it is where
the clients differ most.

Several steps mutate the mailbox (send, move, delete, mark unread). That is safe
because the corpus is regenerated from scratch in every run's setup phase, so
each run starts from an identical mailbox. Nothing is persisted in a volume.

## Running a benchmark

```bash
./runner.py --uri /home/didi/code/parrot \
            --filename applications/emailclients/thunderbird/usage_scenario.yml
```

Setup takes a few minutes — apt installs, a client download, and about three
minutes of corpus generation. None of it is measured.

While iterating on a recording, lower `PARROT_MAIL_TARGET_MB` in the scenario's
`mail-container` environment: at 100 the corpus generates in about seven seconds
instead of three minutes, and the message counts, folder layout and anchor
positions are all unchanged — only the attachments shrink. There is a floor of
roughly 75 MB (the message text is 50 MB on its own, and the two anchor
attachments are fixed at 2.6 and 12 MB); asking for less just prints a warning
and gives you the floor.

