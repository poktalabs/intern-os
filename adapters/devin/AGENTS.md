## internOS — Workstreams (Devin)

This repo is an internOS project. Its workstreams live in `workstreams/<name>/`.
On Devin, this project is reachable as
`$INTERNOS_WORKSPACE/projects/<project>/` (see the project's Devin blueprint).

### Resolution (do this first)

Devin session IDs change every session, so a session binds a workstream by the
exact path the human names, e.g. `projects/<project>/workstreams/<name>`.

1. Acknowledge the human first. Never let file reads delay the first reply.
2. Run `resolve-workstream.sh --load <path>` (on PATH after setup).
   - Exit 0: the output is project `AGENTS.md`, `BRIEF.md`, `STATUS.md`. Work from it.
   - Exit 1: no workstream at that path. Stop and ask.
   - Exit 2: BRIEF.md is missing, or its `thread_id` / `thread_id_devin` is not
     `devin:<path>`. Stop and ask. Do not edit BRIEF.md to make it match.
3. If the human named no workstream, do not look for one. Work normally.

Never resolve by fuzzy name, keyword, recent activity, or a directory listing.
Never use your session ID as a binding.

### Loading order

Project `AGENTS.md` → `BRIEF.md` → `STATUS.md` (the resolver prints all three).
Read `DECISIONS.md`, `STAKEHOLDERS.md`, `MEMORY.md` (last 80 lines),
`RESOURCES.md` or `docs/` only when the task needs them. Do not read other
workstreams. If the session degrades, rebuild context from these files, not
from the transcript.

### While working

- `git pull` the project repo before starting.
- Claim the task: `tick claim TASK-X @devin`.
- Code work happens in the code repo's own clone on a `feat/` / `fix/` /
  `chore/` / `docs/` / `refactor/` / `test/` / `perf/` branch. Never commit to
  `main` or `staging`.

### Before ending the session (required, even if nothing changed)

1. If you claimed a task: `tick done TASK-X @devin` or `tick release TASK-X @devin`.
2. Replace the current-state fields of `STATUS.md` in place (≤10 lines).
   Never append a dated section.
3. Append new decisions to `DECISIONS.md`. Consolidate `MEMORY.md` if it is
   over 80 lines.
4. Append one line to `SESSIONS.md`:
   `<YYYY-MM-DD HH:MM> · devin:<session-id> · <one-line summary>`.
5. `bash "$INTERNOS_HOME/intern-os/scripts/sync-check.sh" --workstream <dir>`.
6. Commit the workstream files and push them as this project's rules allow
   (default: a `chore/<workstream>-status` branch and a PR).

Credentials come from Devin Secrets. Never write a secret value into a
workstream file; `RESOURCES.md` may name a secret, never hold it.
