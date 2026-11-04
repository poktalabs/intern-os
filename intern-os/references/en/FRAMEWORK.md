# internOS — Workstreams Framework

*Version: 1.1.0 | Date: 2026-08-16 | Status: stable — adds git-worktree support for code work (code/.worktrees/)*

---

## The system in one line

Every workstream is a bounded unit of execution that maps to exactly one communication thread, carries active state in structured files, and can be reconstructed independently from those files.

---

## The three layers

internOS operates across three explicit layers.

### 1. Storage layer

The workstream files are the authoritative operational state. Not the transcript, not agent memory.

| Component | What it stores |
|-----------|---------------|
| `PROJECT.md` | Project identity: purpose, scope, direction |
| `AGENTS.md` | Project-level agent context: stack, conventions, people |
| `TICK.md` | Task management: what needs doing, who's doing it |
| Workstream files | Operational state: identity, status, memory, decisions, people, resources |
| `REGISTRY.md` | Derived workstream index: all non-archived workstreams, thread bindings, health (generated, not hand-edited) |

### 2. Resolution layer

Resolution must be exact, deterministic, and non-heuristic.

**Canonical rule:** Each workstream declares its bound communication thread in `BRIEF.md`:

```
thread_id: discord:1491150845675438110
```

**Resolution rules:**
1. Resolve by exact `thread_id`
2. If exact match exists, load that workstream
3. If no exact match exists, stop and ask — or bind
4. Never resolve by fuzzy matching, keyword similarity, or path proximity

**Source of truth:** `BRIEF.md` is the source of truth for thread-to-workstream binding. The derived registry at `projects/REGISTRY.md` provides operational lookup but is never authoritative — regenerate it with `generate-registry.sh`.

**Single workspace vs. workspaces container:** the configured workspace path (`internos.workspace_path` in Hermes, `INTERNOS_WORKSPACE` in Claude Code) may be **either** a single workspace (a directory that directly contains `projects/`) **or** a workspaces container — a directory whose immediate children are each workspaces (canonically named `workspaces`, e.g. `~/.hermes/workspaces`, `~/workspaces`). Detection is structural, not name-based: `<path>/projects/` present → single workspace; absent but `<path>/*/projects/` present → container. In container mode, resolution scans `<container>/*/projects/*/workstreams/*/BRIEF.md` — the same exact-match rule, only over a wider set, since `thread_id` is globally unique. A container groups independent workspaces without merging them; the isolation doctrine applies across workspaces exactly as across projects, and new projects/workstreams are created inside a chosen child workspace, never at the container root.

### 3. Runtime layer

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
- If session degrades, reconstruct from files rather than relying on transcript continuity

---

## Project structure

Each project is a self-contained directory:

```
projects/
├── project-alpha/
│   ├── PROJECT.md           ← Project identity: purpose, scope, direction
│   ├── AGENTS.md            ← Project-level agent context (optional)
│   ├── TICK.md              ← tick-md: all tasks for this project
│   ├── .tick/
│   │   └── config.yml       ← tick-md configuration
│   ├── workstreams/
│   │   ├── feature-x/
│   │   │   ├── BRIEF.md
│   │   │   ├── STATUS.md
│   │   │   ├── MEMORY.md
│   │   │   ├── DECISIONS.md
│   │   │   ├── STAKEHOLDERS.md
│   │   │   ├── RESOURCES.md
│   │   │   └── docs/
│   │   └── bug-fix-y/
│   │       └── ...
│   ├── docs/                ← project-level artifacts
│   └── code/                ← code repos + worktrees (gitignored; optional)
│       ├── README.md        ← declares the code repo layout
│       ├── WORKTREES.md     ← derived worktree ledger (generated)
│       ├── engine/          ← an independent code repo (own .git + remote)
│       └── .worktrees/      ← git worktrees: code/.worktrees/<name>/
└── project-beta/
    ├── PROJECT.md
    ├── AGENTS.md
    ├── TICK.md
    ├── .tick/
    └── workstreams/
```

Projects are not thread-bound. Workstreams are thread-bound.

### AGENTS.md — Project-level agent context

`AGENTS.md` at the project root provides context that applies to all workstreams in the project:

