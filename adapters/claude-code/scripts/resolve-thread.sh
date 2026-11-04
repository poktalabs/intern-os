#!/usr/bin/env bash
#
# resolve-thread.sh — Resolve the active workstream thread from pwd (Claude Code).
#
# Walks up from $PWD looking for an internOS workstream directory of the form
# <workspace>/projects/<project-or-container/...>/<project>/workstreams/<workstream>/.
# If found, verifies that BRIEF.md exists and its thread_id matches the
# expected canonical form
# `claude-code:projects/<path-to-project>/workstreams/<workstream>`.
#
# It also resolves from inside a CODE WORKTREE: when $PWD is under
# <workspace>/projects/<path-to-project>/code/.worktrees/<name>/, it resolves to
# the workstream whose BRIEF.md `worktrees:` block declares that worktree
# (exact match on the project-relative dir path). One declarer → that
# workstream; more than one → exit 2 (ambiguous); none → exit 1.
#
# This is the Claude Code analogue of the Discord/Slack thread_id binding:
# the working directory IS the thread. Resolution is exact and deterministic —
# no fuzzy matching, no fallback, no guessing.
#
# Usage:
#   resolve-thread.sh                       # uses $PWD and $INTERNOS_WORKSPACE
#   resolve-thread.sh <pwd> [<workspace>]   # explicit args (testing)
#
# Env:
#   INTERNOS_WORKSPACE  One or more roots (REQUIRED — no default). PATH-style:
#                       colon-separated list. Each root is EITHER a single
#                       workspace (directly contains `projects/`) OR a
#                       workspaces container (its immediate children each
#                       contain `projects/`, canonically named "workspaces").
#                       Containers are expanded to their child workspaces;
#                       resolution then picks the first workspace that is an
#                       ancestor of $PWD.
#
#                       Single workspace:
#                           export INTERNOS_WORKSPACE="$HOME/workspaces/frutero"
#                       Several workspaces, explicit:
#                           export INTERNOS_WORKSPACE="$HOME/workspaces/frutero:$HOME/workspaces/poktalabs"
#                       Workspaces container (resolves across every child):
#                           export INTERNOS_WORKSPACE="$HOME/workspaces"
#
# Output (stdout, on success): absolute path to the active workstream directory
# Exit codes:
#   0  active workstream resolved (path printed to stdout)
#   1  pwd is not inside a workstream subtree (no active thread — silent, expected)
#   2  workstream directory found but BRIEF.md missing or thread_id mismatched
#   3  usage error (missing INTERNOS_WORKSPACE, bad start dir, etc.)

set -euo pipefail

# --- Args -------------------------------------------------------------------

START_DIR="${1:-$PWD}"
WORKSPACE_LIST="${2:-${INTERNOS_WORKSPACE:-}}"

if [[ -z "$WORKSPACE_LIST" ]]; then
    cat >&2 <<'EOF'
resolve-thread: INTERNOS_WORKSPACE is not set.

Set it to one or more workspace roots (each containing a `projects/` directory).
PATH-style: colon-separated. Examples:

    export INTERNOS_WORKSPACE="$HOME/workspaces/frutero"
    export INTERNOS_WORKSPACE="$HOME/workspaces/frutero:$HOME/workspaces/poktalabs"

There is no implicit default — the Claude Code adapter requires this to be
explicit so it never silently picks up a stale or unrelated workspace.
EOF
    exit 3
fi

# Normalize to absolute paths so prefix-matching is well-defined.
if [[ ! -d "$START_DIR" ]]; then
    echo "resolve-thread: start dir not found: $START_DIR" >&2
    exit 3
fi
START_DIR="$(cd "$START_DIR" && pwd -P)"

# Expand each configured root into concrete workspace roots, then find the
# first that is an ancestor of START_DIR. Missing roots on disk are skipped
# silently — the skill stays quiet in unrelated sessions and only barks when
# the human actually tries to operate.
#
# Each entry may be EITHER a single workspace (directly contains projects/) OR
# a workspaces container (its immediate children each contain projects/, e.g.
# `~/workspaces`). Detection is structural, identical to sync-check.sh and
# generate-registry.sh: a container expands to its child workspaces. The
# canonical thread_id stays relative to the matched workspace, never the
# container, so all downstream matching is unchanged.
WORKSPACE=""
IFS=':' read -r -a _ws_candidates <<< "$WORKSPACE_LIST"

_expanded=()
for _ws in "${_ws_candidates[@]}"; do
    [[ -z "$_ws" ]] && continue
    [[ -d "$_ws" ]] || continue
    _ws_abs="$(cd "$_ws" && pwd -P)"
    if [[ -d "$_ws_abs/projects" ]]; then
        _expanded+=("$_ws_abs")                       # single workspace
    else
        for _child in "$_ws_abs"/*/; do               # workspaces container
            [[ -d "${_child}projects" ]] && _expanded+=("${_child%/}")
        done
    fi
done

if [[ ${#_expanded[@]} -gt 0 ]]; then
    for _ws_abs in "${_expanded[@]}"; do
        case "$START_DIR/" in
            "$_ws_abs"/*)
                WORKSPACE="$_ws_abs"
                break ;;
        esac
    done
fi

if [[ -z "$WORKSPACE" ]]; then
    # Not under any configured workspace — no thread to resolve.
    exit 1
fi

# --- Walk up from $START_DIR, looking for a workstream dir ------------------
#
# A workstream dir is exactly:
#   <WORKSPACE>/projects/<path-to-project>/workstreams/<name>
#   (or, once archived: .../workstreams/archived/<name>)
#
# <path-to-project> may be a simple top-level project (`foo`) or a nested child
# project under a container (`club/club-app`, `devrel/nebius`). The canonical
# thread_id is still relative to the workspace root. We walk up until we find
# a directory whose path matches that shape, OR we leave the workspace subtree.

current="$START_DIR"
workstream_dir=""

while [[ "$current" == "$WORKSPACE"/* ]]; do
    # Match: <WORKSPACE>/projects/<path-to-project>/workstreams/<name>
    rel="${current#$WORKSPACE/}"
    # Archived workstreams live one level deeper (workstreams/archived/<name>,
    # per ROLLOUT.md); the `archived` container itself is not a workstream.
    if [[ "$rel" =~ ^projects/.+/workstreams/(archived/)?[^/]+$ && "$rel" != */workstreams/archived ]]; then
        workstream_dir="$current"
        break
    fi
    current="$(dirname "$current")"
