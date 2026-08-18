#!/usr/bin/env python3
"""Seed a deterministic Matrix corpus for the Parrot chat-client benchmark.

The corpus is the same on every build: every random choice is derived from a
fixed seed plus the message's own coordinates (room + index), and every
timestamp comes from a fixed epoch instead of the wall clock.  That means a
benchmark recorded against this corpus replays identically weeks later and on
another machine.

WHY EVERY TIMESTAMP IS IN THE PAST
    Every Matrix client renders recent messages as relative labels - "today",
    "12:04", "2 minutes ago" - and absolute dates once they are old enough.  A
    corpus stamped with the build date therefore looks different tomorrow than
    it did today, and every reference screenshot rots.  With the whole corpus
    frozen in 2026-06, every client always renders an absolute date.  This is
    the same anchor the email group's generate_corpus.py uses, and it is only
    reachable here because the seeder runs as an application service, which is
    the only kind of Matrix client allowed to say when a message was sent.

WHAT THE SCENARIO DEPENDS ON
    ../script.md names specific rooms and specific messages.  Those are anchors,
    not decoration - a recording clicks at the coordinates where they land.  The
    ones that must not move:

      Aurora Release        deep history, 500 members - the initial-sync load
      Field Photos          newest event is the image reservoir-at-first-light.jpg
      Windvane Deployment   newest message is the reply/react anchor, from Nadia
                            Oyelaran; the only room matching the filter `windvane`
      Parrot Echo           the bot is a member; the ping/pong block
      Parrot Firehose       the bot is a member, room otherwise quiet; the two
                            idle blocks happen here
      #parrot-lobby         public, and @parrot is deliberately NOT in it - the
                            scenario joins it and later leaves it

    The manifest written at the end records all of them, and smoke_test.py
    checks them before a benchmark is allowed to run.

Usage:
    seed_corpus.py --homeserver http://localhost:8008 --manifest /var/lib/parrot/manifest.json
"""

import argparse
import binascii
import hashlib
import json
import random
import struct
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import zlib
from datetime import datetime, timedelta, timezone

# --------------------------------------------------------------------------
# Determinism anchors.  Nothing below may read the wall clock.
# --------------------------------------------------------------------------

SEED = 'parrot-chat-benchmark-v1'

# The corpus is frozen in time, and deliberately ends in the past.  See the
# module docstring.
CORPUS_END = datetime(2026, 6, 30, 17, 42, 11, tzinfo=timezone.utc)
CORPUS_START = datetime(2023, 1, 9, 8, 15, 0, tzinfo=timezone.utc)

DOMAIN = 'parrot.test'

# The cast.  Shared with the email group's corpus on purpose: the two
# benchmarks describe the same fictional company, so a reader moving between
# the two reports meets the same people.
CAST = [
    ('nadia', 'Nadia Oyelaran'),
    ('dmitri', 'Dmitri Sokolov'),
    ('alice', 'Alice Brenner'),
    ('kwame', 'Kwame Asante'),
    ('lena', 'Lena Fischer'),
    ('yusuf', 'Yusuf Demir'),
    ('mira', 'Mira Kovacs'),
    ('tomas', 'Tomas Lindqvist'),
]

# The anchors ../script.md replies to, reacts to and looks for.
ANCHOR_WINDVANE = 'Ship it when the smoke tests are green.'
ANCHOR_PHOTO = 'reservoir-at-first-light.jpg'

WORDS = (
    'deployment rollback staging cluster latency throughput checksum manifest '
    'pipeline artifact rollout telemetry threshold retention snapshot failover '
    'quorum ingress backlog scheduler cache index shard replica migration '
    'canary probe timeout retry payload schema endpoint gateway'
).split()

OPENERS = (
    'Looks like {} is back to normal.',
    'I pushed the {} change to staging.',
    'Can someone double check the {} numbers?',
    'The {} job finished without errors this time.',
    'We are still seeing {} spikes after the restart.',
    'Nothing in the {} logs explains it.',
    'Reverted the {} patch, will retry tomorrow.',
    'That {} alert was a false positive.',
)


def log(message):
    print(f'[seed-corpus] {message}', flush=True)


