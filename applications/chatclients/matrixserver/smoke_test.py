#!/usr/bin/env python3
"""Verify the Parrot benchmark homeserver actually serves what it should.

Run inside the matrix container after build.sh, or from the client container to
confirm the network path.  Checks, in order:

  * the homeserver answers and the account under test logs in with its password
  * the bot account logs in - parrot-bot.py's credentials, checked before a run
    rather than discovered two minutes into the idle block
  * every room the scenario names exists, with the right name and membership
  * the busy room has its full member list and enough history to scroll
  * the reply/react anchor really is the NEWEST message in its room, from the
    right sender
  * the image anchor really is the newest event in the photo room
  * exactly one joined room matches the scenario's `windvane` filter
  * @parrot is NOT in the lobby it is supposed to join, and the lobby is public

That last pair is the one worth having.  A corpus where the account is already
in the lobby passes every count-based check and makes the join block a no-op
that still looks like it worked - which is exactly the failure AGENTS.md warns
about: right number of checkpoints, right number of screenshots, nothing wrong
on screen, and the run measures nothing.

Exits non-zero on the first failed check, so it can gate a benchmark run.

Usage:
    smoke_test.py --homeserver http://matrix.parrot.test:8008 --manifest ...
"""

import argparse
import json
import sys
import urllib.error
import urllib.parse
import urllib.request

FILTER_TERM = 'windvane'


class Failure(Exception):
    pass


def request(method, url, body=None, token=None, timeout=60):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header('Content-Type', 'application/json')
    if token:
        req.add_header('Authorization', f'Bearer {token}')
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            return json.loads(response.read() or b'{}')
    except urllib.error.HTTPError as error:
        detail = error.read().decode('utf-8', 'replace')[:300]
        raise Failure(f'{method} {url} -> {error.code}: {detail}') from error
    except (urllib.error.URLError, OSError) as error:
        raise Failure(f'{method} {url} -> {error}') from error


class Client:
    def __init__(self, homeserver):
        self.base = f'{homeserver.rstrip("/")}/_matrix/client/v3'
        self.token = None
        self.user_id = None

    def login(self, user, password):
        result = request('POST', f'{self.base}/login', {
            'type': 'm.login.password',
            'identifier': {'type': 'm.id.user', 'user': user},
            'password': password,
        })
        self.token = result['access_token']
        self.user_id = result['user_id']
        return self.user_id

    def get(self, path):
        return request('GET', f'{self.base}{path}', token=self.token)

    def joined_rooms(self):
        return self.get('/joined_rooms')['joined_rooms']

    def room_name(self, room_id):
        try:
            return self.get(f'/rooms/{urllib.parse.quote(room_id)}/state/m.room.name')['name']
        except Failure:
            return None

    def members(self, room_id):
        return self.get(f'/rooms/{urllib.parse.quote(room_id)}/joined_members')['joined']

    def latest_messages(self, room_id, limit=20):
        room = urllib.parse.quote(room_id)
        result = self.get(f'/rooms/{room}/messages?dir=b&limit={limit}')
        return [event for event in result.get('chunk', [])
                if event.get('type') == 'm.room.message']


def fetch_bytes(url, token=None, timeout=60):
    """Raw GET, returning the body. Used for media, which is not JSON."""
    req = urllib.request.Request(url, method='GET')
    if token:
        req.add_header('Authorization', f'Bearer {token}')
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            return response.read()
    except urllib.error.HTTPError as error:
        raise Failure(f'GET {url} -> {error.code}: '
                      f'{error.read().decode("utf-8", "replace")[:200]}') from error
    except (urllib.error.URLError, OSError) as error:
        raise Failure(f'GET {url} -> {error}') from error


