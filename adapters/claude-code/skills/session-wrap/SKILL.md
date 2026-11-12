---
name: session-wrap
repo: https://github.com/poktalabs/intern-os
metadata:
  version: 0.5.0
description: >-
  Curated end-of-session wrap for internOS work. Use this whenever the user is closing out a
  working session or about to reset context — "wrap up", "end session", "save context", "let's
  close this", "save and clear", "wrap and clear", "I'm done for now", before a `/clear`, or
  before compacting a long session. It does the judgment work a SessionEnd hook can't: synthesize
  and record the session's decisions / learnings / insights / bugs / mistakes / commitments into
  gbrain, update the active internOS workstream files (STATUS, DECISIONS, journal, TICK), save
  durable Claude memories, write a dated pick-up checkpoint (a cold-start map of open work +
  per-workstream next steps + reference files), then ask whether to continue (compact) or clear
  (start fresh). Invoke proactively when the user signals a session boundary, even if they don't
  say "wrap".
---

# session-wrap — curated session-end lifecycle

The deterministic half of session-end runs automatically via hooks (the internOS `SessionEnd`
hook stamps `BRIEF.md` / `SESSIONS.md` / sync-check; the gbrain hook drops a breadcrumb to
`~/.claude/gbrain-session-queue.jsonl`). This skill is the **curated half** — the parts that need
your judgment about what mattered this session. Run it at a real session boundary.

Work through the steps in order. Each is conditional — skip what doesn't apply, and tell the user
what you skipped and why. Keep it tight; this is a wrap, not a second session.

## Step 0 — Orient

Read the latest breadcrumb to know what you're wrapping:
```
tail -1 ~/.claude/gbrain-session-queue.jsonl
```
It gives `cwd`, `project_dir` (the internOS project root, if any), `repo`, and `transcript_path`.
Resolve the active **project** and **workstream** from `cwd` (project root has `PROJECT.md`;
workstream is `…/workstreams/<name>/`). If there's no internOS project, this is a lighter wrap —
just memory + gbrain for anything notable, then the continue/clear question.

## Step 1 — Synthesize the session (the judgment)