def stable_random(*parts):
    """A Random seeded from the given coordinates.

    Deriving the seed from the message's own position rather than drawing from
    one shared stream means a room can be regenerated, or its size changed,
    without shifting the contents of every other room.
    """
    digest = hashlib.sha256(('|'.join(str(p) for p in (SEED,) + parts)).encode()).digest()
    return random.Random(int.from_bytes(digest[:8], 'big'))


def make_png(width, height, index):
    """A deterministic PNG, built without an image library.

    Real decodable images, because the scenario opens one at full size and
    scrolls a room full of thumbnails: what is being measured is each client's
    decode and scale path, and a placeholder rectangle would not exercise it.
    """
    rng = stable_random('png', index)
    base = (rng.randrange(40, 210), rng.randrange(40, 210), rng.randrange(40, 210))
    rows = bytearray()
    for y in range(height):
        rows.append(0)  # PNG per-scanline filter: none
        for x in range(width):
            # A smooth gradient with a little structure, so the encoded size is
            # realistic rather than a single run-length.
            rows.append((base[0] + x * 255 // max(width - 1, 1)) % 256)
            rows.append((base[1] + y * 255 // max(height - 1, 1)) % 256)
            rows.append((base[2] + ((x ^ y) & 0x3F)) % 256)

    def chunk(kind, payload):
        return (struct.pack('>I', len(payload)) + kind + payload
                + struct.pack('>I', binascii.crc32(kind + payload) & 0xFFFFFFFF))

    return (b'\x89PNG\r\n\x1a\n'
            + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(bytes(rows), 6))
            + chunk(b'IEND', b''))


class AppService:
    """The subset of the Matrix API the seeder needs, as an application service.

    The three query parameters that make this possible - `user_id` to act as
    somebody, `ts` to say when - are available to application services and to
    nothing else.  See conf/parrot-appservice.yaml.
    """

    def __init__(self, homeserver, token, timeout=120):
        self.homeserver = homeserver.rstrip('/')
        self.token = token
        self.timeout = timeout
        self._txn = 0

    def _request(self, method, path, body=None, params=None, raw=None,
                 content_type='application/json', base='/_matrix/client/v3'):
        url = f'{self.homeserver}{base}{path}'
        if params:
            url = f'{url}?{urllib.parse.urlencode(params)}'
        if raw is not None:
            data = raw
        elif body is not None:
            data = json.dumps(body).encode()
        else:
            data = None
        request = urllib.request.Request(url, data=data, method=method)
        request.add_header('Content-Type', content_type)
        request.add_header('Authorization', f'Bearer {self.token}')
        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as response:
                return json.loads(response.read() or b'{}')
        except urllib.error.HTTPError as error:
            detail = error.read().decode('utf-8', 'replace')[:400]
            raise RuntimeError(f'{method} {path} -> {error.code}: {detail}') from error

    def register(self, localpart):
        """Register an application-service user.  Idempotent."""
        try:
            self._request('POST', '/register', {
                'type': 'm.login.application_service',
                'username': localpart,
            })
        except RuntimeError as error:
            if 'M_USER_IN_USE' not in str(error):
                raise

    def set_display_name(self, user_id, name):
        self._request('PUT', f'/profile/{urllib.parse.quote(user_id)}/displayname',
                      {'displayname': name}, params={'user_id': user_id})

    def create_room(self, creator, name, topic, alias=None, public=True):
        body = {
            'name': name,
            'topic': topic,
            'preset': 'public_chat' if public else 'private_chat',
            'visibility': 'public' if public else 'private',
        }
        if alias:
            body['room_alias_name'] = alias
        return self._request('POST', '/createRoom', body,
                             params={'user_id': creator})['room_id']

    def join(self, user_id, room_id):
        self._request('POST', f'/join/{urllib.parse.quote(room_id)}',
                      {}, params={'user_id': user_id})

    def send(self, user_id, room_id, content, when):
        self._txn += 1
        room = urllib.parse.quote(room_id, safe='')
        return self._request(
            'PUT', f'/rooms/{room}/send/m.room.message/seed{self._txn}',
            content,
            params={'user_id': user_id, 'ts': int(when.timestamp() * 1000)},
        )['event_id']

    def upload(self, user_id, data, filename, mime='image/png'):
        return self._request('POST', '/upload', raw=data, content_type=mime,
                             params={'user_id': user_id, 'filename': filename},
                             base='/_matrix/media/v3')['content_uri']


def wait_for_homeserver(homeserver, deadline_seconds=180):
    deadline = time.monotonic() + deadline_seconds
    while time.monotonic() < deadline:
        try:
            urllib.request.urlopen(
                f'{homeserver.rstrip("/")}/_matrix/client/versions', timeout=5).read()
            return True
        except (urllib.error.URLError, OSError):
            time.sleep(1)
    return False


# WHY EVERY ROOM ENDS AT A DIFFERENT TIME
#
# Every client sorts its room list by the room's most recent activity. If every
# room's newest message carries the same timestamp - which it did, because they
# all defaulted to CORPUS_END - then the entire list is one ~70-way tie, and the
# order is whatever the client's sort does with equal keys. That is not
# something a recording may depend on: a macro clicks the room at a fixed
# position, and a tie broken differently on replay clicks a different room while
# every count still matches.
#
# So each room gets its own end, staggered by hours, with the rooms the scenario
# drives at the top of the list in the order the scenario visits them.
ROOM_END_OFFSET_HOURS = {
    'aurora-release': 0,
    'windvane-deployment': 3,
    'field-photos': 9,
    'parrot-echo': 30,
    'parrot-firehose': 50,
    'parrot-lobby': 70,
}


def room_end(key, index=0):
    """The timestamp of a room's newest message.

    Fillers start well below every named room and step down from there, so the
    five rooms the scenario opens stay at the top of the list.
    """
    if key in ROOM_END_OFFSET_HOURS:
        return CORPUS_END - timedelta(hours=ROOM_END_OFFSET_HOURS[key])
    return CORPUS_END - timedelta(hours=100 + index * 5)


def timeline(count, end=CORPUS_END, start=CORPUS_START):
    """`count` timestamps rising from start to end, the last one at `end`.

    Evenly spaced rather than clustered: the scenario scrolls back through
    history, and evenly spaced messages mean a given number of screens always
    covers the same span of dates.
    """
    if count <= 1:
        return [end]
    # Integer microseconds rather than `start + (end - start) / (count - 1) * i`.
    # Dividing a timedelta rounds to the microsecond, so the accumulated step
    # lands near `end` rather than on it - which would leave the anchor message
    # a few milliseconds short of the timestamp the manifest records, and the
    # last message of a room at an arbitrary time rather than a fixed one.
    span = (end - start) // timedelta(microseconds=1)
    return [start + timedelta(microseconds=span * i // (count - 1))
            for i in range(count)]


def text(index, room_key):
    rng = stable_random(room_key, index)
    return rng.choice(OPENERS).format(rng.choice(WORDS))


def seed_conversation(api, room_id, room_key, senders, count, end=CORPUS_END,
                      final=None, final_sender=None):
    """Fill a room with `count` messages, oldest first.

    `final` is sent last with the newest timestamp, which is what makes it the
    anchor the scenario replies to - it is the message at the bottom when the
    room opens, so no scrolling is needed to reach it.
    """
    when = timeline(count, end=end)
    body_count = count - (1 if final else 0)
    for index in range(body_count):
        sender = senders[index % len(senders)]
        api.send(sender, room_id, {'msgtype': 'm.text', 'body': text(index, room_key)},
                 when[index])
        if body_count > 500 and index % 2000 == 0 and index:
            log(f'  {room_key}: {index}/{body_count}')
    if final:
        api.send(final_sender or senders[0], room_id,
                 {'msgtype': 'm.text', 'body': final}, when[-1])


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n', maxsplit=1)[0])
    parser.add_argument('--homeserver', default='http://localhost:8008')
    parser.add_argument('--as-token', default='parrot-benchmark-appservice-as-token')
    parser.add_argument('--user', default='parrot', help='the account under test')
    parser.add_argument('--bot', default='echo')
    parser.add_argument('--history', type=int, default=8000,
                        help='messages in the busy room (default 8000)')
    parser.add_argument('--photos', type=int, default=400,
                        help='images in the photo room (default 400)')
    parser.add_argument('--members', type=int, default=500,
                        help='members in the busy room (default 500)')
    parser.add_argument('--fillers', type=int, default=60,
                        help='extra rooms, so the room-list filter has work to do')
    parser.add_argument('--manifest', required=True)
    args = parser.parse_args()

    if not wait_for_homeserver(args.homeserver):
        log(f'ERROR: {args.homeserver} never answered')
        return 1

    api = AppService(args.homeserver, args.as_token)
    me = f'@{args.user}:{DOMAIN}'
    bot = f'@{args.bot}:{DOMAIN}'
    manifest = {'rooms': {}, 'anchors': {}, 'corpus_end': CORPUS_END.isoformat()}

    # ----------------------------------------------------------------------
    log('registering the cast')
    # ----------------------------------------------------------------------
    # @parrot and @echo are NOT registered here: they need real passwords, so
    # build.sh creates them with register_new_matrix_user before this runs.  The
    # cast has no password because nothing ever logs in as them - the seeder
    # speaks for them through the application service.
    cast_ids = []
    for localpart, display in CAST:
        api.register(localpart)
        user_id = f'@{localpart}:{DOMAIN}'
        api.set_display_name(user_id, display)
        cast_ids.append(user_id)
    nadia = cast_ids[0]

    crowd = []
    for index in range(args.members):
        localpart = f'member{index:03d}'
        api.register(localpart)
        crowd.append(f'@{localpart}:{DOMAIN}')
        if index % 100 == 0 and index:
            log(f'  members: {index}/{args.members}')

    # ----------------------------------------------------------------------
    log('creating the busy room')
    # ----------------------------------------------------------------------
    # The initial-sync load: deep history and a large member list, which is what
    # separates these clients most sharply.
    busy = api.create_room(nadia, 'Aurora Release',
                           'Release coordination for Aurora 4.2', alias='aurora-release')
    for user_id in crowd + cast_ids[1:] + [me]:
        api.join(user_id, busy)
    log(f'  joined {len(crowd) + len(cast_ids)} members')
    seed_conversation(api, busy, 'aurora', cast_ids, args.history,
                      end=room_end('aurora-release'))
    manifest['rooms']['aurora-release'] = {
        'room_id': busy, 'name': 'Aurora Release',
        'messages': args.history, 'members': len(crowd) + len(cast_ids) + 1,
    }

    # ----------------------------------------------------------------------
    log('creating the photo room')
    # ----------------------------------------------------------------------
    photos = api.create_room(cast_ids[4], 'Field Photos',
                             'Site photography', alias='field-photos')
    for user_id in cast_ids[:4] + [me]:
        api.join(user_id, photos)
    when = timeline(args.photos, end=room_end('field-photos'))
    for index in range(args.photos):
        # The last image is the anchor the scenario opens full size, so it is
        # the newest and sits at the bottom when the room opens.
        is_anchor = index == args.photos - 1
        name = ANCHOR_PHOTO if is_anchor else f'site-{index:04d}.png'
        data = make_png(640, 400, index)
        uri = api.upload(cast_ids[4], data, name)
        api.send(cast_ids[index % 4], photos, {
            'msgtype': 'm.image',
            'body': name,
            'url': uri,
            'info': {'mimetype': 'image/png', 'w': 640, 'h': 400, 'size': len(data)},
        }, when[index])
        if index % 100 == 0 and index:
            log(f'  photos: {index}/{args.photos}')
    manifest['rooms']['field-photos'] = {
        'room_id': photos, 'name': 'Field Photos', 'messages': args.photos,
    }
    manifest['anchors']['photo'] = ANCHOR_PHOTO

    # ----------------------------------------------------------------------
    log('creating the deployment room')
    # ----------------------------------------------------------------------
    # The only room whose name matches the scenario's `windvane` filter, and the
    # room the scenario sends, replies, reacts and edits in.
    windvane = api.create_room(nadia, 'Windvane Deployment',
                               'Windvane rollout', alias='windvane-deployment')
    for user_id in cast_ids[1:5] + [me]:
        api.join(user_id, windvane)
    seed_conversation(api, windvane, 'windvane', cast_ids[:4], 600,
                      end=room_end('windvane-deployment'),
                      final=ANCHOR_WINDVANE, final_sender=nadia)
    manifest['rooms']['windvane-deployment'] = {
        'room_id': windvane, 'name': 'Windvane Deployment', 'messages': 600,
    }
    manifest['anchors']['reply_target'] = {'body': ANCHOR_WINDVANE, 'sender': nadia}

    # ----------------------------------------------------------------------
    log('creating the bot rooms')
    # ----------------------------------------------------------------------
    # Two rooms rather than one so the idle blocks start from an empty timeline:
    # the ping/pong exchange would otherwise sit at the bottom of the room the
    # idle screenshots are taken in.
    echo_room = api.create_room(me, 'Parrot Echo', 'Round-trip checks', alias='parrot-echo')
    api.join(bot, echo_room)
    seed_conversation(api, echo_room, 'echo', [me], 12, end=room_end('parrot-echo'))
    manifest['rooms']['parrot-echo'] = {'room_id': echo_room, 'name': 'Parrot Echo'}

    firehose = api.create_room(me, 'Parrot Firehose', 'Idle measurement',
                               alias='parrot-firehose')
    api.join(bot, firehose)
    # Deliberately almost empty.  The two idle blocks are measured here, and
    # they have to start from the same quiet screen in every client.
    seed_conversation(api, firehose, 'firehose', [me], 3, end=room_end('parrot-firehose'))
    manifest['rooms']['parrot-firehose'] = {'room_id': firehose, 'name': 'Parrot Firehose'}

    # ----------------------------------------------------------------------
    log('creating the public lobby')
    # ----------------------------------------------------------------------
    # @parrot is NOT joined: the scenario joins it, and later leaves it.  If the
    # account were already a member the join block would be a no-op and would
    # still look like it worked.
    lobby = api.create_room(cast_ids[3], 'Parrot Lobby', 'Open room', alias='parrot-lobby')
    for user_id in cast_ids[3:6]:
        api.join(user_id, lobby)
    seed_conversation(api, lobby, 'lobby', cast_ids[3:6], 40, end=room_end('parrot-lobby'))
    manifest['rooms']['parrot-lobby'] = {
        'room_id': lobby, 'name': 'Parrot Lobby', 'parrot_is_member': False,
    }

    # ----------------------------------------------------------------------
    log(f'creating {args.fillers} filler rooms')
    # ----------------------------------------------------------------------
    # The room list has to be long enough that filtering it is real work, and
    # that the scenario's `windvane` filter is discriminating rather than
    # trivially the only entry.  No filler name may contain the filter string.
    filler_names = []
    for index in range(args.fillers):
        rng = stable_random('filler', index)
        name = f'{rng.choice(WORDS).title()} {rng.choice(["Sync", "Standup", "Triage", "Planning", "Ops"])} {index:02d}'
        assert 'windvane' not in name.lower(), name
        creator = cast_ids[index % len(cast_ids)]
        room_id = api.create_room(creator, name, 'Filler')
        # Only members may post. Seeding these with the whole cast while joining
        # nobody but the creator is a 403 from Synapse - which is the right
        # answer, and is why the senders are derived from the joins rather than
        # from the cast list.
        senders = list(dict.fromkeys(
            [creator] + [cast_ids[(index + k) % len(cast_ids)] for k in (1, 2)]))
        for user_id in senders[1:] + [me]:
            api.join(user_id, room_id)
        seed_conversation(api, room_id, f'filler{index}', senders, 20,
                          end=room_end(f'filler{index}', index))
        filler_names.append(name)
        if index % 20 == 0 and index:
            log(f'  fillers: {index}/{args.fillers}')
    manifest['fillers'] = filler_names

    with open(args.manifest, 'w', encoding='utf-8') as handle:
        json.dump(manifest, handle, indent=2, sort_keys=True)
    log(f'wrote {args.manifest}')
    log('seeding complete')
    return 0


if __name__ == '__main__':
    sys.exit(main())