- Technology stack and coding conventions
- Key people and their roles
- Project-specific communication rules
- Active integrations (APIs, platforms)
- Architectural constraints or invariants

**Loading behavior:** When an agent enters a workstream thread, it loads `AGENTS.md` from the parent project directory before loading workstream files. If the file does not exist, the agent continues normally.

**Loading order:**
1. `projects/[project]/AGENTS.md` — project-level context
2. `projects/[project]/workstreams/[name]/BRIEF.md` — workstream identity
3. `projects/[project]/workstreams/[name]/STATUS.md` — current state
4. Escalate to other files only when needed

This separates project context from workstream context, avoids repeating project information in every BRIEF.md, and works on all platforms (no dependency on `cwd`).

### Workstream file structure

Each workstream has a directory with 6 standard files:

```
workstreams/[name]/
├── BRIEF.md         ← Workstream identity + thread_id binding (mandatory)
├── STATUS.md        ← Operational heartbeat: phase, next, blockers
├── MEMORY.md        ← Durable context across sessions (≤80 lines)
├── DECISIONS.md     ← Key decisions log with date + rationale
├── STAKEHOLDERS.md  ← Relevant people and their role
├── RESOURCES.md     ← Artifact registry and where they live
└── docs/            ← Working artifacts
```

**Convention:** All system markdown files in UPPERCASE.

---

## Task–workstream relationship

Tasks live in `TICK.md` at the project root. Workstreams live in `workstreams/`. They connect through tags:

- Each task in TICK.md is tagged with its workstream name (e.g., `tags: [feature-x]`)
- A workstream can have **1 or N tasks** — some workstreams are a single task, others have many
- `tick list --tag feature-x` shows all tasks for that workstream
- `tick status` shows all tasks across the project

**STATUS.md is workstream-level health** — aggregated progress, direction, blockers. It does not track individual task status. tick.md owns task status.

**TICK.md is the task-level source of truth** — status, priority, assignment, claim/release, history. It does not describe the workstream's purpose or context. intern-os workstream files own that.

> tick.md is the default task management layer. Other systems (Notion, Linear, Trello, etc.) can be used instead — see the task management section in SETUP.md.

**On artifacts:** there is no single repository. `docs/` inside each workstream is one of N possible repositories (Notion, Google Drive, S3, R2, etc.). `RESOURCES.md` is the index that tracks all resources and where they live.

---

## Write protocol

**Who writes what:**

| Actor | Writes when... | Files |
|-------|----------------|-------|
| **Agent** | At the end of a working session in the thread | STATUS.md, MEMORY.md, DECISIONS.md |
| **Human** | Strategic decision, change of direction, or new information | Any file |
| **Both** | Creating a new workstream | BRIEF.md, STAKEHOLDERS.md, RESOURCES.md |

**Golden rule:** If the agent cannot answer "where does this workstream stand?" by reading STATUS.md, the file is outdated.

**Workstream file size constraints:**

These limits apply to files inside `projects/[project]/workstreams/[name]/` — the intern-os workstream files. They do NOT apply to the agent framework's own memory or configuration files.

| Workstream file | Read rule | Size target |
|-----------------|-----------|-------------|
| BRIEF.md | Read in full | No limit (typically 1-3 KB) |
| STATUS.md | Read in full | ≤10 lines — phase, next, owner, blockers, updated |
| MEMORY.md | **Last 80 lines only** | Keep under 80 lines total — curated summary, not a log |
| DECISIONS.md | Read in full | Append-only log, grows slowly |
| STAKEHOLDERS.md | Read in full | Rarely changes |
| RESOURCES.md | Read in full | Append-only index |

**Workstream MEMORY.md hygiene:** When a workstream's MEMORY.md exceeds 80 lines, the agent must consolidate it — promote key insights to the top, archive or remove stale entries. Detailed session logs belong in the workstream's `docs/` directory, not MEMORY.md. This prevents unbounded context growth that degrades agent startup time on platforms with response timeouts.

**Platform timeout protocol:** On platforms with short response timeouts (Discord ~2min, Slack ACK ~3s), the agent must emit a brief acknowledgment before loading context files. File reads must never block the first response token.

