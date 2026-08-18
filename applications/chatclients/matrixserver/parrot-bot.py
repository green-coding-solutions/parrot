#!/usr/bin/env python3
"""The Parrot benchmark's server-side bot: the thing the scenario can trigger.

Two blocks of the scenario need the *server* to do something at a point the
client chooses, and a Green Metrics Tool run gives us no way to arrange that
from outside.  A `usage_scenario.yml` has exactly one flow command - the replay
- and a replay is nothing but recorded X events.  There is no scheduler, no
second flow step, and no way to reach into the run and say "now send 24
messages".  Anything that has to happen mid-run has to be triggered by the only
actor in the run: the client under test.

So the trigger is a message.  The bot sits in a long-poll `/sync` from before
the replay starts, and reacts to what the client types:

    ping  ->  pong                          (the receive path, one round trip)
    drip  ->  `drip 01` ... `drip 24`,      (the receive path, hands-off, at a
              one every --interval seconds   pace the client cannot influence)

That makes the burst self-triggering and self-contained.  A bot posting on a
wall-clock timer would need the driver and the server to agree on when the
recording started, which does not survive being replayed on another machine a
year later; this way the burst begins when the client asks for it, and the
recording carries the ask.

WHY THE NUMBERS ARE IN THE MESSAGES
    `drip 01` ... `drip 24` are numbered so the checkpoint screenshot at the end
    of the block carries identity and not just a count.  Per AGENTS.md a
    screenshot showing "some messages arrived" is exactly the kind of signal
    that passes while the run is wrong; a screenshot showing the tail of a known
    sequence tells you whether the client rendered all of them, in order, and
    stayed pinned to the live end.  Ground truth is still the room on the
    server, not the picture.

TIMING
    Message i is posted at t0 + (i+1)*interval measured on a monotonic clock, so
    the schedule does not drift with however long the homeserver takes to accept
    each PUT.  With the defaults the first lands at t0+5s and the last at
    t0+120s.  The recording's block has to outlast that: end it once `drip 24`
    has rendered, not 120s after the trigger.

MEASUREMENT
    This runs in the homeserver container, which GMT measures separately from
    the client container - the same split the email group uses so Dovecot's cost
    does not land in Thunderbird's figure.  The bot's own CPU is therefore
    outside the number under comparison, and in any case it is identical for
    every client in the group.

Usage:
    parrot-bot.py --homeserver http://localhost:8008 --user echo --password ...
"""

import argparse
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

# Keeping the initial sync tiny matters: `Aurora Release` holds tens of
# thousands of messages, and a default sync would pull a large chunk of it for
# no reason.  The bot only ever cares about what arrives *after* it starts.
INITIAL_FILTER = json.dumps({
    'room': {
        'timeline': {'limit': 1},
        'state': {'lazy_load_members': True},
    },
    'presence': {'types': []},
})

TRIGGER_PING = 'ping'
TRIGGER_DRIP = 'drip'

# How long the startup handshake keeps trying.  Synapse has been seen returning
# a one-off 500 to the very first /sync of a freshly started container - twelve
# cold starts here never reproduced it, which is exactly the profile of a
# transient - and without a retry that single response ends the GMT run before
# the flow begins.  The steady-state loop below has always ridden out a failed
# sync; this is the same tolerance applied to the two requests that happen
# before the loop exists.
#
# The product of these has to stay comfortably under start-bot.sh's
# PARROT_BOT_READY_TIMEOUT (120s by default), which is already sharing that
# budget with wait_for_homeserver.
STARTUP_ATTEMPTS = 5
STARTUP_RETRY_DELAY = 3


def log(message):
    print(f'[parrot-bot] {message}', flush=True)


class MatrixError(Exception):
    """An HTTP error from the homeserver, carrying what the homeserver said.

    urllib's HTTPError stringifies to nothing but the status line, and the body
    is where Synapse explains itself: a handled failure names an errcode, an
    unhandled exception is a bare M_UNKNOWN.  Discarding it is expensive here in
    particular, because GMT deletes the container the moment a setup-command
    fails - whatever was not printed is gone with it.
    """

    def __init__(self, status, message):
        super().__init__(message)
        self.status = status


# Everything worth retrying rather than dying on: the homeserver refusing a
# connection, a socket dying mid-request, or the homeserver failing the request
# itself.  Named once because the drip loop, the sync loop and the startup
# handshake all have to agree on it.
TRANSIENT_ERRORS = (MatrixError, urllib.error.URLError, OSError)


def with_retries(what, call, attempts=STARTUP_ATTEMPTS, delay=STARTUP_RETRY_DELAY):
    """Run a startup request, retrying through transient failures.

    A 4xx is not retried: that is the benchmark being misconfigured - a wrong
    password, a filter this Synapse rejects - and repeating it just turns an
    immediate, legible failure into a slow one.
    """
    for attempt in range(1, attempts + 1):
        try:
            return call()
        except TRANSIENT_ERRORS as error:
            if isinstance(error, MatrixError) and error.status < 500:
                raise
            if attempt == attempts:
                raise
            log(f'{what} failed ({error}); retrying in {delay}s '
                f'[{attempt}/{attempts - 1}]')
            time.sleep(delay)
    raise AssertionError('unreachable')


