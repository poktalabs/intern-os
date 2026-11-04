#!/usr/bin/env bash
#
# worktree.sh — internOS git-worktree helper (v1.1.0)
#
# internOS keeps real code in nested, gitignored repos at
# `projects/<project>/code/<repo>/`. Parallel and agent-driven code work uses
# git worktrees, created as LINKED WORKTREES of a code repo but parked in one
# shared directory beside the repos:
#
#     projects/<project>/code/.worktrees/<name>/
#
# This location is already ignored by the project repo's `code/*` rule, and
# because it sits BESIDE — not inside — the code repos, it never pollutes any
# repo's `git status` and needs no per-repo `.gitignore` change. The shared
# dir does not encode which code repo owns each worktree, so ownership is
# discovered here via `git worktree list` and declared per workstream in
# BRIEF.md (`worktrees:` block).
#
# This script is the single home for internOS worktree logic. Subcommands:
#
#   create <name> --repo <repo> [--branch <branch>] [--base <ref>]
#                 Create code/.worktrees/<name> as a linked worktree of
#                 code/<repo>, on a new branch. Copies gitignored files listed
#                 in the code repo's optional `.worktreeinclude` file.
#
#   list [--count]
#                 List every worktree under code/.worktrees/ across all code
#                 repos in the project, with owning repo, branch, HEAD,
#                 declaring workstream, and dirty/ahead flags. --count prints
#                 just the number (used by generate-registry.sh).
#
#   prune [--dry-run] [--yes]
#                 Show worktrees that are safe to remove (clean tree AND fully
#                 pushed). Removes them only with --yes. NEVER removes a
#                 worktree with a dirty tree or unpushed commits.
#
#   ledger        Write the derived per-project ledger code/WORKTREES.md.
#
# Global option: --project <path>  Project root (dir containing code/). When
#                omitted, the nearest ancestor of $PWD that contains a code/
#                directory is used.
#
# Usage:
#   worktree.sh create <name> --repo <repo> [--branch <b>] [--base <ref>] [--project <p>]
#   worktree.sh list [--count] [--project <p>]
#   worktree.sh prune [--dry-run] [--yes] [--project <p>]
#   worktree.sh ledger [--project <p>]
#
# Exit: 0 success, 1 runtime error, 2 usage error.

set -euo pipefail

WORKTREES_SUBDIR="code/.worktrees"
LEDGER_REL="code/WORKTREES.md"

# --- Logging ----------------------------------------------------------------

log()  { echo "$*" >&2; }
die()  { echo "worktree: $*" >&2; exit 1; }
usage_die() { echo "worktree: $*" >&2; exit 2; }

# --- Project-root resolution ------------------------------------------------
#
# A project root is the directory that contains `code/` (i.e.
# projects/<project>/). Walk up from a starting dir until one is found. Works
# from the project root, a code repo, or inside a worktree.
resolve_project_root() {
    local explicit="$1" start="$2"
    if [[ -n "$explicit" ]]; then
        [[ -d "$explicit" ]] || die "project path not found: $explicit"
        [[ -d "$explicit/code" ]] || die "not a project root (no code/): $explicit"
        (cd "$explicit" && pwd -P)
        return 0
    fi
    local cur
    cur="$(cd "$start" && pwd -P)"
    while [[ "$cur" != "/" ]]; do
        [[ -d "$cur/code" ]] && { echo "$cur"; return 0; }
        cur="$(dirname "$cur")"
    done
    die "no project root found above $start (expected an ancestor containing code/). Pass --project."
}