**Task claiming:** Before starting work on a task, the agent claims it in tick.md:

```bash
tick claim TASK-001 @agent-name
```

After completing a task:

```bash
tick done TASK-001 @agent-name
```

See TICK-INTEGRATION.md for the full coordination protocol.

**Checkpoints (v1 carry-forward):** The human explicitly requests "save state" and the agent updates STATUS.md + MEMORY.md. No context reset required.

---

## Lifecycle

### Project lifecycle

A project is **discovered** when a team member triggers:

> Discover project: [name]

The agent:
1. Creates `projects/[name]/PROJECT.md` using the project template
2. Creates `projects/[name]/AGENTS.md` using the project agents template
3. Runs `tick init` inside the project directory
4. Registers the agent: `tick agent register @agent-name`
5. Opens a communication thread for the project
6. Asks the discovery questions (owner, objective, success criteria, archive condition)

A project is **archived** when all its workstreams are archived and the archive condition in PROJECT.md is met. The directory moves to `projects/archived/`.

### Workstream lifecycle

A workstream **is born** when:
1. A project exists (or is created)
2. A task is added to TICK.md: `tick add "Task name" --tag workstream-name`
3. A communication thread is opened (Discord forum post or Slack thread)
4. The workstream directory is created in `projects/[project]/workstreams/` with the 6 files

**No task, no thread. No thread, no directory.**

A workstream **dies** when:
1. All tasks for the workstream are marked done in TICK.md
2. STATUS.md is updated with final state and learnings
3. The communication thread is archived
4. The directory is moved from `workstreams/` to `workstreams/archived/`

**Possible states:**

| State | Directory | Communication Thread | Tasks |
|-------|-----------|---------------------|-------|
| Active | `workstreams/` | Open | In progress |
| Paused | `workstreams/` | Open | Blocked |
| Archived | `workstreams/archived/` | Archived | Complete/Archived |

---

## Agent bootstrap

**Principle:** The agent loads only the workstream for the thread it is operating in — not all of them.

**Resolution mechanism:**
- Each communication thread (Discord or Slack) maps to exactly one workstream directory
- The `thread_id` field in BRIEF.md is the canonical binding
- Resolution is by exact match only — never by inference, similarity, or heuristic

**Loading order:**

1. Resolve workstream by exact `thread_id`
2. Read `projects/[project]/AGENTS.md` (project-level context, if exists)
3. Read `BRIEF.md` (workstream identity)
4. Read `STATUS.md` (current state)
5. Escalate to other files only when the task requires it

**Thread ↔ directory mapping:** The `thread_id` field in BRIEF.md uses the format `[platform]:[id]`:

```
thread_id: discord:123456789
```
```
thread_id: slack:C07ABC123/1234567890.123456
```

The agent writes this field when creating the workstream directory, using the thread ID from platform metadata. `thread_id` is mandatory in every BRIEF.md.

**Multiple harnesses:** a workstream can be worked from several agents. `thread_id` stays the primary binding, and each other harness adds a sibling field (`thread_id_claude_code`, for example). A harness that gets a new ID every session binds by exact workstream path (`projects/<project>/workstreams/<name>`) instead. Both are exact matches. Shared state reaches every harness through the project's git repo: see `adapters/generic/SETUP.md`.

**Agent instructions:** Each agent framework has its own mechanism for loading instructions. See `adapters/` for framework-specific configuration:

- **OpenClaw:** SKILL.md + AGENTS.md block → `adapters/openclaw/`
- **Hermes Agent:** Skill definition → `adapters/hermes/`
- **Claude Code:** CLAUDE.md project instructions → `adapters/claude-code/`
- **Other agents:** Manual setup → `adapters/generic/`

The instruction contract is the same regardless of framework:
1. Read `WORKSTREAMS.md` at the start of any session in a workstream thread
2. Resolve the workstream by exact `thread_id`
3. Load project-level `AGENTS.md` (if it exists)
4. Read BRIEF.md → STATUS.md before doing any work
5. Escalate to other files only when the task requires it
6. Claim the task in tick.md before starting work
7. Update STATUS.md at the end of every working session

---

## Recovery doctrine

