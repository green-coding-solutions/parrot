# The homeserver side of the chat-client benchmark

A local Synapse serving a deterministic corpus, plus one bot that exists purely
so the scenario can make the *server* do something at a moment the *client*
chooses.

## Why there is a bot at all

Two blocks of [`../script.md`](../script.md) need messages to arrive from
outside the client:

| Block | What has to happen |
| ----- | ------------------ |
| Echo round trip | one message arrives, shortly after the client sends `ping` |
| Idle receiving | 24 messages arrive over two minutes while nobody touches the client |

A Green Metrics Tool run gives us nowhere to put that. A `usage_scenario.yml`
has exactly one flow command - the replay - and a replay is a stream of recorded
X events. There is no scheduler, no second flow step, and no way to reach into a
run in progress and say "now send 24 messages". A cron job or a timer started at
container boot would not help either: it would have to agree with the recording
about when the burst begins, and that agreement does not survive being replayed
on a slower machine next year, where every earlier block takes longer.

So the only actor that can start the burst is the client under test, and the
only thing the client can do is send a message. That is the whole design:

```text
client types `drip`  ->  Synapse  ->  bot's /sync long-poll wakes up
                                          |
                          `drip 01` ... `drip 24`, one every 5s
                                          |
                                      Synapse  ->  client renders them
```

The recording carries the trigger, so the burst starts at the same point in the
scenario on every machine, and the client's own clock never enters into it.

## Wiring it into a usage_scenario

The bot is a daemon, which means it can be neither a flow command (the flow is
the replay) nor a bare setup-command (setup-commands have to finish, and a
daemon does not). `start-bot.sh` resolves that: it backgrounds the bot and then
blocks until the bot has finished its initial sync, so the replay cannot begin
before the bot is able to hear a trigger.

```yaml
services:
  matrix-container:
    image: ribalba/parrot-matrixserver:v1
    networks:
      parrot-matrix:
        aliases:
          - matrix.parrot.test
    setup-commands:
      - command: parrot-matrixserver-start          # synapse + the seeded corpus
      - command: parrot-bot-start                   # this directory's start-bot.sh

  window-container:
    image: ribalba/xwindow-server
    depends_on:
      - matrix-container
    ...
```

`depends_on` makes GMT finish this container's setup-commands before the client
container is created, so by the time any client exists the bot is listening.

## What it costs the measurement

Nothing that lands on the client. The two containers are measured separately -
the same split the email group uses so Dovecot's cost stays out of
Thunderbird's figure - so the bot's CPU sits in the homeserver's number. And it
is identical for every client in the group in any case: the same 24 messages,
on the same schedule, triggered at the same point in the same scenario.

## The numbers are in the messages on purpose

The burst is `drip 01` through `drip 24`, not 24 copies of the same text, so the
checkpoint screenshot at the end of the block carries identity rather than a
count. Per [`../../../AGENTS.md`](../../../AGENTS.md), "the right number of
things appeared" is exactly the class of signal that passes while the run is
quietly wrong. A numbered sequence shows whether the client rendered all of
them, in order, and stayed pinned to the live end - and if the client never
managed to send the trigger at all, the block is visibly empty instead of
silently measuring two minutes of idle.

That is still only the screenshot. Ground truth is the room on the server:
24 `m.room.message` events from `@echo:parrot.test` after the trigger.

## Files

| File | What it is |
| ---- | ---------- |
| `parrot-bot.py` | the bot: stdlib-only, long-polls `/sync`, answers `ping` and `drip` |
| `start-bot.sh` | backgrounds it and waits for it to be listening; the setup-command |

Both read [`../account.env`](../account.env), which is where the bot's
credentials and the burst's count and interval live. The scenario's last block
is written around those two numbers - 24 messages five seconds apart is the
"two minutes" it claims to measure - so changing them means rewording the block
and re-pacing the recording.

## Shipping a change to either of them

They run from inside `ribalba/parrot-matrixserver`, not from the mounted
repository, so committing a fix does not deploy it — the published image kept an
older `parrot-bot.py` for exactly this reason, one whose startup `/sync` was not
retried, and a run died in BOOT on the HTTP 500 a warming-up Synapse returns on
the first attempt.

```bash
make patch-matrixserver          # layer the current scripts onto the published image
make check-matrixserver          # start it, seed nothing, watch the bot come up
make push-patched-matrixserver   # publish over the same tag
```

That path keeps the corpus, which is the whole point: `make matrixserver`
reseeds, and a reseed changes every room and event ID the recordings are tied
to. Use it only when a build-time input changed — `account.env`, `conf/`,
`build.sh`, `setup.sh`, `seed_corpus.py` — and bump `MATRIX_TAG` when you do.

## Checking it without a homeserver

`parrot-bot.py` talks plain HTTP JSON and takes `--homeserver`, so it can be
pointed at a stub that serves `/versions`, `/login`, `/sync` and the send
endpoint. Feeding it one `drip` event and recording the PUTs verifies the part
that is easy to get wrong - that the burst holds its schedule instead of
drifting by however long each send takes - without bringing Synapse up.
