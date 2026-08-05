#!/usr/bin/env python3
"""Print the corpus layout and the scenario's anchor messages.

Reads the JSON that `generate_corpus.py --print-anchors` emits, either from a
file given as argv[1] or from stdin.  Shown during client setup so whoever
records a macro can see which message sits where without opening the mailbox.
"""

import json
import sys


def main():
    if len(sys.argv) > 1:
        with open(sys.argv[1], encoding='utf-8') as fh:
            data = json.load(fh)
    else:
        data = json.load(sys.stdin)

    folders = data['folders']
    print(f'[anchors] corpus: {data["total_messages"]} messages in {len(folders)} folders')
    for name in sorted(folders):
        print(f'[anchors]   {name:<20} {folders[name]:>6} messages')

    a = data['anchors']
    s = a['search']
    print(f'[anchors] search "{s["term"]}": {s["expected_hits_full_text"]} full-text hits, '
          f'{s["expected_hits_subject_only"]} subject-only hits')
    print(f'[anchors]   spread over: {", ".join(s["folders_containing"])}')

    print('[anchors] inbox positions the scenario refers to (newest first):')
    for key in ('newest_inbox', 'reply_target', 'largest', 'pdf_attachment'):
        m = a[key]
        extra = f'  [{m["attachment"]}]' if 'attachment' in m else ''
        print(f'[anchors]   #{m["position_from_top"]:<2} {key:<16} {m["subject"]}{extra}')
        print(f'[anchors]       from {m["from"]}')

    print(f'[anchors] compose target: {a["compose_to"]} (aliased back to the benchmark mailbox)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