If a session is degraded, bloated, reset, or unhealthy:
- Reconstruct from workstream files
- Do not trust transcript continuity as source of truth
- `BRIEF.md` and `STATUS.md` must be sufficient to restart the workstream safely
- If more context is needed, escalate to `MEMORY.md` and `DECISIONS.md`

---

## Isolation doctrine

By default:
- Do not read another workstream's files
- Do not search broadly across projects
- Do not infer from similar names

Cross-workstream synthesis must be explicit and requested by the human.

---

## Code repository doctrine

For code repos under `code/<repo>/`:
- **Integration branches:** `main` is production. When the project has a staging environment, `staging` is the integration branch: work merges into `staging`, is verified there, then `staging` merges into `main`. No other long-lived branches (no per-scope or per-wave integration branches).
- **Work branches** start from the integration branch and carry a conventional prefix matching the commit type: `feat/<kebab-name>` for features, `fix/` for bug fixes, `chore/`, `docs/`, `refactor/`, `test/`, `perf/` otherwise. Never `ticket/*`, personal names, or bare names.
- Nobody commits directly to `main` or `staging`; merges into them are `--no-ff` from a work branch.
- `intern-os/scripts/worktree.sh create` refuses a branch without one of these prefixes. Agents creating branches by hand (`git switch -c`, `git worktree add -b`) follow the same rule.

---

## Communication platforms

Workstreams use communication threads as the collaboration surface. The framework supports multiple platforms — see COMMUNICATION.md for the full specification.

**Summary:**

| Platform | Container | Workstream surface | Thread ID format |
|----------|-----------|-------------------|------------------|
| Discord | Forum (`[area]-workstreams`) | Forum post (thread) | `discord:[thread_id]` |
| Slack | Channel (`[area]-workstreams`) | Thread in channel | `slack:[channel_id]/[thread_ts]` |

**Naming convention:** `[area]-workstreams` — applies to both Discord forums and Slack channels. Examples: `ceo-workstreams`, `tech-workstreams`, `ops-workstreams`.

**Persistent context mechanism:** The thread starter message (Discord forum post or Slack thread root) is the most reliable context anchor. It survives context compaction and tells the agent which workstream it's operating in. Keep it updated.

---

## tick.md integration

tick.md is the default task management layer. TICK.md lives at the project root and contains all tasks for that project. See TICK-INTEGRATION.md for the full specification.

**Quick reference:**

| Action | Command |
|--------|---------|
| Initialize project | `tick init` |
| Register agent | `tick agent register @agent-name` |
| Add task | `tick add "Task name" --tag workstream-name --priority high` |
| Claim task | `tick claim TASK-001 @agent-name` |
| Complete task | `tick done TASK-001 @agent-name` |
| View project status | `tick status` |
| List workstream tasks | `tick list --tag workstream-name` |

---

## How to create a new project

Use the discovery command:

> Discover project: [name]

Or manually:

1. Create the project directory: `mkdir -p projects/[project-name]`
2. Copy the PROJECT.md template: `cp [skill-path]/assets/templates/project/PROJECT.md projects/[project-name]/`
3. Copy the AGENTS.md template: `cp [skill-path]/assets/templates/project/AGENTS.md projects/[project-name]/`
4. Initialize tick.md: `cd projects/[project-name] && tick init`
5. Register the agent: `tick agent register @agent-name`
6. Fill in PROJECT.md with owner, objective, scope, and archive condition
7. Fill in AGENTS.md with project-level context (optional — can be populated incrementally)
8. The project is ready for workstreams

## How to create a new workstream

1. Add a task in tick.md: `tick add "Description" --tag workstream-name`
2. Open a communication thread (Discord forum post or Slack thread) in the `[area]-workstreams` channel
3. Create the workstream directory with the 6 files:
   ```bash
   WS=workstream-name
   PROJECT=project-name
   cp -r assets/templates/workstream/ projects/$PROJECT/workstreams/$WS/
   mkdir -p projects/$PROJECT/workstreams/$WS/docs
   ```
4. Fill BRIEF.md with workstream identity:
   - `thread_id` (mandatory)
   - `project` and `workstream` names
   - Objective, problem, scope, success criteria, appetite
