# The benchmark mail server

Dovecot (IMAP) and Postfix (submission) serving a deterministic ~500 MB mailbox
on an isolated Docker network. Nothing here is exposed to the outside world and
nothing is downloaded at measurement time.

## Two ways to run it

### Prebuilt image (what the benchmarks use)

The image carries the packages, the configuration, the certificates and the
whole corpus, so a benchmark run only starts two daemons:

```console
$ docker exec mail-container parrot-mailserver-start
[mailserver] port 143 (imap) is up
...
[smoke] all checks passed
[mailserver] ready

real  0m5.029s
```

Five seconds, against three and a half minutes from scratch — and that cost
would otherwise be paid on every one of the eight client benchmarks, on every
repetition.

Baking the corpus also closes a reproducibility hole. The generator is
deterministic on a given machine, but the PNG attachments are produced with
zlib, and zlib's compressed output is not guaranteed byte-identical across
versions or builds. A different zlib would shift attachment sizes, and with them
the message sizes recorded in every Maildir filename. Shipping the bytes means
every machine that pulls the image syncs exactly the same mailbox.

Build and publish it:

```bash
make mailserver              # build and load locally
make check-mailserver        # start it and run the smoke test
make push-mailserver         # push to the registry

make mailserver MAIL_TARGET_MB=100   # smaller corpus, ~25 s build
```

Bump `MAIL_TAG` in the top-level `Makefile` whenever the corpus changes — the tag
is what every `usage_scenario.yml` pins.

### From scratch

Useful when changing the corpus itself, since there is no image to rebuild:

```bash
docker run -d --name mail -v /path/to/parrot:/tmp/repo:ro \
    -e PARROT_MAIL_TARGET_MB=100 \
    ubuntu@sha256:9cbed754112939e914291337b5e554b07ad7c392491dba6daf25eef1332a22e8 sleep inf
docker exec mail bash /tmp/repo/applications/emailclients/mailserver/setup.sh
```

Each `usage_scenario.yml` carries this as a commented alternative next to the
`mail-container` service.

## What runs when

| Script | When | Cost |
| ------ | ---- | ---- |
| [`build.sh`](build.sh) | image build | ~3.5 min — apt, the account, the corpus, the configs |
| [`make-certs.sh`](make-certs.sh) | image build, or first start | under a second; skipped if certificates exist |
| [`start.sh`](start.sh) | every run | ~5 s — daemons, port wait, smoke test |
| [`setup.sh`](setup.sh) | from-scratch only | `build.sh` then `start.sh` |

`start.sh` is on `PATH` inside the image as `parrot-mailserver-start`, and
[`smoke_test.py`](smoke_test.py) as `parrot-mailserver-smoke`, so a
`usage_scenario.yml` setup-command does not need to know where the repository was
mounted.

Set `PARROT_SKIP_SMOKE=1` to start without verifying, and `PARROT_FORCE_CERTS=1`
to mint fresh certificates over the baked ones.

## Dovecot indexes are pre-warmed

The image build runs `doveadm index -u parrot '*'`, which assigns UIDs and builds
the base indexes for all 13,481 messages. Without it, whichever client connects
first pays for scanning the entire maildir, and that cost lands in its energy
figure rather than the server's. A mail server someone has actually been using
has warm indexes, so this is both the fairer and the more realistic starting
state. Build with `--build-arg PARROT_WARM_INDEXES=0` to leave them cold.

## Files

| File | Purpose |
| ---- | ------- |
| [`generate_corpus.py`](generate_corpus.py) | the deterministic corpus; `--print-anchors` dumps the layout without writing |
| [`smoke_test.py`](smoke_test.py) | asserts folder counts, search anchors, message positions and a submission round trip |
| [`conf/dovecot-parrot.conf`](conf/dovecot-parrot.conf) | overrides Debian's defaults as `conf.d/99-parrot.conf` |
| [`conf/postfix-main.cf`](conf/postfix-main.cf) | delivery via Dovecot LMTP, SASL via Dovecot, no outbound route |
| [`conf/postfix-master.cf`](conf/postfix-master.cf) | smtp, submission and smtps, all unchrooted |

## Security

This server is deliberately permissive: plaintext auth is allowed, the CA is a
throwaway, and every address in `parrot.test` is aliased onto one mailbox. It
exists only on an internal Docker network holding synthetic mail, and
`default_transport` is an error, so nothing can leave.

**Do not run this configuration anywhere reachable from a real network.**
