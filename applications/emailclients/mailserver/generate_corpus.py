#!/usr/bin/env python3
"""Generate a deterministic Maildir++ corpus for the Parrot email-client benchmark.

The corpus is byte-for-byte identical on every run: every random choice is
derived from a fixed seed plus the message's own coordinates (folder + index),
and every date comes from a fixed epoch instead of the wall clock.  That means
a benchmark recorded against this corpus replays identically weeks later and on
another machine.

Total on-disk size is driven to ``--target-mb`` (default 500) by sizing the
attachments: the generator first measures how many bytes the message text needs,
then spreads the remaining budget over the attachment-bearing messages.

Attachments are real, openable files - PDFs with selectable text, valid PNGs,
real ZIP archives, CSV and log files - because the usage scenario opens some of
them in the client under test.

Usage:
    generate_corpus.py --root /home/parrot/Maildir --target-mb 500
"""

import argparse
import base64
import binascii
import hashlib
import json
import os
import random
import shutil
import struct
import sys
import time
import zlib
from datetime import datetime, timedelta, timezone

# --------------------------------------------------------------------------
# Determinism anchors.  Nothing in this file may read the wall clock.
# --------------------------------------------------------------------------

SEED = 'parrot-email-benchmark-v1'

# The corpus is frozen in time.  Keeping the newest message in the past is
# deliberate: clients render "today" and "yesterday" as relative labels, which
# would make screenshot assertions rot.  With every date in the past, every
# client always renders an absolute date.
CORPUS_END = datetime(2026, 6, 30, 17, 42, 11, tzinfo=timezone.utc)
CORPUS_START = datetime(2023, 1, 9, 8, 15, 0, tzinfo=timezone.utc)

MAILDIR_HOSTNAME = 'mail.parrot.test'
ACCOUNT = 'parrot@parrot.test'
ACCOUNT_NAME = 'Robin Parrot'

# The scenario searches for this token.  It must appear nowhere else in the
# corpus - not as a project name, not inside a persona's domain - so the result
# count is a stable assertion.  It is planted in the body of SEARCH_TERM_HITS
# messages, and additionally in the subject of SEARCH_TERM_SUBJECT_HITS of
# those, so clients that only search subjects also return a known number.
SEARCH_TERM = 'Windvane'
SEARCH_TERM_HITS = 9
SEARCH_TERM_SUBJECT_HITS = 3

# --------------------------------------------------------------------------
# Personas.  Local ones (@parrot.test) are aliased to the benchmark account by
# Postfix, so mail the scenario sends to them is delivered back and shows up.
# --------------------------------------------------------------------------

PEOPLE = [
    ('Nadia Oyelaran', 'nadia.oyelaran@aurora-labs.test'),
    ('Tomas Brekke', 'tomas.brekke@aurora-labs.test'),
    ('Priya Raghunathan', 'priya.raghunathan@aurora-labs.test'),
    ('Ines Almeida', 'ines.almeida@borealis-systems.test'),
    ('Karl Wiedemann', 'karl.wiedemann@borealis-systems.test'),
    ('Fatima Zahra Idrissi', 'fatima.idrissi@borealis-systems.test'),
    ('Hiroshi Nakamura', 'hiroshi.nakamura@harrier-freight.test'),
    ('Lena Vogt', 'lena.vogt@harrier-freight.test'),
    ('Dmitri Sokolov', 'dmitri.sokolov@northwind-hosting.test'),
    ('Amara Nwosu', 'amara.nwosu@northwind-hosting.test'),
    ('Jonas Lindqvist', 'jonas.lindqvist@meridian-audit.test'),
    ('Chen Wei', 'chen.wei@meridian-audit.test'),
    ('Sofia Kovač', 'sofia.kovac@meridian-audit.test'),
    ('Alice Brenner', 'alice.brenner@parrot.test'),
    ('Ben Okonkwo', 'ben.okonkwo@parrot.test'),
    ('Clara Mendes', 'clara.mendes@parrot.test'),
    ('Deniz Aydın', 'deniz.aydin@parrot.test'),
    ('Eero Virtanen', 'eero.virtanen@parrot.test'),
    ('Grace Oduya', 'grace.oduya@parrot.test'),
    ('Henrik Solberg', 'henrik.solberg@parrot.test'),
]

# Sender of the newest inbox message and of a deliberately large share of the
# inbox, so "sort by sender" and "filter by sender" have a visible effect.
PRIMARY_CORRESPONDENT = PEOPLE[0]

MAILING_LISTS = {
    'Lists/parrot-dev': ('parrot-dev', 'parrot-dev@lists.parrot.test'),
    'Lists/announce': ('parrot-announce', 'announce@lists.parrot.test'),
}

# --------------------------------------------------------------------------
# Vocabulary for message text.  Kept inline so the generator needs no network
# and no data files.
# --------------------------------------------------------------------------

PROJECTS = ['Aurora', 'Borealis', 'Cascade', 'Meridian', 'Northwind', 'Solstice']

SUBJECT_TEMPLATES = [
    'Release checklist for {project} {ver}',
    '{project}: staging deploy failed on {day}',
    'Review request: {project} migration plan',
    'Notes from the {project} sync ({date})',
    'Budget approval needed for {project} hardware',
    'Re: onboarding docs for the {project} team',
    '{project} incident postmortem draft',
    'Invoice {inv} - {project} consulting',
    'Quarterly infrastructure review for {project}',
    'Can you look at the {project} latency graphs?',
    '{project} sprint {num} retrospective',
    'Access request: {project} staging cluster',
    'Draft agenda - {project} steering committee',
    '{project} dependency bump ({num} packages)',
    'Follow-up on the {project} security audit',
    'Timesheet reminder for week {num}',
    '{project} contract renewal - decision needed',
    'New starter paperwork for the {project} rotation',
    '{project} capacity planning numbers',
    'Please confirm attendance: {project} workshop',
    'Backup verification report - {project}',
    '{project} API deprecation timeline',
    'Travel booking for the {project} offsite',
    'Signed NDA attached - {project}',
    '{project} customer escalation #{num}',
]