From the actual conversation, distill — honestly, briefly — what's worth keeping:
- **Decisions** made (and the *why*).
- **Learnings / insights** (non-obvious things discovered).
- **Bugs** found/fixed and **mistakes** made (especially process mistakes worth not repeating).
- **Commitments / open items** (what's promised or pending, for whom, by when).

Don't pad. A session with one real decision gets one line. This synthesis feeds Steps 2-4.

## Step 2 — internOS files (source of truth, on disk)

For the active workstream:
- **STATUS.md** — REPLACE the "current state" + "next" fields in place. **Never append a dated
  `## YYYY-MM-DD` section** — STATUS is a heartbeat, not a log; per-session narrative belongs in
  `SESSIONS.md` (one line) or `journals/` below. If STATUS.md is already over ~40 lines when you
  open it, move the dated/narrative content to `JOURNAL.md` (verbatim, in the workstream
  directory) before writing your update — don't compound inherited bloat.
- **DECISIONS.md** — append load-bearing decisions (date, decision, why). Create if absent.
- **journals/** — if the workstream has build-in-public / content value, invoke the
  **`content-machine/journaling`** skill to capture this session's signal (changes, learnings,
  insights, proof) into the `journals/` layer. That skill owns the doctrine — stream selection,
  evidence-binding, `internal-only` default — so route the journaling there rather than hand-writing
  an entry here. Skip if the work was purely mechanical or has no content signal.
- **TICK.md** — only if task states changed. **GUARD FIRST:** `tick validate`; if it reports 0
  tasks but the file has tasks, it's a lookalike — back up + migrate to tick-native before any
  `tick` mutation, or you'll silently drop tasks (see memory `feedback-tick-lookalike-dataloss`).
  `tick done <id> <agent>` needs the agent arg.

Do **not** auto-commit git unless the user asks — surface what changed and let them commit.

## Step 3 — gbrain memory sync (curated, never a raw import)

Record the Step-1 synthesis into gbrain via the **MCP tools** (or CLI), not a blind import:
- `add_timeline_entry` on the project's gbrain page — a dated summary of the session (decisions,
  milestones, mistakes-not-to-repeat).
- `put_page` updates if a project/topic page's facts changed.
- For file changes to flow in, prefer the project's own pages; if a broader re-index is genuinely
  needed, use the **staging import workflow with exclusions** from `~/.claude/CLAUDE.md`
  ("Ingestion workflow") — NEVER a raw `gbrain import <workspace>` or `gbrain sync --repo
  <workspace>`: those pull `research/`, brain repos, `club/`, `node_modules`, etc. and pollute the
  brain. (That mistake cost an 859-page cleanup on 2026-05-28.)
- If `mcp__gbrain__*` is unavailable this session, use the `gbrain` CLI (`gbrain add-timeline` /
  `put`), or note in the breadcrumb queue that the gbrain sync is still pending.

## Step 4 — Claude memories

Per the auto-memory rules, save/update durable memories (user / feedback / project / reference)
for anything that will matter in *future* conversations — not ephemeral task state, not things
derivable from files or git. Prefer updating existing memories over adding duplicates.

## Step 5 — Pickup checkpoint (the cold-start file)

Write a dated checkpoint the user can point a fresh post-`/clear` session at to resume
**any** workstream cold. STATUS.md is a short status; this is the richer, branching
pickup map. Write it to the project's `docs/checkpoints/<YYYY-MM-DD>-checkpoint.md`
(`mkdir -p` the dir). If there's no internOS project, put it under
`~/.gstack/projects/<slug>/checkpoints/` instead and tell the user the path.

Skip only if the session was trivial (one mechanical change, nothing to resume) — say so.

The checkpoint must contain, in this order:
1. **Purpose line** — "point a fresh session here to pick up cold; read this first,
   then open the referenced files for the workstream you choose." Name the project +
   workstream + thread_id + owner.
2. **Where we are** — one paragraph: current state, what's done, what's the open gate.
3. **North Star / product shape** — the durable framing (skip if unchanged and already
   obvious from BRIEF.md; link it instead).
4. **Locked decisions** — numbered, each one line, flagged **do NOT re-litigate**, with
   a pointer to DECISIONS.md for the why. This is what stops a fresh session from
   re-opening settled calls.
5. **Open questions / decisions still to make** — the live forks.
6. **Workstream options** — the heart of the file. One subsection per viable next track
   (e.g. design / eng / build / ship / research / brand). For EACH: the **skill or
   command** to run, **what to decide first**, and the **exact reference files** to pull
   for that track. The user picks one and has everything to start.
7. **Reference file index** — every artifact path that matters (design doc, tasks,
   test plan, research, briefs, Claude memories, gbrain page slugs, reference code).
8. **Critical don't-forgets** — the few things that would cause real damage if missed
   (security-critical tests, the riskiest dependency to de-risk first, "copy nothing" rules).
9. **Pickup line** — a paste-ready instruction, e.g.:
   > "Read `docs/checkpoints/<date>-checkpoint.md`, then let's work on **[option A / B / C]**."

Then add a one-line pointer to the checkpoint at the TOP of the workstream's STATUS.md
(a blockquote `> **Pick-up checkpoint:** <relative-path> — read it first`), so a fresh
session that auto-loads STATUS surfaces the checkpoint immediately.

Keep it skimmable — headings + tight bullets, not prose. It is a map, not a memoir.

## Step 5b: Stop every server this session started

Before the closing message, stop what this session left running: dev servers (`bun --watch`,
`vite`, `next dev`, `node`), local databases or containers it started (e.g. `supabase start`,
`docker compose up`), browser daemons (gstack `$B` / browse server), tunnels, and background
tasks still alive. Use the project's own stop command when one exists (e.g.
`scripts/dev-bioagent.sh --stop`), otherwise kill by PID or port.

Only what THIS session started: check `lsof -nP -iTCP -sTCP:LISTEN` and each process's cwd /
start time, and leave anything older or from another session or project running (another
Claude session, the user's own apps, long-lived shared containers like a gbrain database).
Then confirm the ports are free and list what you stopped in the closing message. If unsure
whether a process is this session's, ask instead of killing it.

## Step 6 — Log + continue or clear

### 6a. Verify the handoff against the file — do this BEFORE writing the closing message

The closing message is written from what's salient in your head. The checkpoint was written
from the same reasoning, often an hour earlier. **Those two things drift, and the drift always
runs one way: you restate what's already in the file and present it as new.**

Before writing the wrap-up message, grep the artifact you just wrote for the specific facts
you're about to surface:

```bash
grep -n "<term1>\|<term2>\|<term3>" <checkpoint-path>
```

Then apply the rule:

- **Already in the file** → do not repeat it in the closing message. Point at the file instead.
- **Not in the file but matters to the next session** → it belongs in the FILE, not the message.
  Go back to Step 5 and add it, then continue.
- **Neither** → it's session-local colour. Say it or don't; it changes nothing.

Never close with "here are a few things the next session will need." If they're needed, they go
in the checkpoint. **Chat does not survive a `/clear`; files do.** A handoff fact delivered in
the one channel that gets discarded is worse than useless — it also implies the checkpoint has
gaps it doesn't have, which undermines trust in the artifact this whole skill exists to produce.

This is the same failure mode as designing against a stale clone: **trusting working memory over
reading the source.** It applies to your own output too, not just to repos and project files.

### 6b. Log — this line is what the next session sees

Append one line to `~/.claude/checkpoint-log.jsonl` (shared with `/checkpoint`, so `tail
~/.claude/checkpoint-log.jsonl` traces every save across both skills).

**This is not just a log.** The `SessionStart` hook
`~/.claude/hooks/latest-checkpoint-pointer.sh` reads the newest entry carrying a
`checkpoint_path` and renders a pointer at the start of every future session. The hook is
deliberately dumb — it hardcodes no project, path, or date, and derives everything from these
fields. **If you want a future session to notice something, put it here; do not edit the hook.**

```bash
printf '%s\n' "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"type\":\"session-wrap\",\"cwd\":\"$PWD\",\"project\":\"<project-or-null>\",\"workstream\":\"<workstream-or-null>\",\"checkpoint_path\":\"<absolute path written in Step 5>\",\"scope\":\"<what this checkpoint covers>\",\"summary\":\"<one line>\"}" >> ~/.claude/checkpoint-log.jsonl
```

If the optional cost tracker is installed (see Notes), record this wrap's own token cost. The
`PreToolUse` hook stamped the span start when this skill was invoked; close it (session id +
transcript are in the breadcrumb). This is a no-op if the tracker isn't installed:

```bash
CLOSE=~/.claude/skills/session-wrap/scripts/skill-span-close.sh
if [ -x "$CLOSE" ]; then
  SESSION_ID="$(tail -1 ~/.claude/gbrain-session-queue.jsonl | jq -r .session_id)"
  "$CLOSE" session-wrap "$SESSION_ID"
fi
```

It appends a costed record to `~/.claude/cost-log.jsonl` and prints a one-line
`session-wrap: $X.XX (in/out/cache tokens)` summary. Quote that real figure in the closing
message instead of estimating. (Dollar amounts depend on
`~/.claude/skills/session-wrap/scripts/cost-pricing.json`; token counts are exact regardless.)

Field notes:
- **`checkpoint_path`** — absolute path to the Step-5 file. **Required**, or the hook stays
  silent and the checkpoint is undiscoverable. Verify it exists before logging.
- **`scope`** — human-readable coverage, written for someone with no context. For a
  single-workstream session, name the workstream. For a session spanning several projects,
  name them: `"frutero/devrel (ai-for-healthcare, nebius, forward-deployed-series) + poktalabs/regen"`.
  This is what tells a fresh session whether the checkpoint is relevant to what they are
  about to do.
- **`summary`** — one line, and assume it is read cold.

The hook suppresses pointers older than 30 days and skips entries whose file has moved or been
deleted, so stale or broken paths cost nothing.

### 6c. Ask

Then end with one AskUserQuestion:
- **Continue (compact)** — keep working; context compacts but the thread continues.
- **Clear (fresh start)** — reset context. On the next session the **SessionStart hook +
  intern-os skill auto-load** the pwd's project/workstream, and `/session-wrap`'s breadcrumb +
  the updated STATUS + the Step-5 checkpoint get them back up to speed. Safe to clear
  *because* Steps 1-5 just persisted everything.

Recommend **clear** if the work reached a natural boundary and Steps 1-5 captured it; recommend
**continue** if mid-task with hot context worth keeping. Make the call, let the user decide.

## Notes

- This skill composes existing pieces — it doesn't replace the hooks, the `tick-notion-sync`
  skill, or `/context-save`; it's the human-judgment orchestration layer over them.
- Everything it writes is on disk / in gbrain / in memory — all durable across the clear.
- **Cost tracking (optional).** `scripts/` ships a per-execution token/cost tracker for this
  skill's own runs: `skill-span-start.sh` (bracket start), `tally-span-cost.sh` (diffs transcript
  usage against `scripts/cost-pricing.json`), `skill-span-close.sh` (tallies + appends to
  `~/.claude/cost-log.jsonl`, called from Step 6b). To enable it, add a `PreToolUse` hook with
  matcher `"Skill"` pointing at
  `~/.claude/skills/session-wrap/scripts/skill-span-start.sh` in `~/.claude/settings.json`
  (alongside the `SessionStart`/`SessionEnd` blocks from `hooks/settings.json`). Without the
  hook, Step 6b's cost-close call silently no-ops. Rates in `cost-pricing.json` are published
  tiers, not fetched live — verify before trusting dollar figures; token counts are exact
  regardless.