5. Link the communication thread and task in RESOURCES.md

---

## Workspace data model

The internOS workspace contains two kinds of data: **framework files** (replaceable, shipped with the skill) and **user data** (irreplaceable, created by humans and agents during operation).

### Framework files (owned by internOS)

| File | Location | Description |
|------|----------|-------------|
| `WORKSTREAMS.md` | Workspace root | Agent runtime guide — copied from `assets/WORKSTREAMS.md` during install. Replaced on upgrade. |

These files can be safely deleted and recreated from the intern-os repository at any time.

### User data (owned by you)

| File/Directory | Location | Description |
|----------------|----------|-------------|
| `projects/` | Workspace root | All project directories |
| `PROJECT.md` | `projects/[name]/` | Project identity — purpose, scope, direction |
| `AGENTS.md` | `projects/[name]/` | Project-level agent context |
| `TICK.md` + `.tick/` | `projects/[name]/` | Task history, assignments, agent registrations |
| `workstreams/` | `projects/[name]/workstreams/` | All workstream directories |
| Workstream files | `workstreams/[name]/` | BRIEF.md, STATUS.md, MEMORY.md, DECISIONS.md, STAKEHOLDERS.md, RESOURCES.md, docs/ |

**This data is irreplaceable.** It contains your project context, accumulated decisions, task history, and workstream memory. It is NOT stored in the intern-os repository or skill — it lives only in your workspace.

### What survives an uninstall

| Action | Survives? |
|--------|-----------|
| Remove the intern-os skill | Yes — all project data stays |
| Remove WORKSTREAMS.md | Yes — recreate from skill on reinstall |
| Remove `projects/` | **No** — all project data is lost permanently |

### Backup

To back up all intern-os user data:

```bash
tar -czf internos-backup-$(date +%Y%m%d).tar.gz -C [workspace] projects/
```

To restore:

```bash
tar -xzf internos-backup-YYYYMMDD.tar.gz -C [workspace]
```

---

## Uninstalling internOS

Uninstalling removes the framework instructions from your agent but **preserves all project data** by default.

### Step 1: Remove the skill

See your adapter's SETUP.md for the specific uninstall command:

| Framework | Command |
|-----------|---------|
| Hermes Agent | `hermes skills uninstall intern-os` or `rm -rf ~/.hermes/skills/intern-os/` |
| OpenClaw | `openclaw skills uninstall intern-os` + remove internOS block from AGENTS.md |
| Claude Code | Remove the internOS section from CLAUDE.md |
| Other | Remove the internOS instructions from your agent's system prompt |

### Step 2: Remove the runtime guide

```bash
rm [workspace]/WORKSTREAMS.md
```

### Step 3: Restart the agent (if needed)

Most agents read skills from disk per session — no restart needed. Only restart if your agent framework caches skills in memory or you configured intern-os as a preloaded skill.

### Step 4: (Optional) Remove project data

Only do this if you want to permanently delete all project data:

```bash
rm -rf [workspace]/projects/
```

> **Warning:** This deletes all project directories, workstream files, task history, and accumulated context. This cannot be undone. Back up first if unsure.

### After uninstall

- The agent will no longer follow internOS protocols (workstream loading, STATUS.md updates, task claiming)
- Existing communication threads (Slack, Discord) remain but lose their workstream context
- tick.md task files remain readable with `tick status` / `tick list` even without internOS

---

## What this framework is not

- Does not replace tick.md or any task management system — it complements them
- Is not a ticketing or sprint system
- Does not require infrastructure beyond a filesystem and Git

---

## Project shapes: thread-native vs. shared-thread inbox

internOS supports two project shapes for the relationship between `thread_id` and workstream:

### Thread-native projects (default)

For Discord, Slack, and any platform with native thread/forum semantics, the rule is **one workstream per thread**. Each workstream's `BRIEF.md` declares a unique `thread_id`, and the resolution layer is one-to-one. This is the default and applies to every project unless explicitly opted out.

### Shared-thread inbox projects (opt-in, v0.4.0+)

Some platforms — Telegram, WhatsApp, Signal, iMessage, SMS, LINE — do not have native threads. One DM or chat *is* the collaboration surface. On those, multiple workstreams within the same inbox project legitimately share a `thread_id`.

