---
name: intern-os
description: internOS Workstreams framework. Coordinates work across projects, tick.md tasks, communication threads, and filesystem workstreams. Load this skill when operating in a workstream thread or when setting up internOS.
version: 1.1.1
repo: https://github.com/poktalabs/intern-os
prerequisites:
  commands: [tick]
setup:
  help: "Install tick-md with `npm install -g tick-md@1`. Then run `hermes setup` to configure internos.workspace_path."
metadata:
  hermes:
    tags: [Workstreams, Project Management, Coordination]
    related_skills: []
    config:
      - key: internos.workspace_path
        description: Path to a single internOS workspace (contains projects/) OR a workspaces container whose children are workspaces (canonically named "workspaces")
        default: "~/.hermes/workspace"
        prompt: internOS workspace or workspaces-container directory
---

# internOS — Workstreams

internOS is a framework for humans and agents to collaborate on workstreams without losing context between sessions. Each workstream exists in three places simultaneously: a tick.md task (management), a communication thread (collaboration), and a filesystem directory (source of truth).

## Install

| Framework | Command |
|-----------|---------|
| **Hermes Agent** | `hermes skills install poktalabs/intern-os/intern-os` |
| **OpenClaw** | `openclaw skills install https://github.com/poktalabs/intern-os` |
| **Claude Code** | Copy `adapters/claude-code/CLAUDE.md` to your project root |
| **Other** | See `adapters/generic/SETUP.md` |

After installing, follow your adapter's SETUP.md for framework-specific configuration.

## Project vs. workstream — when to use which

> A **project** is the top-level operating container in internOS.
> A **workstream** is a bounded unit of execution inside a project.

**Rule of thumb:**
- If the work requires more than one independent workstream, or involves an operational area with its own identity (infra, product, ops, content, etc.) → it's a **project**.
- If it's a scoped piece of work inside an existing area → it's a **workstream** within that project.

Projects are not thread-bound. Workstreams are thread-bound.

## Discovering a new project

Any team member can create a new project:

> Discover project: [name]

The agent:

1. Creates `projects/[name]/PROJECT.md` using the project template
2. Creates `projects/[name]/AGENTS.md` using the project agents template
3. Runs `tick init` and registers the agent
4. Opens a communication thread for the project

**Discovery questions:**
- **Who is the human owner?**
- **What is the main objective?**
- **What is the success criteria?**
- **When should this project be archived?**

If the human does not have an answer for a non-critical field, mark it as `TBD` in `PROJECT.md`.

## Project lifecycle

```
Discover project → PROJECT.md + AGENTS.md + tick init + thread
    → Workstreams activated within the project
        → All workstreams archived
            → PROJECT.md updated with final state
                → Project directory moved to projects/archived/
```

## The three layers

internOS operates across three explicit layers.

### Storage layer

The workstream files are the authoritative operational state. Not the transcript, not agent memory.

```text
projects/
  REGISTRY.md              ← Derived workstream index (generated, not hand-edited)
  [project-name]/
    PROJECT.md
    AGENTS.md
    TICK.md
    workstreams/
      [workstream-name]/
        BRIEF.md
        STATUS.md
        MEMORY.md
        DECISIONS.md
        STAKEHOLDERS.md
        RESOURCES.md
        docs/
    code/                  ← Container for the project's code repos (gitignored)
      README.md            ← Declares the code repo layout
      WORKTREES.md         ← Derived worktree ledger (generated, not hand-edited)
      [repo]/              ← Independent code repo (its own .git + remote)
      .worktrees/          ← Git worktrees for parallel/agent code work
        [name]/            ← Linked worktree of a code repo (branch per thread)
```

The `code/` container and worktrees are documented in `docs/specs/git-tracking.md`.

### Resolution layer

Resolution must be exact, deterministic, and non-heuristic.

1. Resolve by exact `thread_id` in `BRIEF.md`
2. If exact match exists, load that workstream
3. If no exact match exists, stop and ask — never guess
4. Never resolve by fuzzy matching, keyword similarity, or path proximity

`BRIEF.md` is the source of truth for thread-to-workstream binding. The derived registry at `projects/REGISTRY.md` provides operational lookup but is never authoritative — regenerate with `generate-registry.sh`.

