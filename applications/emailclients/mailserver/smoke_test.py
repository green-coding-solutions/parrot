#!/usr/bin/env python3
"""Verify the Parrot benchmark mail server actually serves what it should.

Run inside the mail container after setup.sh, or from the client container to
confirm the network path.  Checks, in order:

  * IMAP is reachable and the account logs in (plaintext 143 and TLS 993)
  * every folder in the corpus manifest exists with the right message count
  * the SPECIAL-USE flags clients rely on for folder auto-detection are present
  * the search anchors return exactly the documented number of hits
  * the scenario's anchor messages are where the manifest says they are
  * submission works and a sent message is delivered back to the inbox

Exits non-zero on the first failed check, so it can gate a benchmark run.

Usage:
    smoke_test.py --host mail.parrot.test [--skip-smtp] [--ca /srv/ca/parrot-test-ca.crt]
"""

import argparse
import imaplib
import json
import os
import smtplib
import socket
import ssl
import sys
import time
from email.message import EmailMessage

FAILURES = []


def check(label, ok, detail=''):
    mark = 'ok  ' if ok else 'FAIL'
    print(f'[smoke] {mark} {label}' + (f' - {detail}' if detail else ''), flush=True)
    if not ok:
        FAILURES.append(label)
    return ok


def fetched_headers(resp):
    """Pull the raw header block out of an imaplib FETCH response.

    imaplib returns [(b'12 (BODY[HEADER...] {842}', b'<the headers>'), b')'].
    The payload is the second element of the tuple - iterating over the response
    looking for top-level bytes finds only the trailing b')'.
    """
    blob = b''
    for part in resp:
        if isinstance(part, tuple) and len(part) > 1:
            blob += part[1]
    # Unfold continuation lines so a long Subject can be matched in one piece.
    return blob.decode('utf-8', 'replace').replace('\r\n\t', ' ').replace('\r\n ', ' ')