To opt a project in, set two fields in `PROJECT.md`:

```md
shared_thread_ids: true
shared_thread_platforms: telegram, whatsapp, signal, imessage, sms, line
```

When opted in, the rules become:

- Duplicate `thread_id` values inside the same project are permitted **only** for platforms in `shared_thread_platforms`
- The exact `thread_id` resolves to the inbox **project** (the container), not directly to one workstream
- The active workstream within the inbox project is determined by TICK.md state plus explicit human intent (e.g. "let's resume the workspace-cleanup workstream")
- Duplicate `thread_id` values **across different projects** are still flagged as warnings, even if both projects opt in
- Thread-native platforms (`discord`, `slack`) are **hardcoded as never-suppressed**. Listing `discord` or `slack` in `shared_thread_platforms` has no effect — duplicates on those platforms always warn, regardless of opt-in
- Values are normalized before comparison: `shared_thread_ids` accepts `true`/`TRUE`/`"true"` (case-insensitive, optional quotes, trailing `#` comment stripped); `shared_thread_platforms` is lowercased and all whitespace stripped (so `Telegram, WhatsApp` matches `telegram` and `whatsapp` thread_ids)

### Example: a Telegram inbox project

```
projects/telegram-inbox-mel/
├── PROJECT.md          ← shared_thread_ids: true, shared_thread_platforms: telegram
├── TICK.md
└── workstreams/
    ├── dm-intake/
    │   └── BRIEF.md    ← thread_id: telegram:1234567890
    ├── workspace-cleanup/
    │   └── BRIEF.md    ← thread_id: telegram:1234567890  (same — allowed)
    └── tax-prep-q3/
        └── BRIEF.md    ← thread_id: telegram:1234567890  (same — allowed)
```

All three workstreams collaborate over the same Telegram DM, which is what the human experience requires.

### Validator behavior

`sync-check.sh` reads `shared_thread_ids` and `shared_thread_platforms` from each project's `PROJECT.md`. When it detects a duplicate `thread_id`:

- If the duplicate is inside the same opted-in project AND the platform is in the allowlist → emits `INFO  thread_id (...) intentionally shared inside inbox project — also used by ...`
- Otherwise → emits `WARN  thread_id (...) is duplicated — also used by ...` and counts it as an issue

This keeps Discord/Slack discipline strict while letting inbox-shaped projects work the way the platform actually behaves.

---

## Registry

`projects/REGISTRY.md` is a derived index of all non-archived workstreams. It is generated by `generate-registry.sh` and must never be hand-edited.

**Properties:**
- Derived from BRIEF.md + STATUS.md (canonical sources)
- Contains: project, workstream name, thread_id, phase, owner, health, filesystem path
- Regenerated on demand — not auto-updated
- Lives in `projects/` (not workspace root) to avoid auto-loading on every agent message

**When to consult the registry:**
- Cross-workstream operational overview
- Rollout validation
- Identifying unbound or incomplete workstreams
- Answering "what is active right now?"

**When NOT to consult the registry:**
- Resolving a single workstream by thread_id (use BRIEF.md directly)
- Normal workstream operation (isolation doctrine still applies)

See ROLLOUT.md for the full rollout protocol.

---

## What is validated by tooling vs. what is doctrine

internOS distinguishes between rules that are **validated by shipped tooling** and rules that are **doctrine for agents to follow**. Both matter, but they have different enforcement mechanisms.

### Validated by `sync-check.sh`

These are checked by the workspace health script and will produce warnings:

| Check | Severity |
|-------|----------|
| `PROJECT.md` exists per project | WARN |
| `TICK.md` exists per project | WARN |
| All 6 workstream files present | WARN |
| `thread_id` exists in BRIEF.md | WARN |
| `thread_id` format is valid (`platform:id`) | WARN |
| Slack `thread_id` includes channel + thread_ts | WARN |
| No duplicate `thread_id` across workstreams (suppressed for shared-thread inbox projects within their allowed platforms) | WARN |
| Workstream has a matching task tag in TICK.md | WARN |
| `STATUS.md` size within target (≤10 content lines) | WARN |
| `MEMORY.md` size within limit (≤80 lines) | WARN |

