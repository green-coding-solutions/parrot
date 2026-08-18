#!/usr/bin/env python3
"""Ground truth for the chat-client scenario: what the SERVER thinks happened.

AGENTS.md is blunt about why this exists. Every serious defect in this project
so far produced a passing replay, the right number of checkpoints, the right
number of screenshots, and was visible only on the server. The chat equivalents
of the traps it lists are all real:

  What it looked like                 What may have happened
  --------------------------------    ------------------------------------
  Message appears in the timeline      Still queued locally, never sent - some
                                       clients render optimistically and only
                                       show the failure as a small red icon
  Reaction appears under the message   Sent to the wrong event: the one above,
                                       or the reply rather than its parent
  Edit shows the new text              Sent as a NEW message, not an m.replace
  "Joined" and the timeline renders    Peeked, not joined - public rooms allow
                                       reading without membership
  Room list loses the lobby            Left a different room; counts still fit
  24 drip messages on screen           Some arrived and were never rendered, or
                                       rendered and never scrolled to

Counts do not record identity. `targets` is what covers the wrong-target case -
it resolves the event a reply, reaction or edit actually points AT, and prints
its sender, because that is what separates the anchor (@nadia:parrot.test) from
the reply's quoted copy of it (the account itself). `sent` and `reactions` both
pass when a reaction lands on the reply instead of the anchor, which is a defect
this project has produced before and one that is invisible on screen.

Usage:
    matrix-truth.py --homeserver http://matrix.parrot.test:8008 summary
    matrix-truth.py ... sent --room windvane-deployment --body 'Thank you so much'
    matrix-truth.py ... reactions --room windvane-deployment
    matrix-truth.py ... targets --room windvane-deployment
    matrix-truth.py ... drip
"""

import argparse
import json
import sys
import urllib.error
import urllib.parse
import urllib.request

MANIFEST = '/var/lib/matrix-synapse/corpus-manifest.json'


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
        raise SystemExit(f'{method} {url} -> {error.code}: {detail}')


class Truth:
    def __init__(self, homeserver, user, password):
        self.base = f'{homeserver.rstrip("/")}/_matrix/client/v3'
        result = request('POST', f'{self.base}/login', {
            'type': 'm.login.password',
            'identifier': {'type': 'm.id.user', 'user': user},
            'password': password,
        })
        self.token = result['access_token']
        self.user_id = result['user_id']

    def get(self, path):
        return request('GET', f'{self.base}{path}', token=self.token)

    def joined(self):
        return self.get('/joined_rooms')['joined_rooms']

    def name(self, room_id):
        try:
            return self.get(f'/rooms/{urllib.parse.quote(room_id)}/state/m.room.name')['name']
        except SystemExit:
            return None

    def events(self, room_id, limit=60):
        room = urllib.parse.quote(room_id)
        return self.get(f'/rooms/{room}/messages?dir=b&limit={limit}').get('chunk', [])


