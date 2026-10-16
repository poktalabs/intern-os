#!/usr/bin/env bash
#
# latest.sh: gather the latest state of an internOS workstream or project.
#
# Read-only. Prints a plain-text report the /latest skill turns into a summary.
#
#   Inside a workstream  → STATUS.md, its pick-up checkpoint, last sessions,
#                          open tick tasks, recent commits touching it.
#   Inside a project     → workstreams ranked by STATUS `updated:` date, the
#   (not a workstream)     newest project checkpoint, recent commits, open tasks.
#   Neither              → says so and exits 1.
#
# Usage: latest.sh [<pwd>]

set -uo pipefail

START="${1:-$PWD}"
START="$(cd "$START" 2>/dev/null && pwd -P)" || { echo "latest: no such dir: ${1:-$PWD}"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
LOG="$HOME/.claude/checkpoint-log.jsonl"

# resolve-thread.sh ships with the intern-os adapter: three levels up in the
# repo, or the installed intern-os skill.
RESOLVE=""
for c in "$SCRIPT_DIR/../../../scripts/resolve-thread.sh" \
         "$HOME/.claude/skills/intern-os/scripts/resolve-thread.sh"; do
    [[ -x "$c" ]] && { RESOLVE="$c"; break; }
done

# --- helpers ----------------------------------------------------------------

# Project root: nearest ancestor holding PROJECT.md under a projects/ path.
find_project_root() {
    local d="$1"
    while [[ "$d" != "/" ]]; do
        if [[ -f "$d/PROJECT.md" && "$d" == */projects/* ]]; then
            echo "$d"; return 0
        fi
        d="$(dirname "$d")"
    done
    return 1
}

# Newest checkpoint-log entry whose checkpoint_path exists and whose cwd or
# checkpoint_path sits under $1.
logged_checkpoint() {
    local scope="$1"
    [[ -r "$LOG" ]] && command -v jq >/dev/null 2>&1 || return 0
    tail -n 300 "$LOG" \
        | jq -r --arg s "$scope" 'select(type == "object")
            | select((.checkpoint_path // "") != "")
            | select(((.cwd // "") | startswith($s)) or (.checkpoint_path | startswith($s)))
            | "\(.ts)\t\(.checkpoint_path)\t\(.summary // "")"' 2>/dev/null \
        | while IFS=$'\t' read -r ts p summary; do
            [[ -f "$p" ]] && printf '%s\t%s\t%s\n' "$ts" "$p" "$summary"
          done | tail -1
}

# `> **Pick-up checkpoint:** <path>` pointer at the top of a STATUS/INDEX file.
status_pointer() {
    local file="$1" rel
    [[ -f "$file" ]] || return 0
    rel=$(grep -m1 -i 'pick-up checkpoint' "$file" | sed -E 's/.*\*\*[[:space:]]*//; s/[[:space:]]*[:(].*$//; s/`//g')
    [[ -n "$rel" ]] || return 0
    (cd "$(dirname "$file")" && [[ -f "$rel" ]] && echo "$(cd "$(dirname "$rel")" && pwd -P)/$(basename "$rel")")
}

newest_project_checkpoint() {
    local dir="$1/docs/checkpoints"
    [[ -d "$dir" ]] || return 0
    ls -t "$dir"/*.md 2>/dev/null | head -1
}

recent_commits() {
    local path="$1" n="$2"
    git -C "$path" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "(not a git repo)"; return; }
    git -C "$path" log -n "$n" --date=short --format='%ad %h %s' -- . 2>/dev/null
    local dirty
    dirty=$(git -C "$path" status --short -- . 2>/dev/null | wc -l | tr -d ' ')
    [[ "$dirty" -gt 0 ]] && echo "($dirty uncommitted change(s) under this path)"
}

tick_tasks() {
    local dir="$1" tag="${2:-}"
    command -v tick >/dev/null 2>&1 || { echo "(tick not on PATH)"; return; }
    local out
    if [[ -n "$tag" ]]; then
        out=$(cd "$dir" && tick list --tag "$tag" 2>/dev/null | head -20)
    else
        out=$(cd "$dir" && tick list 2>/dev/null | head -20)
    fi
    echo "${out:-(none)}"
}

field() { grep -m1 -E "^$2:" "$1" 2>/dev/null | sed -E "s/^$2:[[:space:]]*//"; }

# --- resolve scope ----------------------------------------------------------

workstream_dir=""
if [[ -n "$RESOLVE" ]]; then
    workstream_dir="$(cd "$START" && "$RESOLVE" 2>/dev/null)" || workstream_dir=""
fi
project_root="$(find_project_root "$START")" || project_root=""

if [[ -z "$workstream_dir" && -z "$project_root" ]]; then
    echo "latest: $START is not inside an internOS workstream or project (no PROJECT.md above it)."
    exit 1
fi

# --- workstream mode --------------------------------------------------------

if [[ -n "$workstream_dir" ]]; then
    ws="$(basename "$workstream_dir")"
    [[ -z "$project_root" ]] && project_root="$(find_project_root "$workstream_dir")"
    echo "MODE: workstream"
    echo "WORKSTREAM: $ws"
    echo "DIR: $workstream_dir"
    echo "PROJECT: ${project_root:-?}"
    echo "BRIEF status: $(field "$workstream_dir/BRIEF.md" status)"

    pointer="$(status_pointer "$workstream_dir/STATUS.md")"
    logged="$(logged_checkpoint "$workstream_dir")"
    echo
    echo "== CHECKPOINT =="
    if [[ -n "$logged" ]]; then
        IFS=$'\t' read -r ts p summary <<< "$logged"
        echo "logged: $p ($ts)"
        echo "  $summary"
    fi
    [[ -n "$pointer" ]] && echo "STATUS pointer: $pointer"
    [[ -z "$logged" && -z "$pointer" ]] && echo "(none found)"

    echo
    echo "== STATUS.md =="
    cat "$workstream_dir/STATUS.md" 2>/dev/null || echo "(missing)"

    echo
    echo "== Last 5 sessions =="
    grep -E '^[0-9]{4}-' "$workstream_dir/SESSIONS.md" 2>/dev/null | tail -5 || echo "(none)"

    echo
    echo "== Recent commits touching this workstream =="
    recent_commits "$workstream_dir" 5

    echo
    echo "== Open tick tasks (tag: $ws) =="
    tick_tasks "$workstream_dir" "$ws"
    exit 0
fi

# --- project mode -----------------------------------------------------------

echo "MODE: project"
echo "PROJECT: $(basename "$project_root")"
echo "DIR: $project_root"

echo
echo "== CHECKPOINT =="
logged="$(logged_checkpoint "$project_root")"
newest="$(newest_project_checkpoint "$project_root")"
if [[ -n "$logged" ]]; then
    IFS=$'\t' read -r ts p summary <<< "$logged"
    echo "logged: $p ($ts)"
    echo "  $summary"
fi
[[ -n "$newest" ]] && echo "newest in docs/checkpoints: $newest"
[[ -z "$logged" && -z "$newest" ]] && echo "(none found)"

echo
echo "== Workstreams, most recently updated first (archived excluded) =="
if [[ -d "$project_root/workstreams" ]]; then
    for s in "$project_root"/workstreams/*/STATUS.md; do
        [[ -f "$s" ]] || continue
        d="$(dirname "$s")"
        upd="$(field "$s" updated)"
        # Sort key: the updated: date, else the file mtime.
        key="$(printf '%s' "$upd" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}')"
        [[ -z "$key" ]] && key="$(date -r "$s" +%Y-%m-%d)"
        mt="$(stat -f %m "$s" 2>/dev/null || stat -c %Y "$s")"
        state="$(field "$s" State | cut -c1-220)"
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$key" "$mt" "$(basename "$d")" \
            "$(field "$d/BRIEF.md" status)" "${upd:-?}" "$state"
    done | sort -t$'\t' -k1,1r -k2,2nr \
         | awk -F'\t' '{printf "- %s [%s] updated %s\n    %s\n", $3, $4, $5, $6}'
else
    echo "(no workstreams/ dir)"
fi

echo
echo "== Recent commits in the project =="
recent_commits "$project_root" 8

if [[ -f "$project_root/TICK.md" ]]; then
    echo
    echo "== Open tick tasks (project) =="
    tick_tasks "$project_root"
fi
exit 0