# List code repos in a project: immediate subdirs of code/ that are git repos,
# excluding the .worktrees parking dir. Prints one absolute path per line.
list_code_repos() {
    local project_root="$1" d
    for d in "$project_root"/code/*/; do
        [[ -d "$d" ]] || continue
        d="${d%/}"
        [[ "$(basename "$d")" == ".worktrees" ]] && continue
        # A code repo has git metadata (dir or worktree gitlink file).
        [[ -e "$d/.git" ]] || continue
        echo "$d"
    done
}

# Find the workstream that declares a given worktree dir, by scanning BRIEF.md
# `worktrees:` blocks for the project-relative dir path. Prints the workstream
# name, or empty if none / ambiguous. Exact substring match on the declared
# `dir:` value — deterministic, no fuzzy matching.
declaring_workstream() {
    local project_root="$1" rel_dir="$2" brief name matches=()
    for brief in "$project_root"/workstreams/*/BRIEF.md; do
        [[ -f "$brief" ]] || continue
        # Look for a `dir:` line (optionally commented-out is ignored) whose
        # value is exactly the worktree's project-relative path.
        if grep -Eq "^[[:space:]]*(-[[:space:]]*)?dir:[[:space:]]*${rel_dir}[[:space:]]*$" "$brief" 2>/dev/null; then
            name="$(basename "$(dirname "$brief")")"
            matches+=("$name")
        fi
    done
    [[ ${#matches[@]} -eq 1 ]] && echo "${matches[0]}"
    return 0
}

# --- Worktree enumeration ---------------------------------------------------
#
# Emit one TSV row per worktree under code/.worktrees/, across all code repos:
#   repo \t name \t dir_rel \t branch \t head \t dirty \t ahead \t workstream
# where dirty ∈ {clean,dirty}, ahead = count of commits not reachable from the
# upstream (or "?" when there is no upstream / cannot compute).
enumerate_worktrees() {
    local project_root="$1"
    local wt_root="$project_root/$WORKTREES_SUBDIR"
    [[ -d "$wt_root" ]] || return 0

    local repo line wt_path branch head name rel_dir dirty ahead ws
    while IFS= read -r repo; do
        # Parse `git worktree list --porcelain` blocks for this repo.
        wt_path=""; branch=""; head=""
        while IFS= read -r line; do
            case "$line" in
                "worktree "*) wt_path="${line#worktree }" ;;
                "HEAD "*)     head="${line#HEAD }" ;;
                "branch "*)   branch="${line#branch }"; branch="${branch#refs/heads/}" ;;
                "detached")   branch="(detached)" ;;
                "")
                    _emit_row "$project_root" "$repo" "$wt_path" "$branch" "$head"
                    wt_path=""; branch=""; head=""
                    ;;
            esac
        done < <(git -C "$repo" worktree list --porcelain 2>/dev/null)
        # Flush a trailing block with no blank line after it.
        [[ -n "$wt_path" ]] && _emit_row "$project_root" "$repo" "$wt_path" "$branch" "$head"
    done < <(list_code_repos "$project_root")
    return 0
}