LIST_SUBJECT_TEMPLATES = [
    '[PATCH {num}/{den}] {area}: fix {thing} handling',
    '[PATCH] {area}: avoid {thing} on shutdown',
    'Re: [RFC] rework the {area} {thing} interface',
    'Re: [PATCH {num}/{den}] {area}: fix {thing} handling',
    'Build failure in {area} on {distro}',
    '{area} test suite is flaky again',
    'Proposal: drop support for {distro}',
    'Re: Build failure in {area} on {distro}',
    'Release {ver} tagged',
    'Weekly {area} triage summary',
    'Question about {thing} lifetimes in {area}',
    'Re: Question about {thing} lifetimes in {area}',
    'Heads up: {thing} API changes in {ver}',
]

AREAS = ['storage', 'net', 'imap', 'ui', 'crypto', 'indexer', 'sched', 'parser', 'cache', 'sync']
THINGS = ['buffer', 'timeout', 'refcount', 'mailbox', 'iterator', 'socket', 'token', 'session',
          'checksum', 'quota', 'header', 'envelope', 'thread', 'cursor', 'lock']
DISTROS = ['Debian 12', 'Ubuntu 24.04', 'Fedora 41', 'Alpine 3.20', 'openSUSE Leap 15.6', 'FreeBSD 14']

SENTENCES = [
    'Thanks for the quick turnaround on this.',
    'I have pushed the branch and CI is green apart from the flaky integration test.',
    'Could you double check the numbers in the third column before we send it on?',
    'The staging cluster was rebuilt this morning, so old credentials will no longer work.',
    'We agreed to postpone the migration until after the audit closes.',
    'Attaching the signed copy for your records.',
    'Let me know if you would rather discuss this on a call.',
    'The latency regression turned out to be a missing index, not the new cache layer.',
    'Please do not forward this outside the working group.',
    'I have booked the small meeting room for Thursday afternoon.',
    'Two of the three blockers are resolved; the last one needs a decision from finance.',
    'Sorry for the delay, I was out sick for most of last week.',
    'The report is generated nightly and the archive keeps ninety days of history.',
    'Can we move the deadline by a week? The vendor has not confirmed yet.',
    'I looked through the logs and the errors all start after the certificate rotation.',
    'Adding Priya, who owns the deployment pipeline these days.',
    'This is the third time the backup job has failed silently.',
    'The proposal looks reasonable to me, with one caveat about the rollback path.',
    'Numbers below are rounded to the nearest thousand.',
    'I would prefer we keep the old endpoint alive for one more release.',
    'Nothing urgent, but it would be good to close this out before the quarter ends.',
    'Confirmed on my side, feel free to go ahead.',
    'The customer is asking for a written timeline by Friday.',
    'I disagree, but not strongly enough to block it.',
    'We should write this down somewhere more permanent than a mail thread.',
    'The invoice references the wrong purchase order number.',
    'After the upgrade the memory footprint dropped by about a third.',
    'Reminder that the office is closed on Monday.',
    'I have asked the vendor for a firmware changelog.',
    'Please reply to all so the archive keeps a record.',
    'That matches what I measured locally, within noise.',
    'The rollout is paused until we understand the disk pressure alerts.',
]

LIST_SENTENCES = [
    'The current code takes the lock before checking the refcount, which inverts the ordering used everywhere else.',
    'No functional change intended.',
    'Tested on x86_64 and aarch64; the arm build needed the extra barrier.',
    'This has been broken since the rework landed two releases ago.',
    'I can reproduce it reliably with a mailbox of about ten thousand messages.',
    'Reviewed-by is welcome, but please look closely at the error path.',
    'The allocation is short-lived so a stack buffer is fine here.',
    'valgrind is quiet after the patch, and noisy before it.',
    'Fixes a use-after-free that only triggers when the connection drops mid-fetch.',
    'I kept the old symbol as a deprecated alias for one cycle.',
    'The test needs a real server, so it is skipped unless the fixture is present.',
    'Please hold off merging until the release branch is cut.',
    'Series applies cleanly on top of main as of this morning.',
    'This is a follow-up to the discussion in the previous thread.',
    'The overhead is around two percent on the synthetic benchmark, which seems acceptable.',
    'I would rather fix the caller than paper over it here.',
    'Dropping the workaround entirely would break the older protocol path.',
    'Splitting this into two patches made the diff much easier to read.',
]

CLOSINGS = ['Best regards', 'Cheers', 'Thanks', 'Kind regards', 'All the best', 'Regards', 'Best']

# --------------------------------------------------------------------------
# Folder plan.  Names are IMAP names; Maildir++ paths are derived from them.
# --------------------------------------------------------------------------

FOLDERS = [
    # (imap name, message count, fraction with attachments, unread fraction, kind)
    ('INBOX',            2100, 0.055, 0.030, 'mail'),
    ('Archive/2023',     1650, 0.040, 0.000, 'mail'),
    ('Archive/2024',     1850, 0.045, 0.000, 'mail'),
    ('Archive/2025',     1500, 0.050, 0.000, 'mail'),
    ('Sent',              940, 0.060, 0.000, 'sent'),
    ('Drafts',             11, 0.090, 0.000, 'draft'),
    ('Junk',              260, 0.020, 0.700, 'junk'),
    ('Trash',             130, 0.030, 0.100, 'mail'),
    ('Lists/parrot-dev', 3600, 0.004, 0.120, 'list'),
    ('Lists/announce',    520, 0.010, 0.040, 'list'),
    ('Projects/Aurora',   540, 0.070, 0.000, 'mail'),
    ('Projects/Borealis', 380, 0.070, 0.000, 'mail'),
]

# Folders that exist but hold no mail of their own (pure hierarchy parents).
CONTAINER_FOLDERS = ['Archive', 'Lists', 'Projects']

SPECIAL_USE = {
    'Drafts': '\\Drafts',
    'Sent': '\\Sent',
    'Trash': '\\Trash',
    'Junk': '\\Junk',
    'Archive': '\\Archive',
}

ATTACH_KINDS = [
    ('pdf', 0.40),
    ('png', 0.28),
    ('zip', 0.14),
    ('csv', 0.10),
    ('log', 0.08),
]


def rng_for(*parts):
    """A RNG seeded only by its coordinates, so any message can be regenerated
    in isolation and in any order."""
    key = SEED + '|' + '|'.join(str(p) for p in parts)
    digest = hashlib.blake2b(key.encode('utf-8'), digest_size=16).digest()
    return random.Random(int.from_bytes(digest, 'big'))


# --------------------------------------------------------------------------
# Real attachment payloads
# --------------------------------------------------------------------------