#### Single workspace vs. workspaces container

`internos.workspace_path` (Hermes) / `INTERNOS_WORKSPACE` (Claude Code) may point at **either**:

- a **single workspace** — a directory that directly contains `projects/`; or
- a **workspaces container** — a directory whose immediate children are each workspaces (every child has its own `projects/`). Canonically named `workspaces` (e.g. `~/.hermes/workspaces`, `~/workspaces`). One gateway can then serve several independent workspaces.

**Detection is structural, not name-based:**
- If `<path>/projects/` exists → `<path>` is a single workspace.
- Else if any immediate child `<path>/*/projects/` exists → `<path>` is a container, and each such child is a workspace.

**Resolution in a container.** Resolve by exact `thread_id` across every workspace in the container — scan `<container>/*/projects/*/workstreams/*/BRIEF.md`. `thread_id` is globally unique (one thread → one workstream), so a single match is authoritative regardless of which workspace it lives in; the owning workspace is whichever child the match resolves under. A container only **widens the search set** — the exact / deterministic / non-heuristic matching rule is unchanged.

**Isolation still holds.** A container groups independent workspaces; it does not merge them. Don't read across workspaces (or projects) except to resolve the one workstream bound to the active thread. Cross-workspace synthesis must be explicit and human-requested.

**Creating things in a container.** New projects and workstreams are always created **inside a specific workspace** (`<container>/<workspace>/projects/...`), never at the container root (which has no `projects/`). When the target workspace is ambiguous, ask which one before scaffolding.

### Runtime layer

Load only what is needed for the current turn.

**Default loading policy (Tier 1):**
- `BRIEF.md`
- `STATUS.md`

**On-demand (Tier 2) — when task requires relationship or decision context:**
- `DECISIONS.md`
- `STAKEHOLDERS.md`

**On-demand (Tier 3) — when task requires accumulated or detailed context:**
- `MEMORY.md`
- `RESOURCES.md`
- `docs/*`

**Runtime rules:**
- No cross-workstream reads by default
- No broad scanning across `projects/`
- No heuristic fallback if binding is missing
- If session degrades, reconstruct from files — not from transcript continuity

## Operating a workstream

When in a communication thread that has a workstream context:

1. Resolve the workstream by exact `thread_id` match
2. Load `AGENTS.md` from the project directory (if it exists)
3. Read the workstream's files:
   - `BRIEF.md` — read in full (includes thread_id, project, identity)
   - `STATUS.md` — read in full (must be ≤10 lines by design; see **STATUS.md hygiene** below)
4. Escalate to `MEMORY.md` (last 80 lines only), `DECISIONS.md`, `STAKEHOLDERS.md`, or `RESOURCES.md` only when the task requires it
5. Check tasks: `tick list --tag [workstream-name]`
6. Claim the task: `tick claim TASK-X @agent-name`
7. Do the work
8. Update STATUS.md at the end of the session — **replace the current-state fields in place, never append a dated section** (see **STATUS.md hygiene** below)
9. If MEMORY.md exceeds 80 lines, consolidate — summary, not log. Target ≤50 lines.
10. Complete or release the task: `tick done TASK-X @agent-name`

### Platform startup protocol

**Rule: always emit acknowledgment before any file reads.** Never let file reads block the first response token.

| Platform | Startup mode | Rule |
|----------|-------------|------|
| Discord | **LIGHT** | ACK immediately → load BRIEF + STATUS → escalate only if needed |
| Slack | **LIGHT** | ACK immediately → load BRIEF + STATUS → escalate only if needed |
| Telegram / CLI | **FULL** | Load BRIEF + STATUS + MEMORY before first response |

**LIGHT mode startup contract:**
1. Emit ACK first (e.g. "on it, loading context...")
2. Load `BRIEF.md` (in full — includes thread_id and workstream identity)
3. Load `STATUS.md` (in full, ≤10 lines)
4. Load `MEMORY.md` only if the request requires prior context
5. If `MEMORY.md` exceeds threshold, load last 80 lines and note it was truncated