def resolve(truth, manifest, key):
    """A room id from the manifest key, or from a name, or passed through."""
    if manifest and key in manifest.get('rooms', {}):
        return manifest['rooms'][key]['room_id']
    if key.startswith('!'):
        return key
    for room_id in truth.joined():
        if (truth.name(room_id) or '').lower() == key.lower():
            return room_id
    raise SystemExit(f'no room matching {key!r}')


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n', maxsplit=1)[0])
    parser.add_argument('--homeserver', default='http://matrix.parrot.test:8008')
    parser.add_argument('--user', default='parrot')
    parser.add_argument('--password', default='parrot')
    parser.add_argument('--manifest', default=MANIFEST,
                        help='corpus manifest, if reachable; room names work without it')
    parser.add_argument('command', choices=['summary', 'sent', 'reactions', 'edits',
                                            'targets', 'drip', 'membership', 'dump'])
    parser.add_argument('--room', default='windvane-deployment')
    parser.add_argument('--body', default=None)
    args = parser.parse_args()

    try:
        with open(args.manifest, encoding='utf-8') as handle:
            manifest = json.load(handle)
    except OSError:
        manifest = None

    truth = Truth(args.homeserver, args.user, args.password)

    if args.command == 'summary':
        rooms = truth.joined()
        print(f'{truth.user_id} is in {len(rooms)} rooms')
        for room_id in rooms:
            name = truth.name(room_id)
            if name and not name.endswith(tuple(str(n) for n in range(10))):
                print(f'  {name:24} {room_id}')
        return 0

    if args.command == 'membership':
        # The join/leave blocks. A public room can be READ without joining, so
        # "the timeline rendered" is not evidence of membership either way.
        rooms = {truth.name(r): r for r in truth.joined()}
        for label in ('Parrot Lobby', 'Parrot benchmark'):
            print(f'  {label:20} {"JOINED" if label in rooms else "not a member"}')
        return 0

    room_id = resolve(truth, manifest, args.room)
    events = truth.events(room_id, 80)

    if args.command == 'sent':
        mine = [e for e in events
                if e['type'] == 'm.room.message' and e['sender'] == truth.user_id]
        print(f'{len(mine)} message(s) from {truth.user_id} in {truth.name(room_id)}')
        for event in mine[:10]:
            content = event['content']
            relates = content.get('m.relates_to') or {}
            kind = 'edit' if relates.get('rel_type') == 'm.replace' else (
                   'reply' if 'm.in_reply_to' in relates else content.get('msgtype', '?'))
            print(f'  [{kind:9}] {content.get("body", "")[:70]!r}')
        if args.body:
            hit = any(e['content'].get('body') == args.body for e in mine)
            print(f'  body {args.body!r}: {"FOUND" if hit else "NOT FOUND"}')
            return 0 if hit else 1
        return 0

    if args.command == 'reactions':
        # Reactions are m.reaction events, not messages, so they never show up
        # in a message count - and the key is what says WHICH emoji landed.
        bodies = {e['event_id']: e.get('content', {}).get('body', '')[:50]
                  for e in events}
        found = [e for e in events if e['type'] == 'm.reaction']
        print(f'{len(found)} reaction(s) in {truth.name(room_id)}')
        for event in found:
            rel = event['content'].get('m.relates_to', {})
            target = rel.get('event_id')
            print(f'  {event["sender"]} reacted {rel.get("key")!r} '
                  f'-> {bodies.get(target, target)!r}')
        return 0 if found else 1

    if args.command == 'edits':
        found = [e for e in events
                 if (e.get('content', {}).get('m.relates_to') or {}).get('rel_type') == 'm.replace']
        print(f'{len(found)} edit(s) in {truth.name(room_id)}')
        for event in found:
            new = (event['content'].get('m.new_content') or {}).get('body')
            print(f'  {event["sender"]} replaced {event["content"]["m.relates_to"]["event_id"]}'
                  f' -> {new!r}')
        return 0 if found else 1

    if args.command == 'drip':
        # The idle-receiving block. Numbering is what makes this checkable:
        # a gap means the bot failed a send, a short tail means the client
        # stopped following the live end.
        room_id = resolve(truth, manifest, 'parrot-firehose')
        events = truth.events(room_id, 60)
        drips = sorted(e['content']['body'] for e in events
                       if e['type'] == 'm.room.message'
                       and e['content'].get('body', '').startswith('drip '))
        print(f'{len(drips)} drip message(s) on the server')
        expected = [f'drip {i:02d}' for i in range(1, len(drips) + 1)]
        if drips == expected and drips:
            print(f'  contiguous: {drips[0]} .. {drips[-1]}')
            return 0
        missing = sorted(set(f'drip {i:02d}' for i in range(1, 25)) - set(drips))
        print(f'  MISSING: {missing[:10]}{" ..." if len(missing) > 10 else ""}')
        return 1

    if args.command == 'targets':
        # WHICH EVENT the account's reply, reaction and edit actually landed on.
        #
        # This is the gap the other commands leave. `reactions` prints the
        # target's BODY, and `sent` only prints that an event was a reply at
        # all - so a reaction attached to the reply's quoted copy of the anchor,
        # rather than to the anchor itself, passes both. That is a real defect
        # this project has produced before, it is invisible on screen, and the
        # sender of the target is what settles it: the anchor is from
        # @nadia:parrot.test, the reply is from the account itself.
        #
        # Targets outside the fetched window are reported as such rather than
        # silently skipped - an unresolvable target is not a passing check.
        by_id = {e['event_id']: e for e in events}

        def describe(event_id):
            target = by_id.get(event_id)
            if target is None:
                return f'(outside the {len(events)}-event window) {event_id}'
            body = (target.get('content') or {}).get('body', '')
            return f'{target["sender"]} :: {target["type"]} :: {body[:60]!r}'

        rows = []
        for event in events:
            if event['sender'] != truth.user_id:
                continue
            relates = (event.get('content') or {}).get('m.relates_to') or {}
            if event['type'] == 'm.reaction' and relates.get('event_id'):
                rows.append(('reaction ' + str(relates.get('key')), relates['event_id']))
            elif relates.get('rel_type') == 'm.replace':
                rows.append(('edit', relates['event_id']))
            elif 'm.in_reply_to' in relates:
                rows.append(('reply', relates['m.in_reply_to'].get('event_id')))

        print(f'{len(rows)} related event(s) from {truth.user_id} '
              f'in {truth.name(room_id)}')
        for kind, event_id in rows:
            print(f'  {kind:12} -> {describe(event_id)}')
        return 0 if rows else 1

    if args.command == 'dump':
        for event in reversed(events):
            print(f'{event["origin_server_ts"]:>15} {event["type"]:<16} '
                  f'{event["sender"]:<28} {json.dumps(event.get("content"))[:90]}')
        return 0

    return 0


if __name__ == '__main__':
    sys.exit(main())