def _pdf_escape(text):
    return text.replace('\\', r'\\').replace('(', r'\(').replace(')', r'\)')


def make_pdf(rng, target_bytes, title):
    """A valid multi-page PDF with selectable text, grown to ~target_bytes."""
    lines_per_page = 44
    pages = []
    page_no = 0
    approx = 0
    # Rough per-page cost, used only to decide how many pages to emit.
    while approx < target_bytes and page_no < 4000:
        page_no += 1
        body = []
        body.append(f'BT /F1 16 Tf 56 760 Td ({_pdf_escape(title)}) Tj ET')
        body.append(f'BT /F1 9 Tf 56 742 Td (Page {page_no} - generated for the Parrot email benchmark) Tj ET')
        y = 712
        for _ in range(lines_per_page):
            words = [rng.choice(SENTENCES).split() for _ in range(2)]
            flat = [w for chunk in words for w in chunk]
            line = ' '.join(flat[: rng.randint(9, 14)])
            body.append(f'BT /F1 10.5 Tf 56 {y} Td ({_pdf_escape(line)}) Tj ET')
            y -= 15
        stream = '\n'.join(body).encode('latin-1', 'replace')
        pages.append(stream)
        approx += len(stream) + 220

    objects = []          # 1-based list of object payloads (bytes)
    font_obj = None
    # Object layout: 1=Catalog, 2=Pages, then per page (Page, Contents), then Font.
    n_pages = len(pages)
    font_num = 3 + 2 * n_pages
    kids = ' '.join(f'{3 + 2 * i} 0 R' for i in range(n_pages))

    objects.append(b'<< /Type /Catalog /Pages 2 0 R >>')
    objects.append(f'<< /Type /Pages /Count {n_pages} /Kids [{kids}] >>'.encode())
    for i, stream in enumerate(pages):
        page_num = 3 + 2 * i
        contents_num = page_num + 1
        objects.append(
            f'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
            f'/Resources << /Font << /F1 {font_num} 0 R >> >> '
            f'/Contents {contents_num} 0 R >>'.encode()
        )
        objects.append(b'<< /Length ' + str(len(stream)).encode() + b' >>\nstream\n' + stream + b'\nendstream')
    objects.append(b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>')
    del font_obj

    out = bytearray(b'%PDF-1.4\n%\xe2\xe3\xcf\xd3\n')
    offsets = []
    for num, payload in enumerate(objects, start=1):
        offsets.append(len(out))
        out += f'{num} 0 obj\n'.encode() + payload + b'\nendobj\n'
    xref_at = len(out)
    out += f'xref\n0 {len(objects) + 1}\n'.encode()
    out += b'0000000000 65535 f \n'
    for off in offsets:
        out += f'{off:010d} 00000 n \n'.encode()
    out += (
        f'trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\nstartxref\n{xref_at}\n%%EOF\n'
    ).encode()
    return bytes(out)


def make_png(rng, target_bytes, label):
    """A valid RGB PNG.  Noise pixels barely compress, so the encoded size
    tracks the pixel count closely and the target is easy to hit."""
    # 3 bytes/pixel + 1 filter byte per row, and zlib gains little on noise.
    px = max(600, int(target_bytes / 3.05))
    width = max(24, int(px ** 0.5))
    height = max(24, px // width)

    raw = bytearray()
    base = rng.randrange(0, 1 << 30)
    for y in range(height):
        raw.append(0)
        row = bytearray()
        # Smooth gradient plus per-row noise: looks like a photo histogram-wise
        # while staying incompressible enough to be size-predictable.
        noise = rng.randbytes(width * 3)
        for x in range(width):
            i = x * 3
            row.append((base + x * 2 + y) % 251 // 2 + noise[i] // 3)
            row.append((x + y * 3) % 241 // 2 + noise[i + 1] // 3)
            row.append((base // 7 + x + y) % 233 // 2 + noise[i + 2] // 3)
        raw += row
    del label

    def chunk(kind, data):
        return (struct.pack('>I', len(data)) + kind + data
                + struct.pack('>I', binascii.crc32(kind + data) & 0xFFFFFFFF))

    header = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
    return (b'\x89PNG\r\n\x1a\n'
            + chunk(b'IHDR', header)
            + chunk(b'IDAT', zlib.compress(bytes(raw), 6))
            + chunk(b'IEND', b''))


def make_csv(rng, target_bytes, label):
    rows = ['date,region,project,requests,errors,p95_ms,cost_eur']
    regions = ['eu-central', 'eu-west', 'us-east', 'us-west', 'ap-south', 'ap-northeast']
    day = CORPUS_START
    while sum(len(r) + 1 for r in rows) < target_bytes:
        day += timedelta(hours=6)
        rows.append('{},{},{},{},{},{},{:.2f}'.format(
            day.strftime('%Y-%m-%d'), rng.choice(regions), rng.choice(PROJECTS),
            rng.randint(10_000, 9_000_000), rng.randint(0, 4200),
            rng.randint(38, 4300), rng.uniform(1.5, 980.0)))
    del label
    return ('\n'.join(rows) + '\n').encode()


def make_log(rng, target_bytes, label):
    levels = ['INFO', 'INFO', 'INFO', 'DEBUG', 'WARN', 'ERROR']
    out = []
    t = CORPUS_START
    total = 0
    while total < target_bytes:
        t += timedelta(milliseconds=rng.randint(3, 900))
        line = '{} {:<5} [{}] {} took {}ms ({} bytes)'.format(
            t.strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3], rng.choice(levels),
            rng.choice(AREAS), rng.choice(THINGS),
            rng.randint(0, 8400), rng.randint(64, 4_000_000))
        out.append(line)
        total += len(line) + 1
    del label
    return ('\n'.join(out) + '\n').encode()


def make_zip(rng, target_bytes, label):
    """ZIP_STORED so the archive size is a predictable function of its members."""
    import io
    import zipfile
    buf = io.BytesIO()
    n = rng.randint(3, 9)
    per = max(256, target_bytes // n)
    with zipfile.ZipFile(buf, 'w', compression=zipfile.ZIP_STORED) as zf:
        for i in range(n):
            kind = rng.choice(['csv', 'log', 'png'])
            if kind == 'csv':
                data, ext = make_csv(rng, per, label), 'csv'
            elif kind == 'log':
                data, ext = make_log(rng, per, label), 'log'
            else:
                data, ext = make_png(rng, per, label), 'png'
            info = zipfile.ZipInfo(f'{label}/part-{i + 1:02d}.{ext}', date_time=(2025, 3, 4, 10, 0, 0))
            zf.writestr(info, data)
    return buf.getvalue()


ATTACH_BUILDERS = {'pdf': make_pdf, 'png': make_png, 'csv': make_csv, 'log': make_log, 'zip': make_zip}
ATTACH_MIME = {
    'pdf': 'application/pdf',
    'png': 'image/png',
    'csv': 'text/csv',
    'log': 'text/plain',
    'zip': 'application/zip',
}


def attach_filename(rng, kind, project):
    stem = rng.choice([
        f'{project.lower()}-report-{rng.randint(2023, 2026)}-Q{rng.randint(1, 4)}',
        f'{project.lower()}-{rng.choice(AREAS)}-metrics',
        f'{rng.choice(["invoice", "contract", "minutes", "proposal", "audit"])}-{rng.randint(10000, 99999)}',
        f'{project.lower()}-{rng.choice(["capacity", "latency", "budget", "rollout"])}-plan',
        f'screenshot-{rng.randint(2024, 2026)}-{rng.randint(1, 12):02d}-{rng.randint(1, 28):02d}',
    ])
    return f'{stem}.{kind}'


# --------------------------------------------------------------------------
# Message text
# --------------------------------------------------------------------------

def pick_subject(rng, kind, project):
    if kind == 'list':
        tpl = rng.choice(LIST_SUBJECT_TEMPLATES)
    else:
        tpl = rng.choice(SUBJECT_TEMPLATES)
    num = rng.randint(1, 40)
    return tpl.format(
        project=project, ver=f'{rng.randint(1, 9)}.{rng.randint(0, 9)}',
        day=rng.choice(['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']),
        date=f'{rng.randint(1, 28)}.{rng.randint(1, 12)}.', inv=f'{rng.randint(20230, 20269)}-{num:03d}',
        num=num, den=rng.randint(num, num + 6), area=rng.choice(AREAS),
        thing=rng.choice(THINGS), distro=rng.choice(DISTROS))


def build_body(rng, kind, sender_name, subject, project, plant_term, quote_from=None):
    """Return (plain_text, html).  Sizes land around 2-9 kB of plain text."""
    pool = LIST_SENTENCES + SENTENCES if kind == 'list' else SENTENCES
    n_paras = rng.randint(2, 6)
    paras = []
    for _ in range(n_paras):
        n_sent = rng.randint(2, 6)
        paras.append(' '.join(rng.choice(pool) for _ in range(n_sent)))

    if plant_term:
        i = rng.randrange(len(paras))
        paras[i] += (f' The {SEARCH_TERM} rollout is the one blocker I still care about, '
                     f'so please keep {SEARCH_TERM} on the agenda.')

    if kind == 'list' and rng.random() < 0.45:
        paras.insert(0, 'On the earlier point:')

    greeting = rng.choice(['Hi', 'Hello', 'Hey', 'Morning', 'Hi all'])
    who = 'all' if kind == 'list' else ACCOUNT_NAME.split()[0]
    lines = [f'{greeting} {who},', '']
    for p in paras:
        lines += [p, '']

    if quote_from:
        lines += [f'On an earlier date, {quote_from} wrote:']
        for _ in range(rng.randint(3, 9)):
            lines.append('> ' + rng.choice(pool))
        lines.append('')

    lines += [f'{rng.choice(CLOSINGS)},', sender_name.split()[0], '']
    if kind == 'list':
        lines += ['--', f'{sender_name} <{project.lower()}@lists.parrot.test>',
                  'To unsubscribe, mail the -request address.', '']
    plain = '\r\n'.join(lines)

    esc = (lambda s: s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;'))
    html_paras = ''.join(f'<p>{esc(p)}</p>' for p in paras)
    html = (
        '<!DOCTYPE html><html><head><meta charset="utf-8">'
        '<style>body{font-family:Helvetica,Arial,sans-serif;font-size:14px;color:#222;line-height:1.45}'
        'blockquote{border-left:2px solid #ccd;margin:0 0 0 8px;padding-left:10px;color:#556}'
        '.sig{color:#777;font-size:12px}</style></head><body>'
        f'<p>{esc(greeting)} {esc(who)},</p>{html_paras}'
        f'<p class="sig">{esc(rng.choice(CLOSINGS))},<br>{esc(sender_name.split()[0])}</p>'
        f'<p class="sig">{esc(subject)}</p></body></html>'
    )
    return plain, html


# --------------------------------------------------------------------------
# MIME assembly (hand-rolled so header order and boundaries are deterministic;
# email.generator would reorder and re-fold some of this)
# --------------------------------------------------------------------------

def rfc2047(text):
    """Encode a display name only when it is not pure ASCII."""
    try:
        text.encode('ascii')
        return text
    except UnicodeEncodeError:
        return '=?UTF-8?B?' + base64.b64encode(text.encode('utf-8')).decode('ascii') + '?='


def addr(name, email):
    return f'"{rfc2047(name)}" <{email}>'


def fold(header, value):
    """Fold a long header at 76 columns on space boundaries."""
    line = f'{header}: {value}'
    if len(line) <= 76:
        return line
    out, cur = [], ''
    for word in line.split(' '):
        if cur and len(cur) + 1 + len(word) > 74:
            out.append(cur)
            cur = '\t' + word
        else:
            cur = word if not cur else cur + ' ' + word
    out.append(cur)
    return '\r\n'.join(out)


def b64_body(data):
    enc = base64.b64encode(data)
    return b'\r\n'.join(enc[i:i + 76] for i in range(0, len(enc), 76)) + b'\r\n'


def qp_encode(text):
    """Quoted-printable for the text parts, matching what a real MUA sends.

    Soft line breaks are placed before a space rather than mid-word.  That is
    what real MUAs do, and it matters here: a word split across a soft break
    would still be found by a server-side IMAP SEARCH, but not by a plain grep
    over the corpus - which is how the search anchors are verified.
    """
    LIMIT = 74
    out = []
    for line in text.split('\r\n'):
        buf = ''
        for ch in line:
            o = ord(ch)
            if ch == '=' or o < 32 or o > 126:
                for b in ch.encode('utf-8'):
                    buf += f'={b:02X}'
            else:
                buf += ch
        while len(buf) > LIMIT:
            cut = buf.rfind(' ', 1, LIMIT)
            if cut <= 0:
                # No space to break on: fall back to a hard cut that does not
                # land inside an =XX escape sequence.
                cut = LIMIT
                while cut > 1 and (buf[cut - 1] == '=' or buf[cut - 2:cut - 1] == '='):
                    cut -= 1
            out.append(buf[:cut] + '=')
            buf = buf[cut:]
        out.append(buf)
    return '\r\n'.join(out)


def build_message(rng, meta, attachments):
    """attachments: list of (filename, mime, bytes).  Returns full RFC5322 bytes."""
    boundary_mixed = 'p=_mixed_{:032x}'.format(rng.getrandbits(128))
    boundary_alt = 'p=_alt_{:032x}'.format(rng.getrandbits(128))

    h = []
    h.append(fold('Return-Path', f'<{meta["from_email"]}>'))
    h.append(fold('Received', f'from {meta["helo"]} (localhost [127.0.0.1]) by {MAILDIR_HOSTNAME} '
                              f'with ESMTP id {meta["msgid_local"][:16]}; {meta["date_hdr"]}'))
    h.append(fold('Date', meta['date_hdr']))
    h.append(fold('From', addr(meta['from_name'], meta['from_email'])))
    h.append(fold('To', ', '.join(addr(n, e) for n, e in meta['to'])))
    if meta.get('cc'):
        h.append(fold('Cc', ', '.join(addr(n, e) for n, e in meta['cc'])))
    h.append(fold('Subject', rfc2047(meta['subject'])))
    h.append(fold('Message-ID', f'<{meta["msgid_local"]}@{meta["msgid_domain"]}>'))
    if meta.get('in_reply_to'):
        h.append(fold('In-Reply-To', meta['in_reply_to']))
        h.append(fold('References', ' '.join(meta['references'])))
    if meta.get('list_id'):
        h.append(fold('List-Id', f'<{meta["list_id"]}.lists.parrot.test>'))
        h.append(fold('List-Post', f'<mailto:{meta["list_post"]}>'))
        h.append(fold('List-Unsubscribe', f'<mailto:{meta["list_post"]}-request@lists.parrot.test>'))
        h.append(fold('Precedence', 'list'))
    h.append(fold('MIME-Version', '1.0'))
    h.append(fold('X-Mailer', meta['mailer']))
    h.append(fold('X-Parrot-Corpus', f'v1 folder={meta["folder"]} index={meta["index"]}'))

    plain_part = (
        f'Content-Type: text/plain; charset=UTF-8\r\n'
        f'Content-Transfer-Encoding: quoted-printable\r\n\r\n'
        f'{qp_encode(meta["plain"])}\r\n'
    ).encode('utf-8')
    html_part = (
        f'Content-Type: text/html; charset=UTF-8\r\n'
        f'Content-Transfer-Encoding: quoted-printable\r\n\r\n'
        f'{qp_encode(meta["html"])}\r\n'
    ).encode('utf-8')

    alt = (
        f'Content-Type: multipart/alternative; boundary="{boundary_alt}"\r\n\r\n'.encode()
        + f'--{boundary_alt}\r\n'.encode() + plain_part
        + f'--{boundary_alt}\r\n'.encode() + html_part
        + f'--{boundary_alt}--\r\n'.encode()
    )

    del alt

    if not attachments:
        headers = '\r\n'.join(h + [
            fold('Content-Type', f'multipart/alternative; boundary="{boundary_alt}"')]) + '\r\n\r\n'
        body = (f'--{boundary_alt}\r\n'.encode() + plain_part
                + f'--{boundary_alt}\r\n'.encode() + html_part
                + f'--{boundary_alt}--\r\n'.encode())
        return headers.encode('utf-8') + body

    headers = '\r\n'.join(h + [
        fold('Content-Type', f'multipart/mixed; boundary="{boundary_mixed}"')]) + '\r\n\r\n'
    body = bytearray()
    body += f'--{boundary_mixed}\r\n'.encode()
    body += f'Content-Type: multipart/alternative; boundary="{boundary_alt}"\r\n\r\n'.encode()
    body += f'--{boundary_alt}\r\n'.encode() + plain_part
    body += f'--{boundary_alt}\r\n'.encode() + html_part
    body += f'--{boundary_alt}--\r\n'.encode()
    for filename, mime, data in attachments:
        body += f'--{boundary_mixed}\r\n'.encode()
        body += f'Content-Type: {mime}; name="{filename}"\r\n'.encode()
        body += f'Content-Disposition: attachment; filename="{filename}"\r\n'.encode()
        body += b'Content-Transfer-Encoding: base64\r\n\r\n'
        body += b64_body(data)
    body += f'--{boundary_mixed}--\r\n'.encode()
    return headers.encode('utf-8') + bytes(body)


# --------------------------------------------------------------------------
# Plan: decide every message's metadata up front, without generating bodies.
# --------------------------------------------------------------------------

MAILERS = [
    'Mozilla Thunderbird 128.6.0',
    'Evolution 3.52.3',
    'Apple Mail (2.3776.700.51)',
    'Microsoft Outlook 16.0',
    'Claws Mail 4.2.0',
    'git-send-email 2.45.2',
    'Roundcube Webmail 1.6.9',
]


class Plan:
    __slots__ = ('folder', 'index', 'kind', 'date', 'subject', 'from_name', 'from_email',
                 'to', 'cc', 'flags', 'n_attach', 'attach_kinds', 'attach_bytes',
                 'thread_root', 'depth', 'project', 'plant_term', 'anchor')

    def __init__(self, **kw):
        for k in self.__slots__:
            setattr(self, k, kw.get(k))


def build_plan():
    """Deterministically lay out every message.  Returns (plans, anchors)."""
    plans = []
    total_msgs = sum(c for _, c, _, _, _ in FOLDERS)
    span = (CORPUS_END - CORPUS_START).total_seconds()

    # Which messages carry the search term: spread deterministically over
    # INBOX and the Archive so the client has to search more than one folder.
    term_slots = [
        ('INBOX', 12), ('INBOX', 118), ('INBOX', 604),
        ('Archive/2025', 233), ('Archive/2025', 901),
        ('Archive/2024', 77), ('Archive/2024', 1310),
        ('Projects/Aurora', 88), ('Sent', 410),
    ]
    assert len(term_slots) == SEARCH_TERM_HITS
    term_set = set(term_slots)
    # The first few also carry the term in the subject line.
    term_subject_set = set(term_slots[:SEARCH_TERM_SUBJECT_HITS])

    for folder, count, attach_frac, unread_frac, kind in FOLDERS:
        frng = rng_for('folder', folder)
        # Every folder covers the full corpus span so date sorting is meaningful
        # everywhere, but the archive years are clamped to their own year.
        lo, hi = CORPUS_START, CORPUS_END
        if folder.startswith('Archive/'):
            year = int(folder.split('/')[1])
            lo = max(CORPUS_START, datetime(year, 1, 1, tzinfo=timezone.utc))
            hi = min(CORPUS_END, datetime(year, 12, 31, 23, 59, tzinfo=timezone.utc))
        fspan = (hi - lo).total_seconds()

        # Deterministic, strictly increasing dates: evenly spaced with jitter.
        step = fspan / max(1, count)
        dates = []
        for i in range(count):
            jitter = rng_for('date', folder, i).uniform(0.05, 0.95)
            dates.append(lo + timedelta(seconds=step * (i + jitter)))
        dates.sort()

        n_attach_total = int(round(count * attach_frac))
        attach_idx = set(frng.sample(range(count), n_attach_total)) if n_attach_total else set()

        n_unread = int(round(count * unread_frac))
        unread_idx = set(frng.sample(range(count), n_unread)) if n_unread else set()

        for i in range(count):
            mrng = rng_for('msg', folder, i)
            project = mrng.choice(PROJECTS)

            if kind == 'list':
                list_name, list_addr = MAILING_LISTS[folder]
                from_name, from_email = mrng.choice(PEOPLE)
                to = [(list_name, list_addr)]
                cc = []
            elif kind == 'sent':
                from_name, from_email = ACCOUNT_NAME, ACCOUNT
                to = [mrng.choice(PEOPLE)]
                cc = [mrng.choice(PEOPLE)] if mrng.random() < 0.25 else []
            elif kind == 'draft':
                from_name, from_email = ACCOUNT_NAME, ACCOUNT
                to = [mrng.choice(PEOPLE)]
                cc = []
            elif kind == 'junk':
                from_name = mrng.choice(['Prize Team', 'Account Security', 'Billing Dept',
                                         'Crypto Advisor', 'HR Notification'])
                from_email = '{}@{}.test'.format(
                    mrng.choice(['no-reply', 'alerts', 'winner', 'secure', 'offers']),
                    mrng.choice(['fast-cash', 'urgent-notice', 'lucky-draw', 'verify-now', 'bonus-hub']))
                to = [(ACCOUNT_NAME, ACCOUNT)]
                cc = []
            else:
                # Weight the primary correspondent heavily in INBOX so
                # sender-based sorting and filtering have a visible effect.
                if folder == 'INBOX' and mrng.random() < 0.22:
                    from_name, from_email = PRIMARY_CORRESPONDENT
                else:
                    from_name, from_email = mrng.choice(PEOPLE)
                to = [(ACCOUNT_NAME, ACCOUNT)]
                cc = [mrng.choice(PEOPLE)] if mrng.random() < 0.3 else []

            subject = pick_subject(mrng, kind, project)
            if (folder, i) in term_subject_set:
                subject = f'{SEARCH_TERM} migration: {subject}'
            depth = 0
            thread_root = None
            if mrng.random() < (0.55 if kind == 'list' else 0.35) and i > 3:
                depth = mrng.randint(1, 3)
                thread_root = i - mrng.randint(1, min(3, i))
                if not subject.startswith('Re: '):
                    subject = 'Re: ' + subject

            flags = 'S'
            if i in unread_idx:
                flags = ''
            elif kind == 'draft':
                flags = 'DS'
            elif mrng.random() < 0.07:
                flags = 'SF'
            elif depth and mrng.random() < 0.25:
                flags = 'RS'

            n_attach = 0
            akinds = []
            if i in attach_idx:
                n_attach = 1 if mrng.random() < 0.8 else 2
                for _ in range(n_attach):
                    r = mrng.random()
                    acc = 0.0
                    chosen = 'pdf'
                    for k, w in ATTACH_KINDS:
                        acc += w
                        if r <= acc:
                            chosen = k
                            break
                    akinds.append(chosen)

            plans.append(Plan(
                folder=folder, index=i, kind=kind, date=dates[i], subject=subject,
                from_name=from_name, from_email=from_email, to=to, cc=cc, flags=flags,
                n_attach=n_attach, attach_kinds=akinds, attach_bytes=[],
                thread_root=thread_root, depth=depth, project=project,
                plant_term=(folder, i) in term_set, anchor=None,
            ))

    # ---- Anchors: overwrite specific messages so the usage scenario has
    # ---- stable, findable targets.
    by_key = {(p.folder, p.index): p for p in plans}
    inbox_count = dict((f, c) for f, c, _, _, _ in FOLDERS)['INBOX']

    def set_anchor(folder, index, **kw):
        p = by_key[(folder, index)]
        for k, v in kw.items():
            setattr(p, k, v)
        return p

    anchors = {}

    # Newest inbox message: unread, from the primary correspondent, no attachment.
    newest = set_anchor('INBOX', inbox_count - 1,
                        subject='Re: Release checklist for Aurora 4.2',
                        from_name=PRIMARY_CORRESPONDENT[0], from_email=PRIMARY_CORRESPONDENT[1],
                        flags='', n_attach=0, attach_kinds=[], depth=1, project='Aurora',
                        anchor='newest_inbox')
    anchors['newest_inbox'] = {
        'folder': 'INBOX', 'subject': newest.subject, 'from': newest.from_email,
        'unread': True, 'position_from_top': 1,
    }

    # The message the scenario opens to view a PDF attachment: 7th from the top.
    pdf_idx = inbox_count - 7
    pdfmsg = set_anchor('INBOX', pdf_idx,
                        subject='Quarterly infrastructure review - final PDF',
                        from_name=PEOPLE[3][0], from_email=PEOPLE[3][1],
                        flags='', n_attach=1, attach_kinds=['pdf'], depth=0,
                        project='Borealis', anchor='pdf_attachment')
    anchors['pdf_attachment'] = {
        'folder': 'INBOX', 'subject': pdfmsg.subject, 'from': pdfmsg.from_email,
        'position_from_top': 7, 'attachment': 'infrastructure-review-2026-Q2.pdf',
    }

    # Biggest message in the mailbox, for "sort by size": 3rd from the top.
    big_idx = inbox_count - 3
    big = set_anchor('INBOX', big_idx,
                     subject='Design assets bundle - Borealis rebrand',
                     from_name=PEOPLE[5][0], from_email=PEOPLE[5][1],
                     flags='S', n_attach=1, attach_kinds=['zip'], depth=0,
                     project='Borealis', anchor='largest')
    anchors['largest'] = {
        'folder': 'INBOX', 'subject': big.subject, 'from': big.from_email,
        'position_from_top': 3, 'attachment': 'borealis-rebrand-assets.zip',
    }

    # Reply target: 2nd from the top.
    rep = set_anchor('INBOX', inbox_count - 2,
                     subject='Staging cluster credentials rotated',
                     from_name=PEOPLE[8][0], from_email=PEOPLE[8][1],
                     flags='', n_attach=0, attach_kinds=[], depth=0, anchor='reply_target')
    anchors['reply_target'] = {
        'folder': 'INBOX', 'subject': rep.subject, 'from': rep.from_email,
        'position_from_top': 2,
    }

    anchors['search'] = {
        'term': SEARCH_TERM,
        'expected_hits_full_text': SEARCH_TERM_HITS,
        'expected_hits_subject_only': SEARCH_TERM_SUBJECT_HITS,
        'folders_containing': sorted({f for f, _ in term_slots}),
        'slots': [{'folder': f, 'index': i} for f, i in term_slots],
    }
    anchors['compose_to'] = 'alice.brenner@parrot.test'
    anchors['primary_correspondent'] = PRIMARY_CORRESPONDENT[1]
    return plans, anchors


# --------------------------------------------------------------------------
# Rendering
# --------------------------------------------------------------------------

def render(plan, attach_sizes):
    """Build the full message bytes for one plan entry.  attach_sizes is the
    list of target byte sizes for this message's attachments (encoded size is
    ~4/3 of that)."""
    mrng = rng_for('render', plan.folder, plan.index)
    plain, html = build_body(
        mrng, plan.kind, plan.from_name, plan.subject, plan.project, plan.plant_term,
        quote_from=(plan.to[0][0] if plan.depth and plan.to else None))

    msgid_local = '{:016x}.{:08x}'.format(
        rng_for('mid', plan.folder, plan.index).getrandbits(64), plan.index)
    domain = plan.from_email.split('@')[1]
    refs = []
    in_reply_to = None
    if plan.thread_root is not None:
        root_local = '{:016x}.{:08x}'.format(
            rng_for('mid', plan.folder, plan.thread_root).getrandbits(64), plan.thread_root)
        in_reply_to = f'<{root_local}@{domain}>'
        refs = [in_reply_to]

    list_id = list_post = None
    if plan.folder in MAILING_LISTS:
        list_id, list_post = MAILING_LISTS[plan.folder]

    attachments = []
    for k, size in zip(plan.attach_kinds, attach_sizes):
        if plan.anchor == 'pdf_attachment':
            fname = 'infrastructure-review-2026-Q2.pdf'
        elif plan.anchor == 'largest':
            fname = 'borealis-rebrand-assets.zip'
        else:
            fname = attach_filename(mrng, k, plan.project)
        label = fname.rsplit('.', 1)[0]
        data = ATTACH_BUILDERS[k](rng_for('att', plan.folder, plan.index, k), size, label)
        attachments.append((fname, ATTACH_MIME[k], data))

    meta = {
        'from_name': plan.from_name, 'from_email': plan.from_email,
        'to': plan.to, 'cc': plan.cc, 'subject': plan.subject,
        'date_hdr': plan.date.strftime('%a, %d %b %Y %H:%M:%S +0000'),
        'msgid_local': msgid_local, 'msgid_domain': domain,
        'in_reply_to': in_reply_to, 'references': refs,
        'list_id': list_id, 'list_post': list_post,
        'mailer': mrng.choice(MAILERS), 'plain': plain, 'html': html,
        'helo': domain, 'folder': plan.folder, 'index': plan.index,
    }
    return build_message(mrng, meta, attachments)


def maildir_path(root, imap_name):
    if imap_name == 'INBOX':
        return root
    return os.path.join(root, '.' + imap_name.replace('/', '.'))


def write_message(folder_path, plan, data, seq):
    """Write into cur/ (or new/ for unread) with Dovecot's size hints.

    Messages use CRLF throughout, so the physical size equals the virtual
    (RFC822) size and both S= and W= can be stated up front - that saves
    Dovecot from stat-ing and rewriting every filename on first access.
    """
    unread = 'S' not in plan.flags
    sub = 'new' if unread else 'cur'
    ts = int(plan.date.timestamp())
    size = len(data)
    base = f'{ts}.M{seq % 1000000:06d}P{1000 + (seq % 9000)}Q{seq}.{MAILDIR_HOSTNAME}'
    name = f'{base},S={size},W={size}'
    # A message in new/ must carry no ":2,<flags>" info part - that is what makes
    # it "new" rather than merely unseen.  build_plan() only ever assigns an
    # empty flag set to unread messages, so this stays consistent.
    assert not (unread and plan.flags), f'unread message with flags {plan.flags!r}'
    if plan.flags:
        name += ':2,' + ''.join(sorted(plan.flags))

    tmp = os.path.join(folder_path, 'tmp', base)
    final = os.path.join(folder_path, sub, name)
    with open(tmp, 'wb') as fh:
        fh.write(data)
    os.utime(tmp, (ts, ts))
    os.rename(tmp, final)
    return size


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--root', default=os.path.expanduser('~/Maildir'))
    ap.add_argument('--target-mb', type=int,
                    default=int(os.environ.get('PARROT_MAIL_TARGET_MB', '500')))
    ap.add_argument('--manifest', default=None,
                    help='where to write corpus-manifest.json (default: <root>/../corpus-manifest.json)')
    ap.add_argument('--aliases', default=None,
                    help='write the list of local persona addresses here, one per line, '
                         'for Postfix to alias onto the benchmark account')
    ap.add_argument('--fresh', action='store_true', help='delete the maildir first')
    ap.add_argument('--print-anchors', action='store_true',
                    help='print the folder plan and scenario anchors as JSON and exit '
                         'without writing anything; lets the client container show the '
                         'operator what to look for without a copy of the corpus')
    args = ap.parse_args()

    if args.print_anchors:
        plans, anchors = build_plan()
        counts = {}
        for p in plans:
            counts[p.folder] = counts.get(p.folder, 0) + 1
        json.dump({'total_messages': len(plans), 'folders': counts, 'anchors': anchors},
                  sys.stdout, indent=2, sort_keys=True)
        sys.stdout.write('\n')
        return 0

    root = os.path.abspath(args.root)
    target = args.target_mb * 1024 * 1024

    if args.fresh and os.path.isdir(root):
        shutil.rmtree(root)

    t0 = time.monotonic()
    plans, anchors = build_plan()
    print(f'[corpus] planned {len(plans)} messages in {len(FOLDERS)} folders', flush=True)

    # ---- Pass 1: measure the text-only size of every message so the
    # ---- attachment budget can be computed exactly.
    text_bytes = 0
    attach_slots = []          # (plan, kind_index)
    for p in plans:
        # Render with the attachment list emptied, so we measure text only.
        saved, p.attach_kinds = p.attach_kinds, []
        text_bytes += len(render(p, []))
        p.attach_kinds = saved
        for ki in range(p.n_attach):
            attach_slots.append((p, ki))
    print(f'[corpus] message text: {text_bytes / 1048576:.1f} MiB, '
          f'{len(attach_slots)} attachment slots', flush=True)

    # MIME part overhead per attachment (headers + boundary), roughly.
    overhead = len(attach_slots) * 240
    budget = target - text_bytes - overhead
    if budget < len(attach_slots) * 4096:
        print(f'[corpus] WARNING: target {args.target_mb} MB is too small for '
              f'{len(plans)} messages; attachments will be minimal', file=sys.stderr)
        budget = len(attach_slots) * 4096

    # Distribute the budget with a long-tailed (log-normal-ish) shape so a few
    # messages are big and most are small - like a real mailbox.
    weights = []
    for p, ki in attach_slots:
        r = rng_for('attw', p.folder, p.index, ki)
        weights.append(r.lognormvariate(0.0, 0.85))
    # The two anchor attachments get fixed, generous sizes so they are
    # recognisably "the big one" and "the PDF" in every client.
    FIXED = {'pdf_attachment': 2_600_000, 'largest': 12_000_000}
    fixed_total = 0
    for i, (p, _ki) in enumerate(attach_slots):
        if p.anchor in FIXED:
            weights[i] = None
            fixed_total += FIXED[p.anchor]
    free_budget = max(0, budget - int(fixed_total * 4 / 3))
    wsum = sum(w for w in weights if w is not None) or 1.0

    sizes = []
    for i, (p, _ki) in enumerate(attach_slots):
        if weights[i] is None:
            sizes.append(FIXED[p.anchor])
        else:
            # 3/4 because base64 inflates the payload by 4/3 on the wire.
            sizes.append(max(2048, int(free_budget * (weights[i] / wsum) * 0.75)))
    for (p, ki), size in zip(attach_slots, sizes):
        while len(p.attach_bytes) <= ki:
            p.attach_bytes.append(0)
        p.attach_bytes[ki] = size

    # ---- Create folder skeleton
    all_folders = [f for f, _, _, _, _ in FOLDERS] + CONTAINER_FOLDERS
    for name in all_folders:
        fp = maildir_path(root, name)
        for sub in ('cur', 'new', 'tmp'):
            os.makedirs(os.path.join(fp, sub), exist_ok=True)
        if name != 'INBOX':
            # Maildir++ marker so Dovecot treats the directory as a mailbox.
            open(os.path.join(fp, 'maildirfolder'), 'wb').close()

    with open(os.path.join(root, 'subscriptions'), 'w', encoding='utf-8') as fh:
        for name in sorted(set(all_folders)):
            if name != 'INBOX':
                fh.write(name.replace('/', '.') + '\n')

    # ---- Pass 2: render and write
    written = 0
    per_folder = {}
    seq = 0
    for p in plans:
        data = render(p, p.attach_bytes)
        fp = maildir_path(root, p.folder)
        seq += 1
        size = write_message(fp, p, data, seq)
        written += size
        st = per_folder.setdefault(p.folder, {'messages': 0, 'bytes': 0, 'unread': 0,
                                              'with_attachments': 0})
        st['messages'] += 1
        st['bytes'] += size
        if 'S' not in p.flags:
            st['unread'] += 1
        if p.n_attach:
            st['with_attachments'] += 1
        if seq % 2000 == 0:
            print(f'[corpus] {seq}/{len(plans)} messages, {written / 1048576:.0f} MiB',
                  flush=True)

    manifest = {
        'corpus_version': 1,
        'seed': SEED,
        'account': {'address': ACCOUNT, 'display_name': ACCOUNT_NAME},
        'generated_from_epoch': CORPUS_END.isoformat(),
        'target_mb': args.target_mb,
        'total_bytes': written,
        'total_mib': round(written / 1048576, 2),
        'total_messages': len(plans),
        'folders': per_folder,
        'special_use': SPECIAL_USE,
        'anchors': anchors,
    }
    mpath = args.manifest or os.path.join(os.path.dirname(root), 'corpus-manifest.json')
    with open(mpath, 'w', encoding='utf-8') as fh:
        json.dump(manifest, fh, indent=2, sort_keys=True)

    if args.aliases:
        # Every domain that appears anywhere in the corpus, as a Postfix
        # catch-all key.  Not just the @parrot.test personas: the scenario
        # replies to a message whose sender is external, and without a catch-all
        # for that domain the reply is undeliverable.  Postfix would then inject
        # a bounce into the inbox mid-run, shifting every anchor position and
        # breaking the screenshot assertions that follow.
        domains = {e.split('@')[1] for _n, e in PEOPLE}
        domains |= {a.split('@')[1] for _n, a in MAILING_LISTS.values()}
        domains.add(ACCOUNT.split('@')[1])
        domains.add('lists.parrot.test')
        with open(args.aliases, 'w', encoding='utf-8') as fh:
            for d in sorted(domains):
                fh.write('@' + d + '\n')

    print(f'[corpus] done: {len(plans)} messages, {written / 1048576:.1f} MiB '
          f'(target {args.target_mb} MiB) in {time.monotonic() - t0:.1f}s', flush=True)
    print(f'[corpus] manifest: {mpath}', flush=True)
    return 0


if __name__ == '__main__':
    sys.exit(main())
