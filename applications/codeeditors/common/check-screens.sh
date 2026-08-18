#!/usr/bin/env bash
# Fail a recording whose checkpoints do not differ from one another.
#
#   check-screens.sh <editor>      one editor
#   check-screens.sh --all         every editor that has a .parrot
#
# WHY THIS EXISTS
#
# Three of the four JetBrains-family editors shipped a recording in which
# Ctrl+G opened the "Go to Line:Column" popup, the popup never took the typed
# line number, and the IDE then sat frozen behind it for the rest of the run.
# Blocks 14 to 18 changed nothing at all, so their five screenshots were
# byte-for-byte the same image - and a replay compares each checkpoint against
# its OWN reference, so five identical references matched five identical
# captures and the run reported 18 PASS 0 FAIL.  Emacs did the same thing for a
# different reason: block 13 opened a path that did not exist, and checks 13 and
# 15 came out identical because nothing between them touched anything real.
#
# A screenshot check answers "does this look like it did when I recorded it".
# It cannot answer "did the recording do anything", because a recording that did
# nothing is perfectly reproducible.  This asks the second question.
#
# Two consecutive checkpoints CAN legitimately look the same - Save file after
# Insert comment leaves the pixels alone in several editors, and that is a real
# result worth keeping.  So this reports every identical pair and fails only
# when a RUN of three or more checkpoints collapses into one image, which no
# scenario in script.md can honestly produce.
set -euo pipefail

REPO=/home/didi/code/parrot
GROUP="${REPO}/applications/codeeditors"
RUN_LIMIT=3

check_one() {
    local editor="$1" dir="${GROUP}/$1"
    [[ -f "${dir}/${editor}.parrot" ]] || return 0

    mapfile -t shots < <(ls -1 "${dir}/${editor}"-check-*.png 2>/dev/null || true)
    if [[ ${#shots[@]} -eq 0 ]]; then
        printf '%-14s no screenshots\n' "$editor"
        return 0
    fi

    # index -> checksum, in checkpoint order
    local -a sums=() names=()
    local f
    for f in "${shots[@]}"; do
        sums+=("$(md5sum "$f" | cut -d' ' -f1)")
        names+=("$(basename "$f" | sed 's/.*-check-0*//; s/\.png//')")
    done

    local pairs=0 worst=1 run=1 start=0 i bad=0 detail=""
    for ((i = 1; i < ${#sums[@]}; i++)); do
        if [[ "${sums[i]}" == "${sums[i-1]}" ]]; then
            (( pairs++ ))
            (( run++ ))
        else
            if (( run > worst )); then worst=$run; fi
            if (( run >= RUN_LIMIT )); then
                bad=1
                detail+=" checks ${names[start]}-${names[i-1]} are one image;"
            fi
            run=1
            start=$i
        fi
    done
    if (( run > worst )); then worst=$run; fi
    if (( run >= RUN_LIMIT )); then
        bad=1
        detail+=" checks ${names[start]}-${names[${#sums[@]}-1]} are one image;"
    fi

    # identical but non-adjacent checkpoints - emacs 13 and 15 - are worth a word
    local dupes
    dupes="$(printf '%s\n' "${sums[@]}" | sort | uniq -d | wc -l)"

    if (( bad )); then
        printf '%-14s FAIL  %d identical pairs, longest run %d -%s\n' \
            "$editor" "$pairs" "$worst" "$detail"
        return 1
    fi
    printf '%-14s ok    %d identical pairs, longest run %d, %d repeated images\n' \
        "$editor" "$pairs" "$worst" "$dupes"
    return 0
}

rc=0
if [[ "${1:-}" == "--all" ]]; then
    for d in "${GROUP}"/*/; do
        e="$(basename "$d")"
        [[ -f "${d}/${e}.parrot" ]] || continue
        check_one "$e" || rc=1
    done
else
    check_one "${1:?usage: check-screens.sh <editor>|--all}" || rc=1
fi
exit "$rc"