def wait_for_port(host, port, timeout):
    deadline = time.monotonic() + timeout
    last = None
    while time.monotonic() < deadline:
        try:
            with socket.create_connection((host, port), timeout=5):
                return True
        except OSError as exc:
            last = exc
            time.sleep(1)
    print(f'[smoke] port {host}:{port} never opened: {last}', file=sys.stderr)
    return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--host', default=os.environ.get('PARROT_MAIL_HOST', 'mail.parrot.test'))
    ap.add_argument('--user', default=os.environ.get('PARROT_MAIL_USER', 'parrot'))
    ap.add_argument('--password', default=os.environ.get('PARROT_MAIL_PASS', 'parrot'))
    ap.add_argument('--manifest', default='/srv/ca/corpus-manifest.json',
                    help='corpus manifest to check against; skipped if missing')
    ap.add_argument('--ca', default='/srv/ca/parrot-test-ca.crt')
    ap.add_argument('--skip-smtp', action='store_true')
    ap.add_argument('--timeout', type=int, default=120)
    args = ap.parse_args()

    if not check(f'IMAP port 143 open on {args.host}',
                 wait_for_port(args.host, 143, args.timeout)):
        return 1

    # ---- plaintext IMAP login
    imap = imaplib.IMAP4(args.host, 143)
    check('IMAP login (plaintext, port 143)',
          imap.login(args.user, args.password)[0] == 'OK')
    # Dovecot only advertises SPECIAL-USE in the post-authentication capability
    # list, and imaplib caches the pre-auth one from the greeting.
    caps = imap.capability()[1][0].decode('ascii', 'replace').upper().split()
    check('server advertises SPECIAL-USE', 'SPECIAL-USE' in caps,
          f'capabilities: {" ".join(caps[:12])}')

    # ---- folder inventory
    typ, raw = imap.list()
    folders = {}
    for line in raw:
        line = line.decode('utf-8', 'replace')
        # (\HasNoChildren \Sent) "." Sent
        flags = line[line.find('(') + 1:line.find(')')].split()
        name = line.rsplit('"', 2)[-1].strip().strip('"')
        if not name:
            name = line.split()[-1]
        folders[name] = flags
    check('IMAP LIST returned folders', typ == 'OK' and len(folders) > 5,
          f'{len(folders)} folders: {", ".join(sorted(folders)[:8])}...')

    special = {f: fl for f, fl in folders.items()
               if any(x.startswith('\\') and x not in
                      ('\\HasChildren', '\\HasNoChildren', '\\Noselect', '\\Subscribed')
                      for x in fl)}
    for want in ('Sent', 'Drafts', 'Trash', 'Junk', 'Archive'):
        check(f'SPECIAL-USE flag on {want}',
              want in special, f'flags: {special.get(want)}')

    # The manifest is optional: run from the client container, where the corpus
    # does not exist, and the folder-count and anchor checks are simply skipped.
    manifest = None
    try:
        with open(args.manifest, encoding='utf-8') as fh:
            manifest = json.load(fh)
    except (OSError, ValueError) as exc:
        print(f'[smoke] no usable manifest at {args.manifest} ({exc.__class__.__name__}) - '
              f'skipping folder counts, search anchors and message positions')

    # ---- message counts per folder
    if manifest:
        total = 0
        for imap_name, stats in sorted(manifest['folders'].items()):
            mbox = imap_name if imap_name == 'INBOX' else imap_name.replace('/', '.')
            typ, data = imap.select(f'"{mbox}"', readonly=True)
            got = int(data[0]) if typ == 'OK' else -1
            total += max(0, got)
            check(f'{imap_name} holds {stats["messages"]} messages',
                  got == stats['messages'], f'server reports {got}')
            if stats['unread']:
                typ, data = imap.search(None, 'UNSEEN')
                n_unseen = len(data[0].split()) if typ == 'OK' else -1
                check(f'{imap_name} has {stats["unread"]} unread',
                      n_unseen == stats['unread'], f'server reports {n_unseen}')
        check(f'total message count is {manifest["total_messages"]}',
              total == manifest['total_messages'], f'counted {total}')
        print(f'[smoke] corpus is {manifest["total_mib"]} MiB '
              f'across {len(manifest["folders"])} folders', flush=True)

        # ---- search anchors
        anchors = manifest['anchors']
        term = anchors['search']['term']
        body_hits = 0
        subj_hits = 0
        for imap_name in sorted(manifest['folders']):
            mbox = imap_name if imap_name == 'INBOX' else imap_name.replace('/', '.')
            imap.select(f'"{mbox}"', readonly=True)
            typ, data = imap.search(None, 'BODY', f'"{term}"')
            if typ == 'OK' and data[0]:
                body_hits += len(data[0].split())
            typ, data = imap.search(None, 'SUBJECT', f'"{term}"')
            if typ == 'OK' and data[0]:
                subj_hits += len(data[0].split())
        check(f'full-text search for "{term}" returns '
              f'{anchors["search"]["expected_hits_full_text"]} hits',
              body_hits == anchors['search']['expected_hits_full_text'],
              f'got {body_hits}')
        check(f'subject search for "{term}" returns '
              f'{anchors["search"]["expected_hits_subject_only"]} hits',
              subj_hits == anchors['search']['expected_hits_subject_only'],
              f'got {subj_hits}')

        # ---- anchor messages are at the documented inbox positions
        # "Position from the top" means what every client shows by default:
        # newest sent date first.  That is a sort, not IMAP sequence order -
        # unread messages sit in the maildir's new/ directory and get their
        # UIDs after the read ones, so sequence order is not date order.
        imap.select('INBOX', readonly=True)
        typ, data = imap.sort('(REVERSE DATE)', 'UTF-8', 'ALL')
        ordered = data[0].split() if typ == 'OK' else []
        check('server supports SORT (REVERSE DATE) on INBOX',
              len(ordered) == manifest['folders']['INBOX']['messages'],
              f'sorted {len(ordered)} messages')
        for key in ('newest_inbox', 'reply_target', 'largest', 'pdf_attachment'):
            a = anchors[key]
            pos = a['position_from_top']
            if len(ordered) < pos:
                check(f'anchor "{key}" is #{pos} newest in INBOX', False,
                      f'INBOX only reported {len(ordered)} messages')
                continue
            seq = ordered[pos - 1]
            hdr = fetched_headers(imap.fetch(seq, '(BODY.PEEK[HEADER.FIELDS (SUBJECT FROM)])')[1])
            check(f'anchor "{key}" is #{pos} newest in INBOX',
                  a['subject'] in hdr and a['from'] in hdr,
                  f'expected {a["subject"]!r} from {a["from"]}')

    imap.logout()

    # ---- TLS
    if wait_for_port(args.host, 993, 20):
        ctx = ssl.create_default_context()
        if os.path.exists(args.ca):
            ctx.load_verify_locations(args.ca)
            verified = 'against the benchmark CA'
        else:
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE
            verified = 'unverified (CA file not present)'
        try:
            imaps = imaplib.IMAP4_SSL(args.host, 993, ssl_context=ctx)
            check(f'IMAPS login on 993, certificate {verified}',
                  imaps.login(args.user, args.password)[0] == 'OK')
            imaps.logout()
        except Exception as exc:                              # noqa: BLE001
            check('IMAPS login on 993', False, repr(exc))
    else:
        check('IMAPS port 993 open', False)

    # ---- submission round trip
    if not args.skip_smtp:
        if wait_for_port(args.host, 587, 30):
            try:
                imap = imaplib.IMAP4(args.host, 143)
                imap.login(args.user, args.password)
                imap.select('INBOX', readonly=True)
                before = int(imap.select('INBOX', readonly=True)[1][0])

                token = 'parrot-smoke-test-delivery'
                msg = EmailMessage()
                msg['From'] = f'{args.user}@parrot.test'
                msg['To'] = 'alice.brenner@parrot.test'
                msg['Subject'] = f'{token} check'
                msg.set_content('Sent by smoke_test.py to prove submission and '
                                'local delivery work.')

                smtp = smtplib.SMTP(args.host, 587, timeout=30)
                smtp.ehlo()
                smtp.starttls(context=ssl.create_default_context(cafile=args.ca)
                              if os.path.exists(args.ca) else ssl._create_unverified_context())
                smtp.ehlo()
                smtp.login(args.user, args.password)
                smtp.send_message(msg)
                smtp.quit()
                check('submission on 587 with STARTTLS + SASL accepted the message', True)

                delivered = False
                for _ in range(30):
                    time.sleep(1)
                    imap.select('INBOX')
                    typ, data = imap.search(None, 'SUBJECT', f'"{token}"')
                    if typ == 'OK' and data[0]:
                        delivered = True
                        break
                check('sent message was delivered back into INBOX', delivered,
                      f'inbox held {before} messages before sending')

                # Remove it again.  A leftover message would sit at the top of
                # the inbox and shift every anchor position by one, breaking
                # macros recorded against the documented layout.
                if delivered:
                    for num in data[0].split():
                        imap.store(num, '+FLAGS', '\\Deleted')
                    imap.expunge()
                    imap.select('INBOX', readonly=True)
                    after = int(imap.select('INBOX', readonly=True)[1][0])
                    check('smoke-test message cleaned up, inbox back to '
                          f'{before} messages', after == before,
                          f'inbox now holds {after}')
                imap.logout()
            except Exception as exc:                          # noqa: BLE001
                check('submission round trip', False, repr(exc))
        else:
            check('submission port 587 open', False)

    print()
    if FAILURES:
        print(f'[smoke] {len(FAILURES)} check(s) FAILED:', file=sys.stderr)
        for f in FAILURES:
            print(f'  - {f}', file=sys.stderr)
        return 1
    print('[smoke] all checks passed')
    return 0


if __name__ == '__main__':
    sys.exit(main())