# Helper: filter to worktrees under code/.worktrees/ and print the TSV row.
_emit_row() {
    local project_root="$1" repo="$2" wt_path="$3" branch="$4" head="$5"
    local wt_root="$project_root/$WORKTREES_SUBDIR"
    # Normalize and keep only worktrees inside the shared parking dir.
    case "$wt_path/" in
        "$wt_root"/*) : ;;
        *) return 0 ;;
    esac
    local name rel_dir dirty ahead ws
    name="$(basename "$wt_path")"
    rel_dir="${wt_path#$project_root/}"
    if [[ -n "$(git -C "$wt_path" status --porcelain 2>/dev/null)" ]]; then
        dirty="dirty"
    else
        dirty="clean"
    fi
    ahead="?"
    if git -C "$wt_path" rev-parse '@{u}' >/dev/null 2>&1; then
        ahead="$(git -C "$wt_path" rev-list --count '@{u}..HEAD' 2>/dev/null || echo '?')"
    fi
    ws="$(declaring_workstream "$project_root" "$rel_dir")"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$(basename "$repo")" "$name" "$rel_dir" "${branch:-?}" \
        "${head:0:9}" "$dirty" "$ahead" "${ws:-—}"
}

# --- Subcommand: create -----------------------------------------------------

cmd_create() {
    local name="" repo="" branch="" base="" project=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --repo)    repo="${2:-}"; shift 2 ;;
            --branch)  branch="${2:-}"; shift 2 ;;
            --base)    base="${2:-}"; shift 2 ;;
            --project) project="${2:-}"; shift 2 ;;
            --*)       usage_die "unknown option: $1" ;;
            *)         [[ -z "$name" ]] && name="$1" || usage_die "unexpected arg: $1"; shift ;;
        esac
    done

    [[ -n "$name" ]] || usage_die "create: <name> is required"
    [[ "$name" =~ ^[a-z0-9][a-z0-9._-]*$ ]] || usage_die "create: <name> must be kebab-case ([a-z0-9._-]): $name"
    [[ -n "$repo" ]] || usage_die "create: --repo <code-repo> is required"

    local project_root code_repo wt_path
    project_root="$(resolve_project_root "$project" "$PWD")"
    code_repo="$project_root/code/$repo"
    [[ -d "$code_repo" ]] || die "code repo not found: code/$repo (under $project_root)"
    [[ -e "$code_repo/.git" ]] || die "not a git repo: code/$repo"

    branch="${branch:-feat/$name}"
    # Branch doctrine (FRAMEWORK.md "Code repository doctrine"): work branches
    # carry a conventional prefix; integration branches (main, staging) are
    # never created as worktree branches.
    [[ "$branch" =~ ^(feat|fix|chore|docs|refactor|test|perf)/[a-z0-9][a-z0-9._-]*$ ]] \
        || die "branch '$branch' must be feat/|fix/|chore/|docs/|refactor/|test/|perf/<kebab-name>"
    wt_path="$project_root/$WORKTREES_SUBDIR/$name"
    [[ -e "$wt_path" ]] && die "worktree path already exists: $WORKTREES_SUBDIR/$name"

    # Default base = the code repo's current HEAD (predictable, no network).
    if [[ -z "$base" ]]; then
        base="$(git -C "$code_repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)"
    fi

    mkdir -p "$project_root/$WORKTREES_SUBDIR"
    log "Creating worktree: $WORKTREES_SUBDIR/$name  [branch $branch, from $base, repo $repo]"
    git -C "$code_repo" worktree add "$wt_path" -b "$branch" "$base" >&2

    apply_worktreeinclude "$code_repo" "$wt_path"

    echo "$wt_path"
    log ""
    log "Worktree ready. Next steps:"
    log "  1. Declare it in the workstream's BRIEF.md:"
    log "       worktrees:"
    log "         - repo: $repo"
    log "           dir: $WORKTREES_SUBDIR/$name"
    log "           branch: $branch"
    log "  2. Install deps in the worktree if needed (fresh checkout: tracked files only)."
    log "  3. Refresh the ledger:  worktree.sh ledger --project \"$project_root\""
}

# Copy gitignored files listed in the code repo's `.worktreeinclude` into a
# fresh worktree. `.worktreeinclude` uses .gitignore-style lines; only files
# that both match a listed pattern AND are gitignored are copied (tracked
# files are never duplicated). Matches the Hermes / Claude Code convention.
apply_worktreeinclude() {
    local code_repo="$1" wt_path="$2"
    local inc="$code_repo/.worktreeinclude"
    [[ -f "$inc" ]] || return 0

    # All gitignored, untracked files in the code repo (relative paths).
    # bash 3.2-compatible read loop (no mapfile).
    local ignored=() _f
    while IFS= read -r _f; do
        [[ -n "$_f" ]] && ignored+=("$_f")
    done < <(git -C "$code_repo" ls-files --others --ignored --exclude-standard 2>/dev/null || true)
    [[ ${#ignored[@]} -eq 0 ]] && return 0

    local pat f copied=0 base
    while IFS= read -r pat || [[ -n "$pat" ]]; do
        pat="${pat%%#*}"                    # strip comments
        pat="${pat#"${pat%%[![:space:]]*}"}" # ltrim
        pat="${pat%"${pat##*[![:space:]]}"}" # rtrim
        [[ -z "$pat" ]] && continue
        for f in "${ignored[@]}"; do
            base="${f##*/}"
            # gitignore semantics (subset): full-path glob match, or basename
            # match when the pattern has no slash.
            # shellcheck disable=SC2053
            if [[ "$f" == $pat ]] || { [[ "$pat" != */* ]] && [[ "$base" == $pat ]]; }; then
                mkdir -p "$wt_path/$(dirname "$f")"
                cp -p "$code_repo/$f" "$wt_path/$f" 2>/dev/null && copied=$((copied+1))
            fi
        done
    done < "$inc"
    [[ $copied -gt 0 ]] && log "Copied $copied gitignored file(s) per .worktreeinclude."
    return 0
}

# --- Subcommand: list -------------------------------------------------------

cmd_list() {
    local count_only=false project=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --count)   count_only=true; shift ;;
            --project) project="${2:-}"; shift 2 ;;
            --*)       usage_die "unknown option: $1" ;;
            *)         usage_die "unexpected arg: $1" ;;
        esac
    done

    local project_root
    project_root="$(resolve_project_root "$project" "$PWD")"

    local rows
    rows="$(enumerate_worktrees "$project_root")"

    if $count_only; then
        [[ -z "$rows" ]] && { echo 0; return 0; }
        echo "$rows" | grep -c . || echo 0
        return 0
    fi

    if [[ -z "$rows" ]]; then
        log "No worktrees under $WORKTREES_SUBDIR/ in $(basename "$project_root")."
        return 0
    fi

    # Build the display table (TSV), then pretty-print with `column` when it is
    # available, falling back to raw TSV on minimal systems that lack it.
    local table
    table="$(
        printf 'REPO\tWORKTREE\tBRANCH\tHEAD\tSTATE\tAHEAD\tWORKSTREAM\n'
        # cols: repo name dir branch head dirty ahead ws  -> drop dir for display
        while IFS=$'\t' read -r repo name _dir branch head dirty ahead ws; do
            printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                "$repo" "$name" "$branch" "$head" "$dirty" "$ahead" "$ws"
        done <<< "$rows"
    )"
    if command -v column >/dev/null 2>&1; then
        printf '%s\n' "$table" | column -t -s "$(printf '\t')"
    else
        printf '%s\n' "$table"
    fi
}

# --- Subcommand: prune ------------------------------------------------------

cmd_prune() {
    local dry_run=false do_yes=false project=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run) dry_run=true; shift ;;
            --yes)     do_yes=true; shift ;;
            --project) project="${2:-}"; shift 2 ;;
            --*)       usage_die "unknown option: $1" ;;
            *)         usage_die "unexpected arg: $1" ;;
        esac
    done

    local project_root rows
    project_root="$(resolve_project_root "$project" "$PWD")"
    rows="$(enumerate_worktrees "$project_root")"
    [[ -z "$rows" ]] && { log "No worktrees to prune."; return 0; }

    local removable=() kept=0
    while IFS=$'\t' read -r repo name dir branch head dirty ahead ws; do
        # Safe to remove ONLY when the tree is clean AND fully pushed
        # (upstream exists and 0 commits ahead). Anything else is kept.
        if [[ "$dirty" == "clean" && "$ahead" == "0" ]]; then
            removable+=("$repo|$name|$dir|$branch")
        else
            kept=$((kept+1))
            log "KEEP  $name  [$dirty, ahead=$ahead, branch=$branch] — has unmerged/unpushed work or changes"
        fi
    done <<< "$rows"

    if [[ ${#removable[@]} -eq 0 ]]; then
        log "Nothing safe to prune ($kept worktree(s) kept)."
        return 0
    fi

    local entry repo name dir branch code_repo
    for entry in "${removable[@]}"; do
        IFS='|' read -r repo name dir branch <<< "$entry"
        if $dry_run || ! $do_yes; then
            log "PRUNE (candidate)  $name  [branch=$branch, repo=$repo]"
        else
            code_repo="$project_root/code/$repo"
            log "Removing worktree $dir ..."
            git -C "$code_repo" worktree remove "$project_root/$dir" >&2 \
                && log "  removed $name"
        fi
    done

    if ! $dry_run && ! $do_yes; then
        log ""
        log "Dry classification only. Re-run with --yes to remove the ${#removable[@]} candidate(s)."
    fi
}

# --- Subcommand: ledger -----------------------------------------------------

cmd_ledger() {
    local project=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --project) project="${2:-}"; shift 2 ;;
            --*)       usage_die "unknown option: $1" ;;
            *)         usage_die "unexpected arg: $1" ;;
        esac
    done

    local project_root ledger rows count
    project_root="$(resolve_project_root "$project" "$PWD")"
    ledger="$project_root/$LEDGER_REL"
    rows="$(enumerate_worktrees "$project_root")"
    count=0
    [[ -n "$rows" ]] && count="$(echo "$rows" | grep -c . || echo 0)"

    {
        echo "# Worktree Ledger — $(basename "$project_root")"
        echo ""
        echo "> **Derived from \`git worktree list\` + BRIEF.md declarations — do not edit manually.**"
        echo "> Regenerate: \`bash intern-os/scripts/worktree.sh ledger --project <project>\`"
        echo ""
        echo "Worktrees live at \`$WORKTREES_SUBDIR/<name>/\` — linked worktrees of a code repo,"
        echo "parked in one shared directory beside the repos. See \`docs/specs/git-tracking.md\`."
        echo ""
        if [[ "$count" -eq 0 ]]; then
            echo "_No active worktrees._"
        else
            echo "| Repo | Worktree | Branch | HEAD | State | Ahead | Workstream |"
            echo "|------|----------|--------|------|-------|-------|------------|"
            while IFS=$'\t' read -r repo name _dir branch head dirty ahead ws; do
                echo "| $repo | \`$name\` | \`$branch\` | \`$head\` | $dirty | $ahead | $ws |"
            done <<< "$rows"
        fi
    } > "$ledger"

    log "Ledger written: $LEDGER_REL ($count worktree(s))"
}

# --- Dispatch ---------------------------------------------------------------

[[ $# -ge 1 ]] || usage_die "usage: worktree.sh {create|list|prune|ledger} [options]"

sub="$1"; shift
case "$sub" in
    create) cmd_create "$@" ;;
    list)   cmd_list "$@" ;;
    prune)  cmd_prune "$@" ;;
    ledger) cmd_ledger "$@" ;;
    -h|--help|help)
        sed -n '2,60p' "$0" | sed 's/^# \{0,1\}//'
        ;;
    *) usage_die "unknown subcommand: $sub" ;;
esac