These are reported as informational (INFO), not failures:

| Check | Severity |
|-------|----------|
| `AGENTS.md` exists per project | INFO |
| BRIEF.md has `project`, `workstream`, `owner`, `created` fields | INFO |
| `MEMORY.md` approaching limit (>50 lines) | INFO |

### Validated by `generate-registry.sh`

| Output | Description |
|--------|-------------|
| `projects/REGISTRY.md` | Derived workstream registry with thread bindings and health status (all non-archived), plus a per-project worktree count |

### Managed by `worktree.sh`

| Output / action | Description |
|--------|-------------|
| `code/.worktrees/<name>/` | Git worktrees for parallel/agent code work — one linked worktree of a code repo per thread/lane. Created, listed, and pruned by the helper. |
| `code/WORKTREES.md` | Derived per-project worktree ledger (repo, branch, state, declaring workstream). See `docs/specs/git-tracking.md`. |

Prune is conservative: it never removes a worktree with a dirty tree or unpushed commits.

### Validated by `checkpoint-reminder.sh`

| Check | Severity |
|-------|----------|
| `STATUS.md` modified within threshold (default 3 days) | STALE |

### Validated by `tick.md`

| Check | Mechanism |
|-------|-----------|
| Task claim/release coordination | tick.md data model — `claimed_by` field |
| Agent registration | tick.md agent registry |
| Task state transitions | tick.md workflow rules |

### Doctrine (agent behavioral expectations)

These rules are documented for agents to follow but are **not mechanically enforced** by tooling. They depend on agents reading and respecting the framework instructions:

- **Exact `thread_id` resolution** — agents must resolve by exact match, never by fuzzy matching or inference
- **Tiered loading** — agents should load BRIEF.md + STATUS.md by default and escalate on demand
- **Platform ACK-first** — agents must emit acknowledgment before file reads on Discord/Slack
- **MEMORY.md curation** — agents must consolidate when over threshold, keeping it as summary not log
- **STATUS.md update at session end** — agents must update STATUS.md after every working session
- **Recovery from files** — agents must reconstruct from workstream files when sessions degrade
- **Workstream isolation** — agents must not read other workstreams' files unless explicitly requested
- **AGENTS.md loading** — agents should load project-level AGENTS.md before workstream files

These behavioral expectations are the right approach for v0.3.0. Future versions may add hooks, MCP tools, or runtime wrappers to enforce some of these programmatically — see Roadmap.

---

## Roadmap

> v0.3.0 ships the simplified Project + Workstream model with three-layer architecture. Future work focuses on runtime enforcement.

### v0.3.x — Runtime enforcement

**Derived workstream registry** — `projects/REGISTRY.md` generated by `generate-registry.sh`. Shipped in v0.3.1.

**Rollout protocol** — formal migration process documented in ROLLOUT.md. Shipped in v0.3.1.

**Bootstrap mutation hooks** — OpenClaw-compatible hooks for automatic workstream loading on thread entry.

### v0.4.0 — Automations

**Auto-scaffold on thread creation**
Platform webhook detects a new thread in a `-workstreams` channel/forum → automatically creates the directory + 6 files and adds the tick.md task.

**Archive workflow**
Detects all tasks for a workstream marked done in tick.md → moves the directory to `workstreams/archived/` → archives the communication thread.

**Cross-project dashboard**
Aggregator that reads all `projects/*/TICK.md` files and produces a unified view across projects.

---

*Iterated from learnings of each workstream.*

---

## References

- Agent runtime guide: `WORKSTREAMS.md` (copied to workspace root)
- Workstream templates: `assets/templates/workstream/`
- Project templates: `assets/templates/project/` (includes PROJECT.md and AGENTS.md)
- Agent adapters: `adapters/`
- Communication spec: `references/en/COMMUNICATION.md`
- tick.md integration: `references/en/TICK-INTEGRATION.md`
- New instance setup: `references/en/SETUP.md`
- Rollout protocol: `references/en/ROLLOUT.md`
- Operational playbook: `references/en/PLAYBOOK.md`