class MatrixClient:
    """The three Matrix endpoints this needs, over stdlib urllib.

    No SDK on purpose: the homeserver image should not need a pip install to
    run the benchmark, and a pinned dependency is one more thing that can drift
    between the machine that recorded and the machine that replays.
    """

    def __init__(self, homeserver, timeout=60):
        self.homeserver = homeserver.rstrip('/')
        self.timeout = timeout
        self.token = None
        self.user_id = None
        self._txn = 0

    def _request(self, method, path, body=None, params=None):
        url = f'{self.homeserver}/_matrix/client/v3{path}'
        if params:
            url = f'{url}?{urllib.parse.urlencode(params)}'
        data = json.dumps(body).encode() if body is not None else None
        request = urllib.request.Request(url, data=data, method=method)
        request.add_header('Content-Type', 'application/json')
        if self.token:
            request.add_header('Authorization', f'Bearer {self.token}')
        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as response:
                return json.loads(response.read() or b'{}')
        except urllib.error.HTTPError as error:
            detail = error.read().decode('utf-8', 'replace').strip()
            raise MatrixError(
                error.code, f'{method} {path} -> {error.code} {detail}'
            ) from None

    def login(self, user, password):
        result = self._request('POST', '/login', {
            'type': 'm.login.password',
            'identifier': {'type': 'm.id.user', 'user': user},
            'password': password,
            'initial_device_display_name': 'parrot-bot',
        })
        self.token = result['access_token']
        self.user_id = result['user_id']
        return self.user_id

    def sync(self, since=None, timeout_ms=30000):
        params = {'timeout': timeout_ms}
        if since:
            params['since'] = since
        else:
            params['filter'] = INITIAL_FILTER
        return self._request('GET', '/sync', params=params)

    def send_text(self, room_id, body):
        self._txn += 1
        room = urllib.parse.quote(room_id, safe='')
        return self._request(
            'PUT',
            f'/rooms/{room}/send/m.room.message/parrot{self._txn}',
            {'msgtype': 'm.text', 'body': body},
        )


def wait_for_homeserver(client, deadline_seconds=120):
    """Block until /versions answers.

    GMT brings the containers up in `depends_on` order, but Synapse answering
    the port is not the same as Synapse being ready to log a user in.
    """
    deadline = time.monotonic() + deadline_seconds
    while time.monotonic() < deadline:
        try:
            urllib.request.urlopen(
                f'{client.homeserver}/_matrix/client/versions', timeout=5
            ).read()
            return True
        except (urllib.error.URLError, OSError):
            time.sleep(1)
    return False


def run_drip(client, room_id, count, interval):
    """Post `drip 01` .. `drip NN` on a fixed schedule.

    Deliberately blocking.  While a burst is running the bot answers nothing
    else, which is what the scenario wants: the block is supposed to be the
    client sitting still with messages arriving, and nothing else moving.
    """
    log(f'drip: {count} messages every {interval}s into {room_id}')
    start = time.monotonic()
    for index in range(count):
        target = start + (index + 1) * interval
        remaining = target - time.monotonic()
        if remaining > 0:
            time.sleep(remaining)
        body = f'drip {index + 1:02d}'
        try:
            client.send_text(room_id, body)
        except TRANSIENT_ERRORS as error:
            # Keep the schedule rather than the sequence: a gap in the numbers
            # is visible in the checkpoint screenshot, a shifted schedule is not.
            log(f'drip: FAILED to send {body}: {error}')
            continue
    log(f'drip: finished {count} messages in {time.monotonic() - start:.1f}s')


def handle_event(client, room_id, event, args):
    if event.get('type') != 'm.room.message':
        return
    if event.get('sender') == client.user_id:
        return
    body = (event.get('content') or {}).get('body')
    if not isinstance(body, str):
        return

    trigger = body.strip().lower()
    if trigger == TRIGGER_PING:
        log(f'ping from {event.get("sender")} in {room_id}')
        client.send_text(room_id, 'pong')
    elif trigger == TRIGGER_DRIP:
        log(f'drip requested by {event.get("sender")} in {room_id}')
        run_drip(client, room_id, args.count, args.interval)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n', maxsplit=1)[0])
    parser.add_argument('--homeserver', default='http://localhost:8008')
    parser.add_argument('--user', default='echo')
    parser.add_argument('--password', required=True)
    parser.add_argument('--count', type=int, default=24,
                        help='messages per drip burst (default 24)')
    parser.add_argument('--interval', type=float, default=5.0,
                        help='seconds between drip messages (default 5.0)')
    parser.add_argument('--ready-file',
                        help='touch this once synced and listening, so a '
                             'setup-command can gate on it')
    args = parser.parse_args()

    client = MatrixClient(args.homeserver)
    if not wait_for_homeserver(client):
        log(f'ERROR: {args.homeserver} never answered')
        return 1

    # Both retried, and the failure reported as one line rather than a stdlib
    # traceback: start-bot.sh tails this log into GMT's error output, and a
    # traceback there says which urllib frame raised rather than what the
    # homeserver said.
    try:
        user_id = with_retries('login', lambda: client.login(args.user, args.password))
        log(f'logged in as {user_id}')

        # The token from the *initial* sync is the cut-off.  Everything already
        # in the rooms is history the bot must not react to - without this it
        # would answer the previous run's triggers the moment it restarts.
        since = with_retries('initial sync', lambda: client.sync(timeout_ms=0))['next_batch']
    except TRANSIENT_ERRORS as error:
        log(f'ERROR: startup failed: {error}')
        return 1
    log('synced; listening for triggers')

    if args.ready_file:
        with open(args.ready_file, 'w', encoding='utf-8') as handle:
            handle.write(f'{user_id}\n')

    while True:
        try:
            result = client.sync(since=since)
        except TRANSIENT_ERRORS as error:
            log(f'sync failed, retrying: {error}')
            time.sleep(2)
            continue
        since = result['next_batch']
        joined = (result.get('rooms') or {}).get('join') or {}
        for room_id, room in joined.items():
            for event in ((room.get('timeline') or {}).get('events') or []):
                handle_event(client, room_id, event, args)


if __name__ == '__main__':
    sys.exit(main())