done

# If not directly inside a workstream dir, check whether cwd is inside a code
# worktree — projects/<path-to-project>/code/.worktrees/<name>/... — and resolve
# to the workstream that DECLARES that worktree in its BRIEF.md `worktrees:`
# block. Exact match on the declared project-relative dir path; deterministic,
# no fuzzy matching. Zero declarers → no thread (exit 1); more than one →
# ambiguous, stop and ask (exit 2).
if [[ -z "$workstream_dir" ]]; then
    rel="${START_DIR#$WORKSPACE/}"
    if [[ "$rel" == projects/*/code/.worktrees/* ]]; then
        project_rel="${rel%%/code/.worktrees*}"        # projects/<path-to-project>
        wt_tail="${rel#*/code/.worktrees/}"
        wt_name="${wt_tail%%/*}"                        # <name>
        if [[ -n "$wt_name" ]]; then
            wt_dir_rel="code/.worktrees/$wt_name"
            project_dir="$WORKSPACE/$project_rel"
            declarers=()
            for _b in "$project_dir"/workstreams/*/BRIEF.md; do
                [[ -f "$_b" ]] || continue
                if grep -Eq "^[[:space:]]*(-[[:space:]]*)?dir:[[:space:]]*${wt_dir_rel}[[:space:]]*$" "$_b" 2>/dev/null; then
                    declarers+=("$(dirname "$_b")")
                fi
            done
            if [[ ${#declarers[@]} -eq 1 ]]; then
                workstream_dir="${declarers[0]}"
            elif [[ ${#declarers[@]} -gt 1 ]]; then
                echo "resolve-thread: worktree $wt_dir_rel is declared by ${#declarers[@]} workstreams — ambiguous." >&2
                echo "  Fix the duplicate 'worktrees:' declaration; a worktree belongs to one workstream." >&2
                exit 2
            fi
        fi
    fi
fi

if [[ -z "$workstream_dir" ]]; then
    exit 1
fi

# --- Verify BRIEF.md and thread_id ------------------------------------------

brief="$workstream_dir/BRIEF.md"
if [[ ! -f "$brief" ]]; then
    echo "resolve-thread: workstream dir has no BRIEF.md: $workstream_dir" >&2
    exit 2
fi

rel_workstream="${workstream_dir#$WORKSPACE/}"
expected_thread_id="claude-code:$rel_workstream"

# Extract a single thread_id-style field value. Accepts both spaced and
# unspaced forms, trims surrounding whitespace. Empty string if not present.
#
# Example matches (for FIELD=thread_id):
#   thread_id: claude-code:projects/foo/workstreams/bar
#   thread_id:claude-code:projects/foo/workstreams/bar
extract_field() {
    local field="$1"
    awk -v f="$field" '
        $0 ~ "^[[:space:]]*" f "[[:space:]]*:" {
            sub(/^[^:]*:[[:space:]]*/, "", $0)
            gsub(/[[:space:]]+$/, "", $0)
            print
            exit
        }
    ' "$brief"
}

# Resolution accepts two binding forms:
#
#   1. Primary binding — `thread_id: claude-code:projects/<p>/workstreams/<w>`
#      The workstream is "owned" by Claude Code; thread_id is canonical.
#
#   2. Dual binding — `thread_id` belongs to another platform (Slack, Discord,
#      Telegram, etc.) where humans collaborate, and a sibling field
#      `thread_id_claude_code: claude-code:projects/<p>/workstreams/<w>`
#      anchors the Claude Code adapter. Used when one workstream spans a
#      human-comms surface and an agent-ops surface.
#
# Either field matching the canonical `claude-code:` form for this directory
# is a successful bind. The framework spec (COMMUNICATION.md) only requires
# a single `thread_id`; `thread_id_claude_code` is this adapter's escape
# hatch for cross-platform workstreams.

primary_tid="$(extract_field thread_id)"
cc_tid="$(extract_field thread_id_claude_code)"

if [[ -z "$primary_tid" && -z "$cc_tid" ]]; then
    echo "resolve-thread: BRIEF.md has no thread_id or thread_id_claude_code: $brief" >&2
    echo "resolve-thread: expected one of them to equal: $expected_thread_id" >&2
    exit 2
fi

if [[ "$primary_tid" == "$expected_thread_id" || "$cc_tid" == "$expected_thread_id" ]]; then
    echo "$workstream_dir"
    exit 0
fi

echo "resolve-thread: thread_id mismatch in $brief" >&2
echo "  expected (in thread_id or thread_id_claude_code): $expected_thread_id" >&2
[[ -n "$primary_tid" ]] && echo "  thread_id:              $primary_tid" >&2
[[ -n "$cc_tid"      ]] && echo "  thread_id_claude_code:  $cc_tid" >&2
echo "  This usually means the workstream was moved or scaffolded elsewhere." >&2
echo "  Stop and ask the human — never guess." >&2
exit 2
