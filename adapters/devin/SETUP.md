# SETUP — Devin Adapter

*internOS v1.1.2 | 2026-11-04*

This adapter lets [Devin](https://devin.ai) (cloud sessions) work internOS workstreams next to other harnesses such as Claude Code or Hermes. It covers the six points in [Writing an adapter](../generic/SETUP.md#writing-an-adapter).

---

## How it works

A Devin session runs on a fresh VM restored from a **snapshot**. A **blueprint** (YAML, configured in Devin's settings) defines that snapshot: which repos are cloned to `~/repos/<repo>`, which tools are installed, and which environment variables exist. Nothing survives from one session to the next except what is in the snapshot or in git.

Three consequences shape the adapter:

- **Instructions** come from the project repo. Devin reads every `AGENTS.md` in a cloned repo at session start (up to 16 KiB each), so the internOS block goes into the project repo's `AGENTS.md`.
- **Binding** cannot use the session ID, because every session gets a new one. The human names the workstream by exact path, and `BRIEF.md` carries that path as the Devin binding.
- **Shared state** lives in the project repo on GitHub. A session pulls it at start and pushes workstream changes at close. Other harnesses see them on their next pull.

| File | Role |
|------|------|
| `adapters/devin/AGENTS.md` | Instruction block for the project repo's `AGENTS.md` |
| `adapters/devin/scripts/resolve-workstream.sh` | Exact-path resolver. With `--load` it prints the Tier 1 bundle. |
| `intern-os/scripts/sync-check.sh` | Health check at session close (shared with the other adapters) |

---

## Prerequisites

- A Devin organization with the GitHub integration granted access to the **project repo** (`<org>/<project>`, the repo that holds `PROJECT.md`, `TICK.md` and `workstreams/`) and to the code repos the workstreams touch.
- Permission to edit that project repo's blueprint (Settings → Environment → Blueprints).

---

## 1. Instructions

Append [`AGENTS.md`](AGENTS.md) from this directory to the project repo's root `AGENTS.md` and commit it. If the repo has no `AGENTS.md`, copy the file as is.

```bash
cat [intern-os-repo]/adapters/devin/AGENTS.md >> [project-repo]/AGENTS.md
```

Devin picks the file up whenever the project repo is cloned in a session. It reads the first 16 KiB of each `AGENTS.md`, so keep the internOS block near the top if the file is long.

The project-level `AGENTS.md` doubles as the framework's project context file. That is the file the loading order reads first, so a single file serves both purposes.

Devin Knowledge notes and org-level skills are not needed. Keeping the instructions in the repo versions them next to the workstream files.

---

## 2. Resolution

Devin session IDs are session-scoped, so the binding is the exact workspace-relative path (see FRAMEWORK.md, "Multiple harnesses").

**Binding in `BRIEF.md`.** Pick the field based on who owns the workstream:

```
# Devin is the only harness on this workstream
thread_id: devin:projects/<project>/workstreams/<name>

# Another harness owns thread_id (Slack, Discord, Claude Code, ...): add a sibling
thread_id: slack:C07ABC123/1234567890.123456
thread_id_devin: devin:projects/<project>/workstreams/<name>
```

Never remove another harness's ID to add Devin's. Older Devin bindings of the form `thread_id: devin:<session-id>` resolve nothing, because that session will never exist again. Replace them with the path form; the resolver flags them.

**Naming the workstream.** The human names the path in the session prompt, for example:

> Work on `projects/acme/workstreams/launch-v2`: ship the v1.1 changelog.

**Resolving.** The session runs:

```bash
resolve-workstream.sh --load projects/<project>/workstreams/<name>
```

| Exit | Meaning | Agent does |
|------|---------|------------|
| 0 | Path exists in exactly one workspace and `BRIEF.md` binds `devin:<path>` | Works from the printed bundle |
| 1 | No workstream at that path | Stops and asks |
| 2 | `BRIEF.md` missing, binding mismatch, or the path exists in more than one workspace | Stops and asks. Does not edit `BRIEF.md`. |
| 3 | Bad path shape or `INTERNOS_WORKSPACE` unset | Fixes the call or the environment (step 5) |

If the prompt names no workstream, the session does not look for one. A Slack- or Linear-triggered session still binds by path: the triggering thread ID is not stable across the sessions that thread spawns, so it is not used as a binding.

---

## 3. Loading order

`resolve-workstream.sh --load` prints, in order:

1. `projects/<project>/AGENTS.md`, if present
2. `BRIEF.md`, in full
3. `STATUS.md`, in full when ≤40 lines. Longer files are cut to 40 lines with a flag telling the agent to trim them, matching the cap in the Claude Code adapter's `session-start.sh`.

Everything else is Tier 2 or 3, read on demand: `DECISIONS.md` and `STAKEHOLDERS.md`, then `MEMORY.md` (last 80 lines), `RESOURCES.md` and `docs/`. No other workstream is read.

**Startup mode.** Devin replies through its chat (web app, Slack, Teams), so it follows LIGHT mode: the first action is an acknowledgment to the human, then the resolver. The Tier 1 bundle is one command, so loading it costs one tool call.

---

## 4. Session close

Devin has no session-end hook, and a session can sleep instead of ending. Session close is therefore doctrine that the `AGENTS.md` block spells out. It runs before the session's final report to the human:

1. If a task was claimed: `tick done TASK-X @devin` or `tick release TASK-X @devin`.
2. Replace `STATUS.md` current-state fields in place (≤10 lines, no dated sections).
3. Append to `DECISIONS.md`. Consolidate `MEMORY.md` if it is over 80 lines.
4. Append to `SESSIONS.md`: `<YYYY-MM-DD HH:MM> · devin:<session-id> · <summary>`. The session ID goes in the log only, not in the binding.
5. `bash "$INTERNOS_HOME/intern-os/scripts/sync-check.sh" --workstream <dir>` and fix what it reports.
6. Commit the workstream files and push them.

**Commit identity.** Devin commits as its own GitHub identity and does not override `user.name`/`user.email`. If a project requires one specific author on every commit, a human commits Devin's workstream changes instead, or the project relaxes that rule for workstream files.

**Getting it to the shared repo.** By default Devin pushes `chore/<workstream>-status` and opens a PR on the project repo, and the human merges it. That PR is the hand-off: the next agent, on any harness, sees the update after the merge and a `git pull`. A project that wants status to land without review can say so in its `AGENTS.md` (for example "workstream files may be pushed straight to `main`").

**Task claims.** `tick claim` edits `TICK.md` on the VM only. If another harness might pick up the same task in parallel, commit and push the claim first, the same way as the session close, before starting the work.

**Code work.** Each Devin session has its own VM, so the session's clone of the code repo (`~/repos/<repo>`) is already an isolated checkout. `code/.worktrees/` is not needed on Devin. Branch names follow FRAMEWORK.md's code repository doctrine (`feat/`, `fix/`, ...). Record the branch in the BRIEF `worktrees:` block only when another harness will continue it in a worktree.

---

## 5. Environment

Every session starts from the snapshot, so the setup goes into the project repo's **repository blueprint**. Builds run that blueprint inside `~/repos/<project-repo>`.

```yaml
initialize:
  - name: Node.js for tick-md
    uses: github.com/actions/setup-node@v4
    with:
      node-version: "22"

  - name: tick-md
    run: npm install -g tick-md@1

  - name: internOS framework
    run: |
      INTERNOS_HOME="$HOME/.internos"
      git clone --depth 1 https://github.com/poktalabs/intern-os "$INTERNOS_HOME"
      mkdir -p "$HOME/.local/bin"
      ln -sf "$INTERNOS_HOME/adapters/devin/scripts/resolve-workstream.sh" "$HOME/.local/bin/resolve-workstream.sh"
      echo "INTERNOS_HOME=$INTERNOS_HOME" >> $ENVRC
      echo 'export PATH="$HOME/.local/bin:$PATH"' >> $ENVRC

  - name: internOS workspace
    run: |
      # Project name as it appears in thread bindings, i.e. the directory
      # name under projects/ on the other harnesses' machines.
      PROJECT=<project>
      mkdir -p "$HOME/internos/projects"
      ln -sfn "$HOME/repos/<project-repo>" "$HOME/internos/projects/$PROJECT"
      echo "INTERNOS_WORKSPACE=$HOME/internos" >> $ENVRC

maintenance:
  - name: Refresh internOS framework
    run: git -C "$HOME/.internos" pull --ff-only

knowledge:
  - name: internos
    contents: |
      internOS project. Resolve a named workstream with
      `resolve-workstream.sh --load projects/<project>/workstreams/<name>`.
      Health check: `bash $INTERNOS_HOME/intern-os/scripts/sync-check.sh --workstream <dir>`.
```

Notes:

- **Why a symlink.** Bindings are relative to the workspace (`projects/<project>/...`). Devin clones repos into `~/repos/`, so `~/internos/projects/<project>` links to the clone, and the same path string resolves on every harness. Use the project's directory name from the other harnesses, which can differ from the repo name: a project repo `<org>/acme-project-dir` bound elsewhere as `projects/acme/...` is linked as `~/internos/projects/acme`.
- **Several projects.** Add each project repo to the environment and add one `ln -sfn` per project. A single `~/internos` workspace serves them all.
- **Code repos** (`code/<repo>/` elsewhere) are separate repos in the same environment, cloned to `~/repos/<repo>`. They need no symlink: Devin works in them directly.
- **Pinning.** For reproducible sessions, pin the framework to a release with `git clone --branch v1.1.2 ...` and drop the `maintenance` pull.
- **Rebuild** the snapshot after saving the blueprint. Sessions started earlier keep the old environment.

---

## 6. Secrets

- Store credentials as **Devin Secrets**: organization, personal, or repository-scoped (the project blueprint's **Secrets** tab). Devin injects them as environment variables or binds them to the commands that need them.
- Workstream files never hold a credential value. `RESOURCES.md` and `AGENTS.md` may say *which* secret a resource needs (by name); the value stays in Devin Secrets.
- Blueprint steps reference secrets as `$NAME`. Do not write secret values to files in `initialize`, because those files are saved into the snapshot.
- Code-repo env files (`.env.local`) are not copied between machines. Each one is rebuilt on the VM from secrets, in that code repo's blueprint.

---

## Isolated-session handoff

Devin can delegate to child sessions. A child starts on its own VM from the same snapshot, with no transcript and no binding from the parent.

- The coordinator writes the manifest to `<workstream>/handoffs/<handoff_id>.yml`, pushes it, and pastes the manifest **content** into the child's prompt, together with the verify-then-execute protocol from `references/en/ISOLATED-HANDOFF.md`.
- The child pulls the project repo and runs `bash "$INTERNOS_HOME/intern-os/scripts/verify-handoff.sh" <manifest>` as its first action.
- The child writes only within the manifest's write scope (`handoffs/<handoff_id>.md`, `handoffs/<handoff_id>/*`, bounded `MEMORY.md` appends), pushes it on its own branch, and reports `{artifact_path, status, summary}` back.
- The coordinator reconciles into `STATUS.md` / `DECISIONS.md`.

---

## Verification

Run these in a Devin session after the snapshot rebuild:

```bash
which tick resolve-workstream.sh                 # both on PATH
echo "$INTERNOS_WORKSPACE" && ls "$INTERNOS_WORKSPACE/projects"
resolve-workstream.sh --load projects/<project>/workstreams/<name>; echo "exit: $?"   # 0
resolve-workstream.sh projects/<project>/workstreams/does-not-exist; echo "exit: $?"   # 1
bash "$INTERNOS_HOME/intern-os/scripts/sync-check.sh" --workstream \
  "$(resolve-workstream.sh projects/<project>/workstreams/<name>)"
```

- [ ] The project repo's `AGENTS.md` contains the internOS block
- [ ] The workstream's `BRIEF.md` binds `devin:projects/<project>/workstreams/<name>`
- [ ] The resolver exits 0 for that path and 1 for an unknown one
- [ ] A session that ends updates `STATUS.md` and `SESSIONS.md` and opens a PR (or pushes, if the project allows it)

---

## Uninstall

1. Remove the `## internOS — Workstreams (Devin)` block from the project repo's `AGENTS.md`.
2. Remove the internOS steps from the project blueprint and rebuild the snapshot.
3. Optionally drop the `thread_id_devin` lines from BRIEF files. Workstream data stays in the project repo.
