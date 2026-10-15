---
name: latest
repo: https://github.com/poktalabs/intern-os
metadata:
  version: 0.1.0
description: >-
  Load the latest status of the current internOS workstream, or, when not inside a workstream,
  the latest work done across the internOS project. Read-only: reads STATUS.md, the pick-up
  checkpoint, recent sessions, commits and tick tasks, then summarizes where things stand and
  the next step. Use when the user invokes /latest, or asks to "load the latest status",
  "where are we", "what's the latest" for a workstream or project.
---

# latest: load the latest status

Read-only. Never edit STATUS, DECISIONS, TICK or the checkpoint log here; saving is `/checkpoint`
and `/session-wrap`'s job.

## Step 1: Gather

Run the bundled script from the user's cwd:

```bash
bash ~/.claude/skills/latest/scripts/latest.sh
```

It resolves the scope with the intern-os `resolve-thread.sh` (so it also binds from inside a
declared `code/.worktrees/<name>/`) and prints one of:

- `MODE: workstream`: BRIEF status, the pick-up checkpoint (newest entry in
  `~/.claude/checkpoint-log.jsonl` under this workstream, plus the STATUS.md pointer), STATUS.md
  in full, the last 5 SESSIONS.md entries, recent commits touching the workstream, open tick tasks.
- `MODE: project`: the newest project checkpoint (logged and in `docs/checkpoints/`), every
  non-archived workstream ranked by its STATUS `updated:` date with its State line, recent commits,
  open project tick tasks.
- Exit 1 when the cwd is in neither. Say so and stop; do not guess a project.

## Step 2: Read the checkpoint

If a checkpoint path came back, read it: it is the cold-start map (locked decisions, open
questions, options). If the logged checkpoint and the STATUS pointer differ, read the newer one
and mention the other. If STATUS.md's `updated:` date is newer than the checkpoint, STATUS wins
for current state; the checkpoint still supplies decisions and options.

In project mode, also read the STATUS.md of the top one or two workstreams when the State line
is cut off or the next step is not clear from it.

## Step 3: Report

Short, lead with the answer:

- **Workstream:** where it stands (2-4 lines), the next step or open options, blockers and gates
  waiting on the human, and the checkpoint path as a clickable link.
- **Project:** what moved most recently (which workstreams, when, what), what is active vs
  winding down, the newest checkpoint, and which workstream looks like the natural next pick.

Flag drift you notice (STATUS over ~40 lines, a pointer to a missing file, uncommitted changes,
a workstream marked active with an old `updated:` date) in one line each; do not fix it here.
Then ask what to work on, unless the user already said.
