#!/usr/bin/env bash
#
# push-workstream.sh — commit a workstream's files and push them straight to
# the project repo's main branch, with conflict guardrails.
#
#   push-workstream.sh <workstream-dir> [summary]
#
# Guardrails:
#   - Stages only the workstream directory and the project's TICK.md. Refuses
#     if anything else is already staged.
#   - Rebases onto the remote branch before pushing (unrelated uncommitted
#     changes are autostashed and restored); never force-pushes.
#   - Conflicts in append-only logs (DECISIONS.md, SESSIONS.md, JOURNAL.md)
#     are resolved by keeping both sides (remote lines first).
#   - Any other conflict (STATUS.md, BRIEF.md, TICK.md, ...) is not guessed:
#     the commit goes to a chore/<workstream>-status-<timestamp> branch, a PR
#     is opened if `gh` is available, and the script exits 4.
#   - Before pushing, checks that the outgoing commits touch only allowed paths.
#
# Commit identity: Devin applies the user's "Git commit author" setting through
# a git wrapper in its own shell, which this script does not inherit. The script
# loads the same settings file, so its commits (and rebases) get that identity.
#
# Env: INTERNOS_PUSH_BRANCH (default main), INTERNOS_PUSH_REMOTE (default
# origin), INTERNOS_PUSH_RETRIES (default 3, for push races),
# INTERNOS_DEVIN_GIT_AUTHOR (default /opt/.devin/git_author).
#
# Exit codes:
#   0  pushed, or nothing to push
#   2  refused: something outside the workstream is staged
#   3  usage error
#   4  needs a human (conflict, outgoing commits touching other paths, or
#      repeated push rejection): pushed to a branch instead of main

set -euo pipefail

BRANCH="${INTERNOS_PUSH_BRANCH:-main}"
REMOTE="${INTERNOS_PUSH_REMOTE:-origin}"
RETRIES="${INTERNOS_PUSH_RETRIES:-3}"
APPEND_ONLY="DECISIONS.md SESSIONS.md JOURNAL.md"

ws_arg="${1:-}"
summary="${2:-session close}"
if [[ -z "$ws_arg" || ! -d "$ws_arg" || ! -f "$ws_arg/BRIEF.md" ]]; then
    echo "usage: push-workstream.sh <workstream-dir> [summary]" >&2
    exit 3
fi

ws_abs="$(cd "$ws_arg" && pwd -P)"
root="$(git -C "$ws_abs" rev-parse --show-toplevel)"
ws_rel="${ws_abs#"$root"/}"
ws_name="$(basename "$ws_abs")"
summary="${summary#"$ws_name: "}"
cd "$root"

commit_args=()
devin_git_author="${INTERNOS_DEVIN_GIT_AUTHOR:-/opt/.devin/git_author}"
if [[ -f "$devin_git_author" ]]; then
    # shellcheck source=/dev/null
    source "$devin_git_author"
    if [[ -n "${DEVIN_COMMIT_AUTHOR:-}" ]]; then
        commit_args+=(--author="$DEVIN_COMMIT_AUTHOR")
    fi
    if [[ -n "${DEVIN_COMMIT_TRAILER:-}" ]]; then
        commit_args+=(--trailer="$DEVIN_COMMIT_TRAILER")
    fi
fi

current="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$current" != "$BRANCH" ]]; then
    echo "push-workstream: project repo is on '$current', expected '$BRANCH'." >&2
    exit 3
fi

allowed() {
    local p="$1"
    [[ "$p" == "$ws_rel/"* || "$p" == "TICK.md" ]]
}

outside=""
while IFS= read -r p; do
    [[ -n "$p" ]] && ! allowed "$p" && outside+="  $p"$'\n'
done < <(git diff --cached --name-only)
if [[ -n "$outside" ]]; then
    echo "push-workstream: refusing, files outside $ws_rel are staged:" >&2
    printf '%s' "$outside" >&2
    exit 2
fi

git add -A -- "$ws_rel"
[[ -f TICK.md ]] && git add -- TICK.md
if git diff --cached --quiet; then
    if [[ -z "$(git log --oneline "$REMOTE/$BRANCH..HEAD" 2>/dev/null)" ]]; then
        echo "push-workstream: nothing to push."
        exit 0
    fi
else
    git commit -q ${commit_args[@]+"${commit_args[@]}"} -m "$ws_name: $summary"
fi

fallback() {
    git rebase --abort 2>/dev/null || true
    local b="chore/${ws_name}-status-$(date +%Y%m%d%H%M%S)-$(git rev-parse --short HEAD)"
    git branch "$b"
    git push -q "$REMOTE" "$b"
    git reset -q --keep "$REMOTE/$BRANCH"
    echo "push-workstream: $1" >&2
    echo "  Your commits are on branch $b (pushed). Local $BRANCH is reset to $REMOTE/$BRANCH." >&2
    if command -v gh >/dev/null 2>&1; then
        gh pr create --base "$BRANCH" --head "$b" --title "$ws_name: $summary (needs conflict resolution)" \
            --body "push-workstream.sh could not push to $BRANCH: $1" >&2 || true
    fi
    echo "  Tell the human; do not force-push." >&2
    exit 4
}

resolve_conflicts() {
    local f base
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        base="$(basename "$f")"
        if [[ " $APPEND_ONLY " != *" $base "* ]] || ! allowed "$f"; then
            return 1
        fi
        local tmp; tmp="$(mktemp -d)"
        git show ":1:$f" > "$tmp/base" 2>/dev/null || : > "$tmp/base"
        git show ":2:$f" > "$tmp/upstream" 2>/dev/null || : > "$tmp/upstream"
        git show ":3:$f" > "$tmp/ours" 2>/dev/null || : > "$tmp/ours"
        git merge-file --union -p "$tmp/upstream" "$tmp/base" "$tmp/ours" > "$f" || true
        rm -rf "$tmp"
        git add -- "$f"
    done < <(git diff --name-only --diff-filter=U)
}

attempt=0
while :; do
    attempt=$((attempt + 1))
    git fetch -q "$REMOTE" "$BRANCH"
    if ! git rebase -q --autostash "$REMOTE/$BRANCH" >/dev/null 2>&1; then
        [[ -d "$(git rev-parse --git-path rebase-merge)" || -d "$(git rev-parse --git-path rebase-apply)" ]] \
            || fallback "git rebase onto $REMOTE/$BRANCH failed"
        while :; do
            resolve_conflicts || fallback "conflict outside the append-only logs: $(git diff --name-only --diff-filter=U | tr '\n' ' ')"
            if GIT_EDITOR=true git rebase --continue >/dev/null 2>&1; then
                break
            fi
            [[ -n "$(git diff --name-only --diff-filter=U)" ]] || fallback "rebase failed"
        done
    fi

    while IFS= read -r p; do
        if [[ -n "$p" ]] && ! allowed "$p"; then
            fallback "outgoing commits touch $p, outside $ws_rel"
        fi
    done < <(git diff --name-only "$REMOTE/$BRANCH..HEAD")

    if git push -q "$REMOTE" "HEAD:$BRANCH" 2>/dev/null; then
        echo "push-workstream: pushed $ws_rel to $REMOTE/$BRANCH."
        exit 0
    fi
    if [[ "$attempt" -ge "$RETRIES" ]]; then
        fallback "push to $BRANCH rejected $attempt times"
    fi
done
