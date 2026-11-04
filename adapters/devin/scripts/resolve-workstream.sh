#!/usr/bin/env bash
#
# resolve-workstream.sh — Devin adapter resolver for internOS workstreams.
#
# Devin session IDs change every session, so a Devin session cannot bind a
# workstream by its own ID. It binds by the exact workspace-relative path the
# human named instead:
#
#   resolve-workstream.sh [--load] projects/<path-to-project>/workstreams/<name>
#
# The workstream's BRIEF.md must carry that path as its Devin binding, in
# either field:
#
#   thread_id: devin:projects/<path-to-project>/workstreams/<name>        (Devin-owned)
#   thread_id_devin: devin:projects/<path-to-project>/workstreams/<name>  (sibling binding)
#
# INTERNOS_WORKSPACE (required) is a single workspace (contains projects/), a
# workspaces container (children contain projects/), or a colon-separated list
# of either. The path is checked under every expanded workspace; exactly one
# must exist. No fuzzy matching, no directory scans beyond that.
#
# Output:
#   default  absolute path of the workstream directory
#   --load   the Tier 1 bundle: project AGENTS.md, BRIEF.md, STATUS.md (capped)
#
# Exit codes:
#   0  resolved
#   1  no workstream at that path in any configured workspace
#   2  binding broken: BRIEF.md missing, binding mismatch, or ambiguous match
#   3  usage error (bad path shape, INTERNOS_WORKSPACE unset)

set -euo pipefail

STATUS_LOAD_CAP="${STATUS_LOAD_CAP:-40}"

load=false
if [[ "${1:-}" == "--load" ]]; then
    load=true
    shift
fi

rel="${1:-}"
rel="${rel%/}"
if [[ -z "$rel" ]]; then
    echo "usage: resolve-workstream.sh [--load] projects/<project>/workstreams/<name>" >&2
    exit 3
fi
if [[ ! "$rel" =~ ^projects/.+/workstreams/(archived/)?[^/]+$ || "$rel" == */workstreams/archived || "$rel" == *..* ]]; then
    echo "resolve-workstream: not a workstream path: $rel" >&2
    echo "  expected: projects/<path-to-project>/workstreams/<name>" >&2
    exit 3
fi

if [[ -z "${INTERNOS_WORKSPACE:-}" ]]; then
    echo "resolve-workstream: INTERNOS_WORKSPACE is not set." >&2
    exit 3
fi

expanded=()
IFS=':' read -r -a candidates <<< "$INTERNOS_WORKSPACE"
for ws in "${candidates[@]}"; do
    [[ -n "$ws" && -d "$ws" ]] || continue
    ws_abs="$(cd "$ws" && pwd)"
    if [[ -d "$ws_abs/projects" ]]; then
        expanded+=("$ws_abs")
    else
        for child in "$ws_abs"/*/; do
            [[ -d "${child}projects" ]] && expanded+=("${child%/}")
        done
    fi
done

matches=()
if [[ ${#expanded[@]} -gt 0 ]]; then
    for ws_abs in "${expanded[@]}"; do
        [[ -d "$ws_abs/$rel" ]] && matches+=("$ws_abs/$rel")
    done
fi

if [[ ${#matches[@]} -eq 0 ]]; then
    echo "resolve-workstream: no workstream at $rel under INTERNOS_WORKSPACE=$INTERNOS_WORKSPACE" >&2
    echo "  Stop and ask the human. Do not pick a similarly named workstream." >&2
    exit 1
fi
if [[ ${#matches[@]} -gt 1 ]]; then
    echo "resolve-workstream: $rel exists in ${#matches[@]} workspaces — ambiguous:" >&2
    printf '  %s\n' "${matches[@]}" >&2
    exit 2
fi

ws_dir="${matches[0]}"
brief="$ws_dir/BRIEF.md"
if [[ ! -f "$brief" ]]; then
    echo "resolve-workstream: workstream has no BRIEF.md: $ws_dir" >&2
    exit 2
fi

field() {
    awk -v f="$1" '
        $0 ~ "^[[:space:]]*" f "[[:space:]]*:" {
            sub(/^[^:]*:[[:space:]]*/, "", $0)
            gsub(/[[:space:]]+$/, "", $0)
            print
            exit
        }
    ' "$brief"
}

expected="devin:$rel"
primary="$(field thread_id)"
sibling="$(field thread_id_devin)"
if [[ "$primary" != "$expected" && "$sibling" != "$expected" ]]; then
    echo "resolve-workstream: Devin binding mismatch in $brief" >&2
    echo "  expected (in thread_id or thread_id_devin): $expected" >&2
    echo "  thread_id:       ${primary:-<empty>}" >&2
    echo "  thread_id_devin: ${sibling:-<empty>}" >&2
    echo "  Stop and ask the human. Do not edit BRIEF.md to make it match." >&2
    exit 2
fi

if [[ "$load" == false ]]; then
    echo "$ws_dir"
    exit 0
fi

project_dir="${ws_dir%/workstreams/*}"
echo "# internOS workstream: $rel"
echo "# path: $ws_dir"
if [[ -f "$project_dir/AGENTS.md" ]]; then
    echo
    echo "===== $project_dir/AGENTS.md ====="
    cat "$project_dir/AGENTS.md"
fi
echo
echo "===== BRIEF.md ====="
cat "$brief"
echo
echo "===== STATUS.md ====="
if [[ -f "$ws_dir/STATUS.md" ]]; then
    lines=$(wc -l < "$ws_dir/STATUS.md" | tr -d ' ')
    if [[ "$lines" -gt "$STATUS_LOAD_CAP" ]]; then
        head -n "$STATUS_LOAD_CAP" "$ws_dir/STATUS.md"
        echo
        echo "[internOS: STATUS.md is $lines lines; loaded the first $STATUS_LOAD_CAP. It should be ≤10. Trim it in place and move the narrative to JOURNAL.md.]"
    else
        cat "$ws_dir/STATUS.md"
    fi
else
    echo "[internOS: STATUS.md is missing]"
fi
