# intern-os

internOS Workstreams framework — coordinate work across projects, tasks, communication threads, and filesystem workstreams for any AI agent framework.

## What it does

Installs the **internOS Workstreams** framework — a coordination system built on three explicit layers:

| Layer | What it does |
|-------|-------------|
| **Storage** | Workstream files are the authoritative state (`projects/[name]/workstreams/`) |
| **Resolution** | `thread_id` in BRIEF.md is the exact binding between thread and workstream |
| **Runtime** | Load only what is needed — BRIEF.md + STATUS.md by default, escalate on demand |

Agents loaded with this framework know how to:
- Create and manage projects with tick.md task tracking
- Activate workstreams from any communication thread
- Resolve the right workstream by exact `thread_id` match
- Load project-level context from `AGENTS.md`
- Claim tasks before working and release them when done
- Keep STATUS.md updated across sessions so context never gets lost
- Reconstruct from files when sessions degrade

## Install

| Framework | Command |
|-----------|---------|
| **Hermes Agent** | `hermes skills install poktalabs/intern-os/intern-os` |
| **OpenClaw** | `openclaw skills install https://github.com/poktalabs/intern-os` |
| **Claude Code** | Copy `adapters/claude-code/CLAUDE.md` to your project root |
| **Other** | See `adapters/generic/SETUP.md` |

After installing, follow your framework's setup guide in `adapters/[framework]/SETUP.md`.

## Scripts

| Script | What it does |
|--------|-------------|
| `intern-os/scripts/sync-check.sh` | Workspace health check — reports missing thread_ids, incomplete Slack IDs, missing files, orphan directories. Usage: `bash sync-check.sh <workspace-path>` |
| `intern-os/scripts/checkpoint-reminder.sh` | Stale STATUS.md detector — flags active workstreams not updated within threshold. Usage: `bash checkpoint-reminder.sh <workspace-path> [days]` |

## Documentation

| Document | What it covers |
|----------|---------------|
| `intern-os/references/en/FRAMEWORK.md` | Architecture — three layers, lifecycle, agent bootstrap |
| `intern-os/references/en/SETUP.md` | First-time setup guide |
| `intern-os/references/en/PLAYBOOK.md` | Day-to-day operations |
| `intern-os/references/en/TICK-INTEGRATION.md` | tick.md integration spec |
| `intern-os/references/en/COMMUNICATION.md` | Discord + Slack communication spec |

Spanish versions available in `intern-os/references/es/`.

## Versioning

internOS is stable on the `1.x` line. The latest release is published at [GitHub Releases](https://github.com/poktalabs/intern-os/releases) and `gh api /repos/poktalabs/intern-os/releases/latest` returns the correct version (currently `v1.1.1`).

The release line is `v1.0.0` (2026-07-24) → `v1.1.0` (2026-08-16) → `v1.1.1` (2026-10-15), each with a corresponding GitHub Release. Earlier `v1.0.0`/`v1.0.1`/`v1.1.0` tags from a premature pre-`0.x`-reset versioning attempt have been superseded: `v1.0.0` and `v1.1.0` were re-pointed at the real released commits, and the stray `v1.0.1` was removed (the line has no `v1.0.1`). If anything pinned to the old pre-reset tags, re-fetch.

## License

[AGPL v3](LICENSE) for open source use. Commercial license required for B2B products and SaaS — contact [hola@frutero.club](mailto:hola@frutero.club).

## Built by

[Frutero](https://frutero.club) — Impact Technology for Latin America