**MEMORY.md hygiene:**
- Hard limit: 80 lines; target: ≤50 lines
- Must be a curated summary — not a raw session log
- Detailed chronology goes in `docs/` notes, not MEMORY.md
- If size grows beyond threshold: consolidate before ending the session, not after
- `sync-check.sh` validates line count; agents are expected to self-enforce during sessions

### STATUS.md hygiene

STATUS.md is read in full by default every session (Tier 1) — its size is a recurring tax on every future session, not a one-time cost. Doctrine that isn't enforced drifts: one production workstream reached 1,050 lines / 143 KB before anyone noticed.

- **Never append a dated `## YYYY-MM-DD` section.** Per-session narrative → `SESSIONS.md` (append-only, one line per session), where the adapter has one. Content-worthy narrative → the workstream's `journals/` layer, if the adapter has one.
- **Always replace the current-state fields in place** — editing, not accumulating.
- **Overflow archive:** `JOURNAL.md` in the workstream directory holds old STATUS narrative verbatim, on-demand only — never auto-loaded.
- Adapters that pre-load STATUS.md at session start should cap that load (e.g. full file only under ~40 lines, else head + an oversized-file flag) so a bloated file costs a fixed amount, not an unbounded one — see the Claude Code adapter's `session-start.sh` for a reference implementation.

### Recovery doctrine

If a session is degraded, bloated, reset, or unhealthy:
- Reconstruct from workstream files
- Do not trust transcript continuity as source of truth
- `BRIEF.md` and `STATUS.md` must be sufficient to restart the workstream safely

### Isolation doctrine

By default:
- Do not read another workstream's files
- Do not search broadly across projects
- Do not infer from similar names

Cross-workstream synthesis must be explicit and requested by the human.

### Worktrees (code work)

When a workstream does real code work, operate in a **git worktree**, not the code repo's primary checkout:

- Worktrees live at `projects/[project]/code/.worktrees/<name>/` — one linked worktree of a code repo per hot thread or lane. Never build two threads in one checkout.
- Create/list/prune them with `intern-os/scripts/worktree.sh` (e.g. `worktree.sh create <name> --repo <code-repo>`). Do not rely on a harness's native `--worktree`, which forks the *project* repo (where `code/*` is gitignored) and yields an empty checkout.
- Declare a workstream's worktree(s) in its `BRIEF.md` `worktrees:` block (repo, dir, branch). This is the authoritative link; the derived `code/WORKTREES.md` ledger and the `projects/REGISTRY.md` count reconcile it against live git state.
- Cleanup is conservative and gated on merge: never remove a worktree with a dirty tree or unpushed commits.

Full mechanics — layout, naming, `.worktreeinclude` env-copy, harness/IDE compatibility — are in `docs/specs/git-tracking.md`.

## Activating a new workstream

Any team member can activate a workstream from any thread:

> Activate workstream: [name] in project: [project]

The agent creates what's missing: task in tick.md, communication thread, and workstream directory scaffold.

**Directory scaffold:**
```bash
PROJECT=project-name
WS=workstream-name
mkdir -p [workspace]/projects/$PROJECT/workstreams/$WS/docs
touch [workspace]/projects/$PROJECT/workstreams/$WS/{BRIEF.md,STATUS.md,MEMORY.md,DECISIONS.md,STAKEHOLDERS.md,RESOURCES.md}
```

> In a workspaces container, `[workspace]` is the chosen child workspace (`<container>/<workspace>`), never the container root. Ask which workspace if it's ambiguous.

Add the thread ID to BRIEF.md (mandatory):
```
thread_id: [platform]:[thread ID]
```

**Communication thread format:**
```
**[Workstream name]**

What: [one line]
Owner: [name]
Task: TASK-001
Directory: projects/[project]/workstreams/[name]/
Status: [current phase — one line]
```

## Workstream file structure

```
projects/[project]/workstreams/[name]/
├── BRIEF.md         ← Workstream identity + thread_id binding (mandatory)
├── STATUS.md        ← Operational heartbeat: phase, next, blockers
├── MEMORY.md        ← Durable context across sessions (≤80 lines)
├── DECISIONS.md     ← Key decisions log with date + rationale
├── STAKEHOLDERS.md  ← Relevant people and their role
├── RESOURCES.md     ← Artifact registry and where they live
├── JOURNAL.md       ← Overflow archive of old STATUS narrative (on-demand, never auto-loaded)
└── docs/            ← Working artifacts
```