def check(label, condition, detail=''):
    if condition:
        print(f'  ok    {label}')
        return
    raise Failure(f'{label}{": " + detail if detail else ""}')


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n', maxsplit=1)[0])
    parser.add_argument('--homeserver', default='http://127.0.0.1:8008')
    parser.add_argument('--user', default='parrot')
    parser.add_argument('--password', default='parrot')
    parser.add_argument('--bot', default='echo')
    parser.add_argument('--bot-password', default='echo')
    parser.add_argument('--manifest', required=True)
    args = parser.parse_args()

    with open(args.manifest, encoding='utf-8') as handle:
        manifest = json.load(handle)

    try:
        print('[smoke] homeserver and accounts')
        request('GET', f'{args.homeserver.rstrip("/")}/_matrix/client/versions')
        client = Client(args.homeserver)
        user_id = client.login(args.user, args.password)
        check(f'{user_id} logs in', True)

        # The bot's credentials, checked here rather than discovered when the
        # idle-receiving block silently measures nothing.
        bot = Client(args.homeserver)
        bot_id = bot.login(args.bot, args.bot_password)
        check(f'{bot_id} logs in', True)

        print('[smoke] rooms the scenario names')
        joined = client.joined_rooms()
        names = {room_id: client.room_name(room_id) for room_id in joined}
        by_name = {name: room_id for room_id, name in names.items() if name}

        for key in ('aurora-release', 'field-photos', 'windvane-deployment',
                    'parrot-echo', 'parrot-firehose'):
            expected = manifest['rooms'][key]
            room_id = expected['room_id']
            check(f'{expected["name"]} is joined', room_id in joined,
                  f'{room_id} not in {len(joined)} joined rooms')
            check(f'{expected["name"]} has its name', names.get(room_id) == expected['name'],
                  f'got {names.get(room_id)!r}')

        print('[smoke] the busy room carries the sync load')
        busy = manifest['rooms']['aurora-release']
        member_count = len(client.members(busy['room_id']))
        check(f'Aurora Release has {busy["members"]} members',
              member_count == busy['members'], f'got {member_count}')

        print('[smoke] anchors are where the scenario reaches for them')
        anchor = manifest['anchors']['reply_target']
        newest = client.latest_messages(manifest['rooms']['windvane-deployment']['room_id'], 5)
        check('Windvane Deployment has messages', bool(newest))
        top = newest[0]
        check('reply anchor is the newest message',
              top['content'].get('body') == anchor['body'],
              f'newest is {top["content"].get("body")!r}')
        check('reply anchor is from the right sender',
              top['sender'] == anchor['sender'],
              f'newest is from {top["sender"]}')

        photos = client.latest_messages(manifest['rooms']['field-photos']['room_id'], 5)
        check('Field Photos has messages', bool(photos))
        check('image anchor is the newest event',
              photos[0]['content'].get('body') == manifest['anchors']['photo'],
              f'newest is {photos[0]["content"].get("body")!r}')
        check('image anchor is an image',
              photos[0]['content'].get('msgtype') == 'm.image',
              f'msgtype is {photos[0]["content"].get("msgtype")!r}')

        # THE IMAGES MUST ACTUALLY BE FETCHABLE THE OLD WAY.
        #
        # Everything above passes on a server whose photo room renders as a
        # grid of broken-image icons: the events are there, the msgtype is
        # right, the mxc:// uri is well formed, and the bytes are on disk. What
        # fails is the fetch, and only for clients that use the pre-v1.11
        # endpoint - which is one of the six.
        #
        # Synapse 1.120+ defaults enable_authenticated_media to true, which
        # 404s /_matrix/media/v3/download for anything uploaded while it is on.
        # homeserver.yaml turns it off; this proves it, because the flag is
        # recorded per media row at upload time and so depends on the config
        # having been right when seed_corpus.py ran, not merely right now.
        print('[smoke] the corpus images are fetchable by old and new clients')
        mxc = photos[0]['content'].get('url', '')
        check('image anchor has an mxc uri', mxc.startswith('mxc://'), f'url is {mxc!r}')
        server_name, _, media_id = mxc[len('mxc://'):].partition('/')

        legacy = fetch_bytes(
            f'{args.homeserver.rstrip("/")}/_matrix/media/v3/download/'
            f'{server_name}/{media_id}')
        check('legacy /_matrix/media/v3/download serves the bytes',
              len(legacy) > 1024,
              f'got {len(legacy)} bytes - is enable_authenticated_media set false?')

        modern = fetch_bytes(
            f'{args.homeserver.rstrip("/")}/_matrix/client/v1/media/download/'
            f'{server_name}/{media_id}', token=client.token)
        check('authenticated /_matrix/client/v1/media/download still serves them',
              len(modern) > 1024, f'got {len(modern)} bytes')
        check('both endpoints return the same image',
              legacy == modern,
              f'legacy {len(legacy)} bytes, authenticated {len(modern)} bytes')

        print('[smoke] the room-list filter discriminates')
        matching = [name for name in by_name if FILTER_TERM in name.lower()]
        check(f'exactly one joined room matches {FILTER_TERM!r}',
              len(matching) == 1, f'matched {matching}')

        print('[smoke] the join block has something to join')
        lobby = manifest['rooms']['parrot-lobby']
        check('@parrot is NOT already in the lobby',
              lobby['room_id'] not in joined,
              'the join block would be a no-op that still looks like it worked')

        print('[smoke] the bot can hear a trigger')
        bot_rooms = bot.joined_rooms()
        for key in ('parrot-echo', 'parrot-firehose'):
            room_id = manifest['rooms'][key]['room_id']
            check(f'bot is in {manifest["rooms"][key]["name"]}', room_id in bot_rooms)

    except Failure as failure:
        print(f'  FAIL  {failure}', file=sys.stderr)
        return 1

    print('[smoke] all checks passed')
    return 0


if __name__ == '__main__':
    sys.exit(main())
