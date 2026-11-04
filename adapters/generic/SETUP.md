# SETUP — Generic Adapter (Any Agent Framework)

*internOS v1.1.2 | 2026-11-04*

Manual setup for agent frameworks without a dedicated adapter, including cloud agents such as Codex and Cursor. Devin has its own adapter in [`adapters/devin/`](../devin/SETUP.md). To write a dedicated adapter, see [Writing an adapter](#writing-an-adapter).

---

## Prerequisites

- An AI agent framework that supports custom instructions or system prompts
- Access to the agent's workspace or working directory

---

## Setup

### 1. Install tick.md

```bash
pnpm add -g tick-md
```

### 2. Add internOS instructions to your agent

Add the following to your agent's instruction file, system prompt, or configuration:

```markdown
## internOS — Workstreams

If `WORKSTREAMS.md` exists in the workspace root, read it at the start
of any session in a communication thread that has a workstream context.

### Resolution

Resolve the workstream by exact `thread_id` in BRIEF.md. If this agent has no
stable thread (each session gets a new ID), resolve by the exact workstream
path the human named instead. If no exact match exists, stop and ask. Never guess.

### Loading order

1. Resolve workstream by exact `thread_id`
2. Read `projects/[project]/AGENTS.md` (project-level context, if exists)
3. Read `BRIEF.md` in full (workstream identity + thread_id)
4. Read `STATUS.md` in full (must be ≤10 lines by design)
5. Escalate to MEMORY.md, DECISIONS.md, STAKEHOLDERS.md, RESOURCES.md only when needed
6. MEMORY.md: read last 80 lines only — search on demand if more needed

Only load the workstream directory matching the active thread.
Do not load all workstreams — keep context clean.

Projects live in: `projects/[project-name]/`
Workstream directories live in: `projects/[project]/workstreams/[workstream-name]/`

Always emit acknowledgment BEFORE loading any context files. Never let file reads block the first response token.

Platform startup modes:
- Discord / Slack (LIGHT): ACK → BRIEF + STATUS → escalate only if needed
- Telegram / CLI (FULL): BRIEF + STATUS + MEMORY before first response

Recovery: if session is degraded, reconstruct from workstream files — not transcript.
Isolation: do not read other workstream files by default.

Before starting work on a task, claim it:
  tick claim TASK-X @agent-name

Before ending any working session:
1. Complete or release the task in tick.md
2. Update STATUS.md with:
   - What was done this session
   - Current workstream phase
   - Any blockers
3. If the workstream's MEMORY.md exceeds 80 lines (target ≤50), consolidate — summary, not log

This is required even if nothing changed. A blank STATUS.md means
the workstream is invisible to the next agent or session.
```

### 3. Copy WORKSTREAMS.md to your workspace

```bash
cp [intern-os-repo]/intern-os/assets/WORKSTREAMS.md [workspace]/WORKSTREAMS.md
```

### 4. Create the projects directory

```bash
mkdir -p [workspace]/projects/
```

### 5. Initialize your first project

```bash
PROJECT=my-project
mkdir -p [workspace]/projects/$PROJECT
cd [workspace]/projects/$PROJECT
tick init
tick agent register @agent-name --type bot --role engineer
```

### 6. Restart the agent

Apply instruction changes by restarting the agent session.

---

## Verification

- [ ] Agent instructions include the internOS block
- [ ] WORKSTREAMS.md exists in the workspace root
- [ ] `projects/` directory exists
- [ ] At least one project initialized with tick.md
- [ ] Agent registered: `cd projects/[project] && tick agent list`
- [ ] Agent restarted

---

## Working across harnesses

One workstream can be worked from several agents at once, for example a local CLI agent and a cloud agent.

- **Shared state lives in git.** Keep each project in its own repo. Pull before starting and push `STATUS.md`, `DECISIONS.md` and task changes when finishing, so the next agent sees them.
- **One ID per harness.** `thread_id` stays as the primary binding. Other harnesses add a sibling field such as `thread_id_claude_code`. Never remove one harness's ID to add another.
- **Session-scoped harnesses.** If an agent gets a new ID every session, its ID cannot bind a workstream. Bind by exact path (`projects/<project>/workstreams/<name>`) instead. This is still an exact match, not a guess.

---

## Writing an adapter

An adapter is the smallest set of files that lets a harness follow the framework. Put it in `adapters/<harness>/` with its own `SETUP.md`. It must cover:

1. **Instructions:** how the harness loads the block in step 2 at session start (instruction file, repo knowledge, system prompt).
2. **Resolution:** how the session finds its workstream, by exact `thread_id` or exact path, and stops to ask when nothing matches.
3. **Loading order:** project `AGENTS.md`, then `BRIEF.md`, then `STATUS.md`, escalating to other files only on demand.
4. **Session close:** how `STATUS.md` and tasks get updated, and how they reach the shared repo.
5. **Environment:** what must exist on the machine (git access to the project repo, `tick`, workspace path). Cloud agents usually start from a fresh machine, so the setup has to be repeatable.
6. **Secrets:** where credentials live. They never go in tracked workstream files.

Read `intern-os/SKILL.md` and `intern-os/references/en/FRAMEWORK.md` first, and use `adapters/claude-code/` or `adapters/hermes/` as worked examples.

---

## Next step

Follow **PLAYBOOK.md** to activate your first workstream.

---

## Uninstall

### 1. Remove the internOS instructions from your agent

Remove the `## internOS — Workstreams` section from your agent's instruction file or system prompt.

### 2. Remove WORKSTREAMS.md from the workspace

```bash
rm [workspace]/WORKSTREAMS.md
```

### 3. Restart the agent

Apply changes by restarting the agent session.

### 4. (Optional) Remove workspace data

The steps above remove the internOS framework but **preserve your project data** (projects, workstreams, TICK.md, task history). To remove everything:

```bash
rm -rf [workspace]/projects/
```

> **Warning:** This deletes all project directories, workstream files, task history, and accumulated context. This cannot be undone.