## Project file structure

```
projects/[project]/
├── PROJECT.md       ← Project identity: purpose, scope, direction
├── AGENTS.md        ← Project-level agent context (optional)
├── TICK.md          ← Task management (tick.md)
├── .tick/
│   └── config.yml   ← tick.md configuration
├── workstreams/
└── code/            ← Container for code repos + worktrees (gitignored; optional)
    ├── README.md    ← Declares the code repo layout
    ├── WORKTREES.md ← Derived worktree ledger (generated)
    ├── [repo]/      ← Independent code repo (own .git + remote)
    └── .worktrees/  ← Git worktrees: code/.worktrees/<name>/ (one branch per thread)
```

The `code/` container, its `.gitignore` rules, and the worktree convention are specified in `docs/specs/git-tracking.md`.

## Isolated-session handoff (multi-agent)

When a coordinating agent delegates work to an isolated specialist (subagent) that does not inherit the parent's transcript or workstream binding, use the **handoff manifest** layer.

The coordinator writes a manifest file at `<workstream>/handoffs/<handoff_id>.yml` that names exactly what the specialist must load, what to do, and where to write back. The specialist verifies the binding deterministically (exact `thread_id` match in `BRIEF.md`, exact path existence) before any action — no fuzzy matching, no broad scans. Work returns as a file at `<workstream>/handoffs/<handoff_id>.md`; the coordinator owns reconciliation back into `STATUS.md` / `DECISIONS.md`.

**Specialist write scope is strict by doctrine.** Specialists may write only to:
- `handoffs/<handoff_id>.md` (return artifact)
- `handoffs/<handoff_id>/*` (optional sub-artifacts)
- `MEMORY.md` (bounded appends per the manifest)

Specialists never write `BRIEF.md`, `STATUS.md`, or `DECISIONS.md`. Those stay coordinator-owned so the operational heartbeat reflects the coordinator's view, not a specialist's intermediate state.

Full reference: `references/en/ISOLATED-HANDOFF.md` (Spanish: `references/es/`).
Schema: `schemas/handoff-v1.yaml`. Verifier: `scripts/verify-handoff.sh`.

## Tooling vs. doctrine

The resolution, runtime, recovery, and isolation rules above are **doctrine for agents to follow** — they depend on agents reading and respecting these instructions. They are not mechanically enforced by tooling.

What **is** validated by shipped tooling:
- `sync-check.sh` — validates file presence, `thread_id` format and uniqueness, BRIEF.md identity fields, STATUS.md / MEMORY.md size limits. Accepts a single workspace **or** a workspaces container (iterates every child workspace and enforces `thread_id` uniqueness across the whole container). Use `--rollout` for a prioritized action list.
- `generate-registry.sh` — generates derived workstream registry at `projects/REGISTRY.md`, including a per-project worktree count. Given a container, writes one registry per child workspace plus a container-level index.
- `worktree.sh` — creates/lists/prunes git worktrees under `code/.worktrees/` and writes the derived `code/WORKTREES.md` ledger. Prune never removes a worktree with a dirty tree or unpushed commits.
- `checkpoint-reminder.sh` — detects stale STATUS.md files
- `verify-handoff.sh` — verifies a handoff manifest against the four named binding checks (workstream_path, BRIEF.md, thread_id match, required load paths)
- `tick.md` — enforces task claim/release coordination

See FRAMEWORK.md for the full breakdown of what is validated vs. what is doctrine.

## Full documentation

- Framework: `references/en/FRAMEWORK.md`
- Playbook: `references/en/PLAYBOOK.md`
- Communication: `references/en/COMMUNICATION.md`
- tick.md integration: `references/en/TICK-INTEGRATION.md`
- Rollout protocol: `references/en/ROLLOUT.md`
- Isolated-session handoff: `references/en/ISOLATED-HANDOFF.md`
- Framework-specific setup: `adapters/[framework]/SETUP.md`
