# Changelog

> **Version scheme:** internOS moved to `0.x.x` versioning starting with this release to reflect alpha status. Prior releases are kept as historical record.

## v1.1.1 (2026-10-15)

Adds the **`latest`** companion skill, the read side of `checkpoint` and `session-wrap`, and releases the companion-skill work merged since v1.1.0.

### New features

- **`/latest`: load the latest status.** New `adapters/claude-code/skills/latest/` (v0.1.0). Inside a workstream it loads STATUS.md, the pick-up checkpoint (newest `~/.claude/checkpoint-log.jsonl` entry scoped to the workstream, plus the STATUS.md pointer), the last 5 sessions, recent commits and open tick tasks, then summarizes state and next step. Inside a project but outside a workstream it ranks non-archived workstreams by STATUS `updated:` date and loads the newest project checkpoint. Read-only. Unlike the global `latest-checkpoint-pointer.sh` hook, which shows the newest checkpoint across every project, `/latest` is scoped to the cwd. Resolution reuses `resolve-thread.sh`, so it also binds from a declared `code/.worktrees/<name>/`.
- **`checkpoint` companion skill (v0.1.0)**: fast progress save before `/compact` or `/clear` (merged after v1.1.0, first released here).
- **`session-wrap` 0.2.0 → 0.4.0**: Step 6 log + verify workflow, optional per-execution cost tracker (merged after v1.1.0, first released here).

### Docs

- `adapters/claude-code/SETUP.md`: section 8 installs `latest`.
- `intern-os/VERSION` 1.1.0 → 1.1.1; `intern-os/SKILL.md` `version:` 1.1.0 → 1.1.1; README release line.

## v1.1.0 — 2026-08-16

**⚠️ Supersedes an old `v1.1.0` tag.** Like the `v1.0.0` reset below, this repo carried stale pre-alpha-reset tags — `v1.0.1` (2026-03-27) and `v1.1.0` (2026-03-30) — from the abandoned pre-`0.x` lineage. Neither was ever published as a GitHub Release or battle-tested. The old `v1.1.0` tag has been deleted and re-pointed here; the stale `v1.0.1` tag has been removed entirely (no `v1.0.1` release exists — the line goes `v1.0.0` → `v1.1.0`). If you have anything referencing the old `v1.0.1` or `v1.1.0` from before 2026-08-16, re-fetch — they pointed at different, untested code.

Adds first-class **git-worktree support** for code work. internOS projects keep real code in nested, gitignored repos under `projects/<project>/code/<repo>/`; parallel and agent-driven work now has a documented, tooled, and tracked way to run in isolated checkouts. The convention (`code/.worktrees/<name>/`, one shared parking dir beside the code repos) was already running in production on pokta-care by hand — this release upstreams it as doctrine + tooling. Cross-tool compatibility (Claude Code, Hermes, OpenClaw, Codex, and the desktop ADEs) was researched before locking the layout.

### New features

- **`worktree.sh` — the worktree helper.** New `intern-os/scripts/worktree.sh` with `create` / `list` / `prune` / `ledger`. Creates `code/.worktrees/<name>/` as a linked worktree of a chosen code repo, copies gitignored files listed in the code repo's optional `.worktreeinclude`, and writes the derived per-project ledger `code/WORKTREES.md`. Prune is conservative — it never removes a worktree with a dirty tree or unpushed commits. bash 3.2-compatible.
- **BRIEF.md `worktrees:` binding.** The workstream template gains an optional `worktrees:` block (repo, dir, branch) — the authoritative link from a workstream to the worktree(s) it drives. The derived ledger and registry count reconcile against live `git worktree list`.
- **Registry worktree awareness.** `generate-registry.sh` now emits a per-project worktree count in the Summary and a **Worktrees** section pointing at each `code/WORKTREES.md`. Defensive — no `code/` container means no change.
- **Worktree-cwd resolution (Claude Code).** `resolve-thread.sh` now binds from inside a code worktree (`projects/<project>/code/.worktrees/<name>/`) to the workstream whose BRIEF.md declares it — exact match, deterministic; ambiguous declarations exit 2.
- **`WorktreeCreate` hook (Claude Code, optional).** New `worktree-create.sh` + a `WorktreeCreate` block in the adapter `settings.json` redirect Claude Code's native worktree creation (which would fork the *project* repo, where `code/*` is gitignored) into `code/.worktrees/` of the intended code repo. Repo chosen via `INTERNOS_WORKTREE_REPO` or the sole code repo.

### Spec & doctrine

- **`docs/specs/git-tracking.md`** — new "Git worktrees" section (layout, naming, harness/IDE compatibility table, `.worktreeinclude` bootstrap, Turbo-cache caveat, cleanup doctrine); the prior worktree open question is resolved; the "Multiple `.git` directories" tradeoff now covers the worktree gitlink files.
- **`intern-os/SKILL.md`** and **`references/{en,es}/FRAMEWORK.md`** — storage-layer trees and project structure now show `code/`, `code/.worktrees/`, and `code/WORKTREES.md`; a "Worktrees (code work)" doctrine subsection; `worktree.sh` added to the tooling breakdown.
- **`templates/git/project.gitignore`** — documents that `code/.worktrees/` stays ignored by the existing `code/*` rule and re-includes the derived `code/WORKTREES.md`.
- **Adapter docs** (`adapters/claude-code/SKILL.md`, `CLAUDE.md`) — worktree operating protocol, the helper-over-native-flag rule, and the new resolution behavior.

### Updated files

- `intern-os/scripts/worktree.sh` (new), `adapters/claude-code/scripts/worktree-create.sh` (new)
- `adapters/claude-code/hooks/settings.json` — `WorktreeCreate` hook block
- `adapters/claude-code/scripts/resolve-thread.sh` — worktree-cwd resolution
- `intern-os/scripts/generate-registry.sh` — per-project worktree count + Worktrees section
- `intern-os/assets/templates/workstream/BRIEF.md` — `worktrees:` block
- `templates/git/project.gitignore` — worktree docs + `code/WORKTREES.md` re-include
- `docs/specs/git-tracking.md`, `intern-os/SKILL.md`, `intern-os/references/{en,es}/FRAMEWORK.md`
- `adapters/claude-code/SKILL.md`, `adapters/claude-code/CLAUDE.md`
- `intern-os/VERSION` 1.0.0 → 1.1.0; `intern-os/SKILL.md` `version:` 1.0.0 → 1.1.0

## v1.0.0 — 2026-07-24

**⚠️ Supersedes an old `v1.0.0` tag.** This repo has a `v1.0.0` tag from 2026-03-27 (predating the `0.x` alpha-status reset above) that was never published as a GitHub Release and was never battle-tested — it was rushed. That old tag has been replaced; `v1.0.0` now points here. If you have anything (a clone, a cached tag SHA, a pinned dependency) referencing the old `v1.0.0` from before 2026-07-24, re-fetch — it pointed at different, untested code.

First stable release, and the real one. Formalizes the **nested child project** pattern that has been running in production for ~2 months (e.g. `projects/club/club-app/workstreams/...`, `projects/devrel/nebius/workstreams/...`, `projects/godinez-ai/zeta-godin/workstreams/...`) but was never upstreamed — the Claude Code adapter only supported single-segment project names (`projects/<project>/workstreams/<name>`) until now. Also fixes two latent bugs in `generate-registry.sh` found while porting this support.

### New features

- **Nested child projects — Claude Code adapter.** `resolve-thread.sh` now matches `projects/<path-to-project>/workstreams/<name>` where `<path-to-project>` may be a single top-level project (`foo`) or a nested child project under a container (`club/club-app`, `devrel/nebius`). Previously only single-segment project names resolved; nested projects — already in real use — would fail resolution entirely under the shipped script.
- **`generate-registry.sh` scans nested projects.** The main scan previously assumed every project was exactly one path segment below `projects/` and silently skipped any project nested deeper (a container directory like `club/` has no `workstreams/` of its own, so its child projects were never reached). It now locates project directories by walking to wherever a `workstreams/` directory actually is, at any depth.

### Bug fixes

- **`generate-registry.sh` thread_id validation rejected valid IDs.** The health-check regex (`^[a-z]+:.+`) didn't allow hyphens, so every `claude-code:`-prefixed thread_id (and any other hyphenated platform prefix) was flagged `invalid thread_id format` and the workstream marked `unbound` even when correctly bound. Fixed to `^[a-z-]+:.+`, matching the already-correct regex in `sync-check.sh`.
- **`generate-registry.sh` container mode workstream count** used a fixed `-mindepth 3 -maxdepth 3` `find`, undercounting workspaces containing nested projects. Now walks to each `workstreams/` directory directly, same fix as the main scan.

### Updated files

- `adapters/claude-code/scripts/resolve-thread.sh` — nested-project regex + doc-string updates
- `adapters/claude-code/scripts/session-start.sh` — doc-string updated to `<path-to-project>`
- `adapters/claude-code/SKILL.md` — documents the nested child-project thread_id form; resolver description updated
- `adapters/claude-code/CLAUDE.md` — same `<path-to-project>` wording fix
- `adapters/claude-code/SETUP.md` — first `INTERNOS_WORKSPACE` example changed from `$HOME/workspace` (singular, inconsistent with the canonical `~/workspaces` container convention documented two paragraphs later) to `$HOME/workspaces/my-org`
- `intern-os/scripts/generate-registry.sh` — nested-project scan + thread_id regex + container ws_count fixes
- `intern-os/SKILL.md` — `version:` 0.5.0-alpha.2 → 1.0.0

## v0.5.0-alpha.2 — 2026-06-18

Alpha point release within the `0.5.0` line. Brings the **workspaces-container** model to **both** the Hermes and Claude Code adapters, unifying their multi-workspace handling on one structural definition. Point `internos.workspace_path` (Hermes) or `INTERNOS_WORKSPACE` (Claude Code) at a top-level container (canonically `<any-path>/workspaces`) and the adapter resolves across every child workspace. Backward-compatible: a path that directly contains `projects/` is still a single workspace and behaves exactly as before.

### New features

- **Workspaces container support — framework-wide, both adapters.** `internos.workspace_path` (Hermes) / `INTERNOS_WORKSPACE` (Claude Code) may now point at a **workspaces container** — a directory whose immediate children are each workspaces (each with its own `projects/`) — in addition to a single workspace. Detection is **structural, not name-based**: `<path>/projects/` present → single workspace; absent but `<path>/*/projects/` present → container. Resolution in container mode scans `<container>/*/projects/*/workstreams/*/BRIEF.md` by exact `thread_id` (globally unique, so the match is authoritative across workspaces); the matching rule is unchanged, only the search set widens. The isolation doctrine applies across workspaces just as across projects, and new projects/workstreams are always created inside a chosen child workspace, never at the container root.

- **Unified resolver model across adapters.** The Claude Code resolver (`resolve-thread.sh`) previously only accepted single-workspace roots in its PATH-style `INTERNOS_WORKSPACE` list; it now expands any container entry into its child workspaces before ancestor-matching `$PWD`. Containers and single workspaces may be mixed in the same colon-separated list. This is the same `<any-path>/workspaces` model and the same structural detection the Hermes adapter uses — so both adapters now describe multi-workspace setups identically. The canonical `thread_id` stays relative to the matched workspace, never the container.

### Updated files

- `intern-os/SKILL.md` — `version:` 0.5.0-alpha.1 → 0.5.0-alpha.2; `metadata.hermes.config` description for `internos.workspace_path` now states it accepts a workspace **or** a container; new "Single workspace vs. workspaces container" subsection under the resolution layer; container note on the activation scaffold; tooling bullets note container-awareness
- `intern-os/scripts/sync-check.sh` — v0.5.0; accepts a container path (iterates every child workspace) and enforces `thread_id` uniqueness **across** the whole container; per-workspace headers; container-aware summary; single-workspace + `--workstream` modes unchanged
- `intern-os/scripts/generate-registry.sh` — v0.5.0; container mode generates one `projects/REGISTRY.md` per child workspace plus a container-level index at `<container>/REGISTRY.md`
- `adapters/hermes/SETUP.md` — documents the container option (with structure diagram), the `skills.config.internos.workspace_path` injection note, and a container verification step
- `adapters/claude-code/scripts/resolve-thread.sh` — expands container entries in `INTERNOS_WORKSPACE` into child workspaces before ancestor-matching `$PWD`; bash-3.2-safe empty-array guard; updated Env docs
- `adapters/claude-code/{SKILL.md, SETUP.md, CLAUDE.md}` — document the workspaces-container option alongside the existing PATH-style list
- `intern-os/references/{en,es}/FRAMEWORK.md` — resolution-layer subsection on single workspace vs. container (EN + ES parity); version header bump
- `intern-os/VERSION` — 0.5.0-alpha.1 → 0.5.0-alpha.2
- `CHANGELOG.md` — this entry

### Compatibility

- **No breaking changes.** Single-workspace installs (path with its own `projects/`) detect as before and behave identically; container behavior only activates when the path has no `projects/` of its own but its children do.
- **No Hermes-core change required.** Hermes already injects `skills.config.internos.workspace_path` verbatim into the skill payload; container support lives entirely in the framework skill, scripts, and docs.

## v0.5.0-alpha.1 — 2026-06-16

Alpha point release within the `0.5.0` line. Adds two Claude Code adapter skills — `session-wrap` and `export-sessions` — making the claude-code adapter the first internOS adapter to ship more than one skill. Both are optional installs and Claude-Code-specific (gbrain / Claude memories / gstack); no changes to the platform-neutral core and no breaking changes.

### New features

- **`session-wrap` companion skill bundled in the Claude Code adapter.** internOS now ships a second Claude Code skill alongside the core `intern-os` skill: `session-wrap`, the curated human-judgment half of session-end (the existing `SessionEnd` hook is the deterministic half). It synthesizes a session's decisions / learnings / bugs / commitments, records them to gbrain (`add_timeline_entry` / `put_page`, never a raw import), updates the active workstream's STATUS/DECISIONS/journal/TICK, saves durable Claude memories, and writes a dated cold-start pick-up checkpoint under the project's `docs/checkpoints/` before a `/clear` or compact — ending on a continue-vs-clear prompt. Lives under the **claude-code adapter** rather than the platform-neutral core because its mechanism (gbrain, Claude memories, the `~/.claude/gbrain-session-queue.jsonl` breadcrumb) is Claude-Code-specific. This makes the claude-code adapter the first internOS adapter to ship more than one skill. Optional install (adapter SETUP.md step 5); skip it if you don't use gbrain.

- **`export-sessions` skill + engine for whole-project host migration.** A third Claude Code adapter skill, `export-sessions`, with its engine scripts (`scripts/export-sessions.sh` + `import-sessions.sh`), exports an entire internOS project's tracking state — internOS repo(s) via `git bundle` (incl. unpushed commits + the gitignored `journals/`), Claude Code session transcripts + memories, gstack artifacts, and gbrain pages (markdown, re-embedded on import) — into one gpg-AES-256-encrypted bundle, then restores it on another internOS-native host. Path-derived slugs are remapped on import; code subrepos are recorded for clone-from-remote (not bundled) to keep the archive lean. Broader than a Transfer Module: it carries session history + agent memory, which TMs deliberately don't. Like `session-wrap` it ships under the **claude-code adapter** (it moves Claude Code + gbrain + gstack state). Optional install (adapter SETUP.md step 6).

### Updated files

- `adapters/claude-code/skills/session-wrap/SKILL.md` — **new**: bundled companion skill (gains a `repo:` provenance field)
- `adapters/claude-code/skills/export-sessions/SKILL.md` — **new**: whole-project host-migration skill (judgment layer over the engine scripts)
- `adapters/claude-code/scripts/export-sessions.sh`, `adapters/claude-code/scripts/import-sessions.sh` — **new**: the migration engine (bundle/encrypt + restore/decrypt, manifest-driven)
- `adapters/claude-code/SETUP.md` — **new steps 5–6**: install the `session-wrap` and `export-sessions` companion skills, plus verification lines
- `intern-os/VERSION` — 0.5.0-alpha.0 → 0.5.0-alpha.1
- `intern-os/SKILL.md` — `version:` 0.5.0-alpha.0 → 0.5.0-alpha.1
- `CHANGELOG.md` — this entry

## v0.5.0-alpha.0 — 2026-05-23

Alpha release. Bundles four contribution branches authored against `main` after v0.4.1: Claude Code multi-workspace + dual-binding adapter, three-tier git-tracking convention, Transfer Modules packaging standard (spec v1.0 + v1.1 with the `engagement-delivery` type), and a spec stub for project-level shared docs + TM export. Three of the four ship implementation; the fourth (shared-docs) is spec-only and lands as an alpha-tagged design artifact for review. Authored and validated locally before the alpha tag — see "Validation" below. No breaking changes for solo-workspace single-binding users.

### New features

- **Claude Code multi-workspace + dual-binding adapter.** `INTERNOS_WORKSPACE` now accepts a PATH-style colon-separated list of workspace roots, so one Claude Code install can resolve workstreams across `agencia/`, `poktalabs/`, `frutero/`, etc. without per-shell switching. The resolver walks each root in declaration order. Dual-binding: BRIEF.md may declare both `thread_id:` and a `thread_id_claude_code:` fallback — the resolver accepts the fallback when the primary `thread_id` belongs to another platform (e.g. an `internal:` design thread still resolves under Claude Code). Sync-check's workspace-scan thread_id regex now accepts hyphens in platform names (`claude-code` was previously flagged invalid). Touches `adapters/claude-code/{SKILL.md, scripts/resolve-thread.sh, scripts/session-start.sh}` and `intern-os/scripts/sync-check.sh`.

- **Three-tier git-tracking convention.** New spec `docs/specs/git-tracking.md` establishes the workspace-repo / project-repo / `code/` clones layering: the project repo holds state (BRIEF/STATUS/DECISIONS/TICK/workstreams) and contains a `code/` subdir whose contents are opaque to the parent. Ships `templates/git/workspace.gitignore` and `templates/git/project.gitignore` as allowlist-style ignores so nested code clones remain self-managed without leaking into the project repo's history. Lived application: internOS itself moved from `poktalabs/projects/research/intern-os/` to a first-class project `poktalabs/projects/intern-os/` under this convention (2026-05-19).

- **Transfer Modules (TM) packaging standard — spec v1.0 + v1.1.** Formalizes TMs as portable, scoped context capsules that move workstream state between agents and environments. Spec v1.0 (`docs/specs/transfer-modules.md`) defines the base structure: `SKILL.md`, `references/{TM.yml, IMPORT.md, REDACTION_REPORT.md}`, `scripts/verify_tm.sh`, and a typed `payload/`. Spec v1.1 adds the `internOS.engagement-delivery` TM type — for delivering a frozen engagement context to a receiving team — with `payload/{source-snapshot, runtime, updates}`, an `apply_to_target.sh` script (one-field-per-line parser, rewritten for robustness), and `references/{APPLY.md, EXPORT_MANIFEST.md, RETURN.md}`. Ships `templates/tm/` and `templates/tm/engagement-delivery/` as starting structures. Portable verifier (`templates/tm/scripts/verify_tm.sh`) is POSIX + sha256 only, zero runtime deps. Verified end-to-end against the live `method-lab-engine-delivery` TM.

- **Shared docs + TM export contract — spec only.** `docs/specs/shared-docs-and-tm-export.md` introduces project-level `docs/` as the home for shared documents and external-system artifact snapshots that drive project state (e.g. `/office-hours` design docs), plus a TM-export contract extension that resolves workstream `RESOURCES.md` references into `<workstream>/docs/` at export time. Motivated by scaffolding the Nubia project, which surfaced the gap (no home for cross-workstream docs, no portability contract for external-artifact snapshots, no LLM-Wiki indexability guarantees). **No implementation in this alpha** — template updates, `.gitignore` allowlist for `docs/`, and TM-export tooling are deferred to a follow-up. Spec lands tagged for design review.

### Updated files

- `intern-os/VERSION` — 0.4.1 → 0.5.0-alpha.0
- `intern-os/SKILL.md` — `version:` 0.4.1 → 0.5.0-alpha.0
- `adapters/claude-code/SKILL.md` — multi-workspace + dual-binding documentation
- `adapters/claude-code/scripts/resolve-thread.sh` — colon-separated `INTERNOS_WORKSPACE` walk; `thread_id_claude_code:` fallback
- `adapters/claude-code/scripts/session-start.sh` — multi-workspace surface in preload context
- `intern-os/scripts/sync-check.sh` — hyphen-platform regex fix in workspace-scan thread_id validation
- `docs/specs/git-tracking.md` — **new**: three-tier git-tracking convention
- `docs/specs/transfer-modules.md` — **new**: TM standard spec v1.0 + v1.1
- `docs/specs/shared-docs-and-tm-export.md` — **new**: spec stub (no implementation)
- `templates/git/{workspace,project}.gitignore` — **new**: allowlist ignores
- `templates/tm/{SKILL.md, README.md, references/, scripts/}` — **new**: base TM template
- `templates/tm/engagement-delivery/{SKILL.md, README.md, references/, scripts/}` — **new**: engagement-delivery TM template
- `CHANGELOG.md` — this entry

### Validation

Validated against this machine's live workspaces before the alpha tag:

- Resolver walks colon-separated `INTERNOS_WORKSPACE` and resolves workstreams under multiple workspace roots (exit 0 for in-scope, silent exit 1 for out-of-scope).
- `sync-check` workspace sweep accepts `claude-code:` thread_ids and recognizes mixed-platform projects without false-positive warnings.
- `sync-check --workstream` mode runs clean against the alpha workstream.
- Portable TM verifier (`templates/tm/scripts/verify_tm.sh`) passes against the live `method-lab-engine-delivery` TM; byte-identical to the verifier shipped inside that TM.
- Hook scripts (`session-start.sh`, `session-end.sh`) match the hooks declared in `adapters/claude-code/hooks/settings.json`.

### Compatibility

- **Solo-workspace single-binding usage unchanged.** Existing single-path `INTERNOS_WORKSPACE` values continue to work — the resolver treats `INTERNOS_WORKSPACE=/path/to/workspace` and `INTERNOS_WORKSPACE=/path/to/workspace` (no colon) identically.
- **Workstreams without `thread_id_claude_code:` keep their previous resolution behavior.** The fallback is opt-in per workstream.
- **TM standard is additive.** Existing workstreams without a TM keep working; the standard only applies when a TM is exported.
- **Git-tracking convention is documentation.** No tooling enforces it; existing project layouts continue to work.
- **No upgrade required for existing installs** unless you want the new resolver behavior. To upgrade: re-run the install per `adapters/claude-code/SETUP.md`.

### Known limitations (deferred to v0.5.0 stable or later)

- Shared-docs convention (IOS-5) ships as a spec stub only. Template updates, `.gitignore` allowlist for `docs/`, and TM-export resolver work are outstanding. Implementation lands in a follow-up alpha or in v0.5.0 stable.
- TM-export tooling does not yet automate the snapshot-into-`<workstream>/docs/` step the shared-docs spec describes.
- `session-start.sh` `tick-md` task discovery does not yet surface frontmatter-tagged tasks in TICK.md (pre-existing in v0.4.x; orthogonal to this release).

## v0.4.1 — 2026-05-13

DX patch. Addresses [#21](https://github.com/poktalabs/intern-os/issues/21). Installed skill now carries forward version/source metadata so agents and humans can tell what's running and where it came from. No breaking changes.

### Fixed

- **Installed skill is self-describing.** Adds `repo:` field to `intern-os/SKILL.md` frontmatter and a new `intern-os/VERSION` file packaged alongside `SKILL.md`. Before, an install at `~/.claude/skills/intern-os/` had no `repo:`, no `VERSION`, no `CHANGELOG` — checking for updates required guessing the repo URL.
- **Release workflow guards version consistency.** `.github/workflows/release.yml` now asserts that `intern-os/VERSION` and the `version:` field in `intern-os/SKILL.md` both match the pushed tag. Prevents drift between the three places version lives.

### Documentation

- **Versioning note added to README.** Records that `v1.0.0` / `v1.0.1` / `v1.1.0` tags on the remote are premature rollbacks; the active line is `0.x`. Closes [#23](https://github.com/poktalabs/intern-os/issues/23).

### Compatibility

- No behavior changes. Existing installs upgrade by re-installing or copying the new `VERSION` file alongside `SKILL.md`.

---

## v0.4.0 — 2026-05-11

Multi-agent feature release. Bundles three issues: [#16](https://github.com/poktalabs/intern-os/pull/16) (Claude Code lifecycle adapter), [#10](https://github.com/poktalabs/intern-os/issues/10) (isolated-session handoff doctrine + manifest), [#11](https://github.com/poktalabs/intern-os/issues/11) (shared-thread inbox projects). Each landed through dogfood-tested PRs (#19 ran 3 dogfood rounds with 23 findings addressed; #20 ran 2 rounds with 13 findings addressed). No breaking changes.

### New features

- **Claude Code lifecycle adapter (#16)** — cwd-bound workstream resolution + `SessionStart` / `SessionEnd` hooks. Each `/resume` continues the same thread via working-directory binding. Adds `adapters/claude-code/{SKILL.md, SETUP.md, hooks/settings.json, scripts/}` and a `--workstream <path>` flag to `sync-check.sh` for single-workstream scoping.

- **Isolated-session handoff (#10)** — deterministic, file-backed manifest layer so a coordinator can delegate to an isolated specialist subagent (Hermes `delegate_task`, OpenClaw `sessions_spawn`, Claude Code `Agent` tool) without losing workstream binding. Four doctrinal invariants: deterministic resolution, explicit isolation, files-as-source-of-truth, role separation. Ships canonical schema (`intern-os/schemas/handoff-v1.yaml`), POSIX reference verifier (`intern-os/scripts/verify-handoff.sh`) with two-layer validation (well-formedness + binding_checks), manifest template, EN/ES references, per-harness adapter sections, and an end-to-end example.

- **Shared-thread inbox projects (#11)** — project-level opt-in (`shared_thread_ids: true` + `shared_thread_platforms: ...`) for inbox-style messaging platforms (Telegram, WhatsApp, Signal, iMessage, SMS, LINE) where one DM is the collaboration surface for multiple workstreams. `sync-check.sh` suppresses duplicate-thread_id warnings within opted-in projects when the platform is in the allowlist. Discord and Slack are hardcoded as never-suppressed regardless of opt-in.

### Updated files

- `intern-os/SKILL.md` — version 0.3.3 → 0.4.0; new "Isolated-session handoff" section; updated tooling list
- `intern-os/assets/WORKSTREAMS.md` — version 0.4.0; coordinator + specialist operational guidance for handoffs
- `intern-os/references/{en,es}/FRAMEWORK.md` — version 0.4.0 header; new "Project shapes" section; updated sync-check validation table
- `intern-os/references/{en,es}/ISOLATED-HANDOFF.md` — **new**: full reference doc, EN + ES parity
- `intern-os/schemas/handoff-v1.yaml` — **new**: canonical schema with two-layer dispatch model documented
- `intern-os/scripts/verify-handoff.sh` — **new**: POSIX verifier (~290 lines, no deps); 4 named binding_checks + well-formedness layer; smoke-tested across happy path + 7 failure modes
- `intern-os/scripts/sync-check.sh` — version 0.4.0; reads project-level `shared_thread_ids` / `shared_thread_platforms`; case-insensitive value parsing; hardcoded discord/slack never-suppressed set; half-config warnings (both directions); fixed sed-delimiter bug on slack thread_ids; tightened `extract_field` to require `:` (no prefix matching)
- `intern-os/assets/templates/{handoff/manifest.yml, project/PROJECT.md}` — **new** handoff template; PROJECT.md adds commented-out shared-thread inbox section
- `adapters/claude-code/{SKILL.md, SETUP.md, CLAUDE.md, hooks/, scripts/}` — Claude Code adapter (new + updated)
- `adapters/{hermes, openclaw, claude-code}/SETUP.md` — per-harness isolated-handoff sections
- `examples/isolated-session-handoff.md` — **new**: end-to-end walkthrough
- `docs/specs/v0.4.0-isolated-handoff.md` — **new**: accepted spec (graduated 2026-05-08)
- `CHANGELOG.md` — v0.4.0 entry

### Compatibility

- **Solo-agent thread-bound usage unchanged.** Handoff layer is opt-in via manifests; shared-thread inbox is opt-in per-project; Claude Code adapter is additive.
- **No breaking changes.** Existing projects (no `shared_thread_ids` field) keep the previous strict duplicate-detection. Existing workstreams without `handoffs/` subdirectory work as before.
- **OpenClaw + Hermes adapters** — gain isolated-handoff sections but require no install changes for existing users.

### Known limitations (deferred to v0.4.1+)

- Manifest immutability is doctrine-only (no signing). Covered by the manifest-signing open question in the spec.
- Concurrent specialists for the same workstream are not formally locked.
- Cross-workstream handoff requires spawning two specialists, one per workstream.
- `binding_checks` array in manifests is documentary in v1; v2+ verifiers may parse and dispatch.

### Dogfood notes

The handoff doctrine itself was dogfooded through 5 specialist-spawning cycles across PR #19 (3 rounds) and PR #20 (2 rounds). 36 total findings; 33 fixed in the bundled release; 3 architectural concerns deferred with explicit rationale. One CRITICAL exploit (flow-style YAML bypassing the allowlist) and one CRITICAL contract violation (template silent opt-in) were caught by dogfood and fixed before merge.

---

## v0.3.3 — 2026-05-07

Security scan cleanup. Addresses [#17](https://github.com/poktalabs/intern-os/issues/17). Patch release — no behavior changes, no breaking changes. Reduces Hermes installer's security-scan finding count from 63 to 58 (eliminates 4 actionable findings; remaining 58 are `agent_config_mod` false positives in framework documentation that cannot be removed without gutting the AGENTS.md project-context convention).

### Fixed

- **Pinned `tick-md` install version** — `npm install -g tick-md` → `npm install -g tick-md@1` in `intern-os/SKILL.md` `setup.help`, `intern-os/references/en/SETUP.md`, `intern-os/references/es/SETUP.md`. Eliminates 3 `unpinned_npm_install` (medium, supply chain) findings.
- **Replaced `cd ../..` path traversal in extract-changelog.sh** — now uses `git rev-parse --show-toplevel` to locate the repo root. Cleaner anyway. Eliminates 1 `path_traversal` (medium, traversal) finding.

### Added

- **Hermes security scan section** in `adapters/hermes/SETUP.md` — explains the expected DANGEROUS verdict, why `agent_config_mod` flags are false positives for this skill, and the `--force` install procedure.

### Updated files

- `intern-os/SKILL.md` — version 0.3.2 → 0.3.3, pinned tick-md@1 in setup.help
- `intern-os/references/en/SETUP.md` — pinned tick-md@1
- `intern-os/references/es/SETUP.md` — pinned tick-md@1
- `intern-os/scripts/extract-changelog.sh` — switched from `cd ../..` to `git rev-parse --show-toplevel`
- `adapters/hermes/SETUP.md` — added "Hermes security scan" subsection
- `CHANGELOG.md` — v0.3.3 entry

### Compatibility

No behavior changes. No breaking changes. The `git rev-parse` change in `extract-changelog.sh` adds an implicit dependency on `git` being available (it always is in GitHub Actions, where the script runs). Local invocations from a non-git directory will now exit with a clear error instead of silently resolving the wrong path.

---

## v0.3.2 — 2026-05-07

Hermes Agent native-plumbing release. Addresses [#12](https://github.com/poktalabs/intern-os/issues/12). Adopts three Hermes mechanisms to reduce manual setup surface area while preserving OpenClaw and Claude Code compatibility. No breaking changes.

### New features

- **Configurable workspace path** — `intern-os/SKILL.md` declares `internos.workspace_path` as a Hermes config var (`metadata.hermes.config`). `hermes setup` prompts for it; the resolved value is injected into the skill payload at activation as a `[Skill config: ...]` block. Default: `~/.hermes/workspace`. Eliminates hardcoded workspace paths from the SKILL body and adapter SETUP.
- **Prerequisite validation** — `prerequisites.commands: [tick]` surfaces a Hermes setup note when `tick-md` is missing on PATH (advisory; does not block activation).
- **Setup help** — `setup.help` field provides a human-readable install hint shown alongside the prerequisite note.
- **Slash command** — `/intern-os` is now auto-registered by Hermes from the skill's `name:` field; documented in the Hermes adapter SETUP.

### Updated files

- `intern-os/SKILL.md` — v0.3.2: enriched frontmatter (`prerequisites`, `setup.help`, `metadata.hermes.config`)
- `adapters/hermes/SETUP.md` — v0.3.2: rewritten around `hermes setup` flow, slash command, and auto-supporting-files. Manual `cp WORKSTREAMS.md` step removed (auto-listed by Hermes).
- `IMPLEMENT.md` — **removed**: superseded by adapter SETUPs
- `CHANGELOG.md` — v0.3.2 entry

### Compatibility

- **OpenClaw, Claude Code, generic adapters** — unaffected. The added frontmatter keys (`prerequisites`, `setup`, `metadata.hermes.config`) are silently ignored by their loaders.
- **Hermes** — requires support for `metadata.hermes.config` (verified present in current `agent/skill_utils.py`). Any reasonably current Hermes build.

### Spec

Full design: [`docs/specs/v0.3.2-hermes-compat.md`](docs/specs/v0.3.2-hermes-compat.md)

---

## v0.3.1 — 2026-04-12

Operational visibility and rollout tooling. Addresses [#7](https://github.com/poktalabs/intern-os/issues/7): workstream registry and rollout protocol for production internOS.

### New features

- **Workstream registry** — `projects/REGISTRY.md` is a derived index of all non-archived workstreams, generated by `generate-registry.sh`. Contains project, workstream name, thread_id, phase, owner, health status, and filesystem path. The Phase column distinguishes active, paused, and backlog workstreams. Explicitly derived from BRIEF.md + STATUS.md — never authoritative. Lives in `projects/` (not workspace root) to avoid auto-loading on every agent message.
- **Registry generator script** — `scripts/generate-registry.sh` scans all projects and workstreams, reads BRIEF.md + STATUS.md, and outputs `projects/REGISTRY.md`. Same interface as sync-check.sh (`<workspace-path>` argument).
- **Rollout protocol** — `references/en/ROLLOUT.md` and `references/es/ROLLOUT.md` document the formal process for bringing workspaces to internOS spec: assess, normalize active workstreams, classify legacy content, validate.
- **Rollout validation mode** — `sync-check.sh --rollout` appends a prioritized action list: unbound workstreams, incomplete identity fields, missing TICK.md tags.

### Updated files

- `intern-os/scripts/generate-registry.sh` — **new**: workstream registry generator
- `intern-os/scripts/sync-check.sh` — v0.3.1: added `--rollout` flag for focused rollout validation
- `intern-os/references/en/ROLLOUT.md` — **new**: rollout/migration protocol
- `intern-os/references/es/ROLLOUT.md` — **new**: Spanish translation of rollout protocol
- `intern-os/references/en/FRAMEWORK.md` — v0.3.1: registry as derived component, updated roadmap, rollout reference
- `intern-os/references/es/FRAMEWORK.md` — v0.3.1: same updates in Spanish
- `intern-os/assets/WORKSTREAMS.md` — v0.3.1: registry section, rollout reference
- `intern-os/SKILL.md` — v0.3.1: registry in storage layer, generate-registry.sh in tooling
- `examples/workspace-layout.md` — v0.3.1: REGISTRY.md in example tree
- `adapters/claude-code/CLAUDE.md` — v0.3.1: cross-workstream lookup via registry
- `CHANGELOG.md` — v0.3.1 entry

---

## v0.3.0 — 2026-04-11

Simplification and hardening release. Removes Pod as a concept. Re-centers internOS around Project + Workstream with a three-layer architecture (storage, resolution, runtime).

Addresses [#4](https://github.com/poktalabs/intern-os/issues/4): project-level `AGENTS.md` for agent context on messaging platforms.

### Breaking changes

- **Pod removed from internOS core.** All Pod-related concepts, templates, discovery questions, lifecycle, and entity_type classification have been removed. Projects are now the only top-level container.
- **PROJECT.md simplified.** Removed `entity_type`, `client`, `proposal_status`, `pod_type`, `delivery_manager`, `architect`, `expected_revenue`, `firm_dependencies`, `firm`, and pod-specific lifecycle checklist. Existing PROJECT.md files should be simplified to the new schema.
- **BRIEF.md schema updated.** Now includes mandatory `thread_id`, `project`, `workstream`, `owner`, `created`, `last_updated` fields. Existing BRIEF.md files should add the new identity fields.
- **STATUS.md schema updated.** Now uses structured fields: Phase, Next, Owner, Blockers, Updated.
- **MEMORY.md template updated.** Now uses structured sections: Durable context, Key learnings, Open threads.
- **RESOURCES.md template updated.** Now uses a structured table format.
- **STAKEHOLDERS.md template updated.** Now separates Internal and External stakeholders.
- **DECISIONS.md template updated.** Now uses date-prefixed entries with decision/rationale/impact/status.

### New features

- **Three-layer architecture** (storage, resolution, runtime) is now explicitly documented across SKILL.md, FRAMEWORK.md, and WORKSTREAMS.md.
- **Project-level AGENTS.md** ([#4](https://github.com/poktalabs/intern-os/issues/4)): New template at `assets/templates/project/AGENTS.md`. Contains project-level context (stack, conventions, key people, integrations, architectural constraints). Loaded before workstream files. Works on all platforms (no cwd dependency).
- **Resolution doctrine:** Exact `thread_id` matching is now the canonical and only resolution method. Fuzzy matching, keyword similarity, and path proximity are explicitly forbidden.
- **Recovery doctrine:** Agents must reconstruct from workstream files when sessions degrade. BRIEF.md + STATUS.md must be sufficient to restart any workstream.
- **Isolation doctrine:** Cross-workstream reads are forbidden by default. Cross-workstream synthesis must be explicitly requested.
- **Tiered runtime loading:** Default loads only BRIEF.md + STATUS.md (Tier 1). DECISIONS.md + STAKEHOLDERS.md on demand (Tier 2). MEMORY.md + RESOURCES.md + docs/ on demand (Tier 3).
- **Loading order updated:** Resolution → AGENTS.md → BRIEF.md → STATUS.md → escalate on demand.

### Updated files

- `intern-os/SKILL.md` — v0.3.0: Pod removed, three-layer architecture, AGENTS.md support, resolution/recovery/isolation doctrines, tooling vs. doctrine section
- `intern-os/assets/WORKSTREAMS.md` — v0.3.0: three-layer table, resolution/recovery/isolation doctrines, AGENTS.md loading
- `intern-os/scripts/sync-check.sh` — v0.3.0: updated for three-layer model — validates AGENTS.md presence, BRIEF.md identity fields, thread_id uniqueness, STATUS.md/MEMORY.md size limits
- `intern-os/assets/templates/project/PROJECT.md` — simplified: removed all Pod/entity_type fields
- `intern-os/assets/templates/project/AGENTS.md` — **new**: project-level agent context
- `intern-os/assets/templates/workstream/BRIEF.md` — strengthened: mandatory identity fields
- `intern-os/assets/templates/workstream/STATUS.md` — structured: Phase/Next/Owner/Blockers/Updated
- `intern-os/assets/templates/workstream/MEMORY.md` — structured sections
- `intern-os/assets/templates/workstream/DECISIONS.md` — structured format
- `intern-os/assets/templates/workstream/STAKEHOLDERS.md` — Internal/External sections
- `intern-os/assets/templates/workstream/RESOURCES.md` — table format
- `intern-os/references/en/FRAMEWORK.md` — v0.3.0: complete rewrite with three-layer architecture, "validated vs. doctrine" section
- `intern-os/references/es/FRAMEWORK.md` — v0.3.0: Spanish translation updated to match, including "validated vs. doctrine" section
- `intern-os/references/en/PLAYBOOK.md` — v0.3.0: updated loading order, AGENTS.md, resolution
- `intern-os/references/es/PLAYBOOK.md` — v0.3.0: same updates in Spanish
- `adapters/openclaw/SETUP.md` — v0.3.0: updated AGENTS.md block with resolution/recovery/isolation
- `adapters/hermes/SETUP.md` — v0.3.0: updated platform startup note
- `adapters/generic/SETUP.md` — v0.3.0: updated instruction block with resolution/recovery/isolation
- `adapters/claude-code/CLAUDE.md` — v0.3.0: updated with resolution, AGENTS.md, tiered loading
- `README.md` — updated to reflect three-layer architecture
- `examples/workspace-layout.md` — updated with AGENTS.md and new template formats

### Migration from v0.2.x

1. **Remove Pod fields from PROJECT.md:** Delete `entity_type`, `client`, `proposal_status`, `pod_type`, `delivery_manager`, `architect`, `expected_revenue`, `firm_dependencies`, `firm`, and the "Rules by entity_type" section. Use the new simplified template.
2. **Add AGENTS.md to projects:** Create `projects/[name]/AGENTS.md` with project-level context (optional but recommended).
3. **Update BRIEF.md files:** Add `project`, `workstream`, `owner`, `created`, `last_updated` fields. Ensure `thread_id` is present.
4. **Update WORKSTREAMS.md:** Replace workspace root `WORKSTREAMS.md` with v0.3.0 version from `assets/WORKSTREAMS.md`.
5. **Update adapter configuration:** Follow the v0.3.0 adapter SETUP.md for your framework.

---

## v0.2.2 — 2026-04-06

Addresses [#2](https://github.com/poktalabs/intern-os/issues/2): Discord timeout-safe startup while preserving per-workstream context.

### Changes

- **Platform startup protocol (SKILL.md, all adapters):** ACK-first rule is now mandatory, not advisory. Replaces the loose "platform timeout protocol" note with an explicit startup mode table: Discord/Slack = LIGHT (ACK → BRIEF + STATUS → MEMORY on demand), Telegram/CLI = FULL.
- **MEMORY.md hygiene hardened:** Hard limit remains 80 lines; target ≤50 lines now documented. Rule clarified: curated summary only — detailed chronology must go in `docs/` notes, not MEMORY.md. Consolidation must happen before ending the session.
- **Version bump:** `2.1.0` → `0.2.2` across SKILL.md and all adapter SETUP.md files.

### Updated files

- `intern-os/SKILL.md` — v0.2.2: platform startup table, LIGHT mode contract, MEMORY.md hygiene rules
- `adapters/openclaw/SETUP.md` — v0.2.2: same platform startup table in AGENTS.md block
- `adapters/hermes/SETUP.md` — v0.2.2: Discord startup note added to Discord config section
- `adapters/generic/SETUP.md` — v0.2.2: platform modes in generic instructions block

---

## v2.1.0 — 2026-03-31

### New features

- **Project discovery:** New `Discover project: [name]` command creates a project with `PROJECT.md`, `tick init`, agent registration, and a communication thread. The agent asks 4 discovery questions (domain, exclusions, owner, archive condition).
- **PROJECT.md template:** New template at `assets/templates/project/PROJECT.md` — defines project identity with domain, owner, boundaries, success criteria, and active workstreams list.
- **Project-vs-workstream criterion:** Documented decision rule — a project groups work of the same domain over time; a workstream is a concrete sprint within that domain.
- **Project lifecycle:** Full lifecycle defined (discover → active → archive) with explicit archive condition in PROJECT.md.

### Updated files

- `adapters/hermes/SKILL.md` — v2.1.0: added `Discover project` command, project-vs-workstream criterion, project lifecycle
- `assets/WORKSTREAMS.md` — v2.1: added Project Discovery and project-vs-workstream sections, split lifecycle into project + workstream
- `references/en/PLAYBOOK.md` — v2.1: added Entry E (new project discovery)
- `references/en/FRAMEWORK.md` — v2.1: updated project layer to include PROJECT.md, expanded project lifecycle with discovery flow
- **Sync check script:** `scripts/sync-check.sh` — diagnostic tool that scans a workspace and reports mismatches: missing thread_ids, incomplete Slack IDs, missing workstream files, orphan directories without tick.md tasks. Platform-agnostic, report-only.
- **Checkpoint reminder script:** `scripts/checkpoint-reminder.sh` — detects active workstreams with stale STATUS.md files. Configurable threshold (default 3 days). Cron-compatible exit codes.
- **MEMORY.md read limits:** Agents now read only the last 80 lines of MEMORY.md on startup. MEMORY.md must be maintained as a curated summary (≤80 lines), not a session log. Documented across all adapters (Hermes, OpenClaw, Claude Code, generic); `sync-check.sh` validates line count.
- **STATUS.md size constraint:** STATUS.md must answer "where does this workstream stand?" in ≤10 lines.
- **Platform timeout protocol:** On platforms with short response timeouts (Discord ~2min, Slack ACK ~3s), agents must emit an acknowledgment before loading context files. Documented in WORKSTREAMS.md, PLAYBOOK.md, FRAMEWORK.md, and all adapters.
- **Repo restructure:** Skill content (SKILL.md, assets, references, scripts) moved into `intern-os/` subdirectory for out-of-the-box installation on both Hermes and OpenClaw. Unified SKILL.md replaces per-adapter SKILL.md files. Adapter SETUP.md files remain at `adapters/[framework]/`.
- **Uninstall guide:** All adapters + FRAMEWORK.md (en/es) now document uninstallation steps and workspace data model.

### Install commands (v2.1.0)

| Framework | Command |
|-----------|---------|
| Hermes Agent | `hermes skills install poktalabs/intern-os/intern-os` |
| OpenClaw | `openclaw skills install https://github.com/poktalabs/intern-os` |

## v2.0.0 — 2026-03-30

### Breaking changes

- **Project container:** Workstreams now live inside projects (`projects/[name]/workstreams/`) instead of a flat `workstreams/` directory. Existing workstream directories must be moved into a project.
- **SKILL.md moved:** Root `SKILL.md` moved to `adapters/openclaw/SKILL.md`. OpenClaw users should update their skill reference.
- **Thread ID format:** `discord_thread_id` in BRIEF.md replaced by `thread_id: [platform]:[id]` (e.g., `thread_id: discord:123456789`).

### New features

- **Agent-framework agnostic:** Adapters for OpenClaw, Hermes Agent, Claude Code, and a generic fallback. Core spec is agent-neutral.
- **tick.md integration:** TICK.md at project root as the default task management layer. Full coordination protocol with claim/release cycle. Project template includes pre-configured TICK.md and .tick/config.yml.
- **Multi-platform communication:** Discord forums and Slack threads as first-class platforms. Platform-agnostic communication protocol in COMMUNICATION.md.
- **Project templates:** `assets/templates/project/` (TICK.md + .tick/config.yml + workstreams/) and `assets/templates/workstream/` (6 files with headers and stubs).
- **Workspace layout example:** `examples/workspace-layout.md` showing a fully populated v2 workspace.

### Migration from v1

1. Create a project directory and move workstreams into it:
   ```bash
   mkdir -p projects/my-project
   mv workstreams/ projects/my-project/workstreams/
   ```
2. Initialize tick.md in the project:
   ```bash
   cd projects/my-project
   tick init
   tick agent register @agent-name --type bot --role engineer
   ```
3. Replace root WORKSTREAMS.md with the v2 version from `assets/WORKSTREAMS.md`
4. Update your agent configuration using the appropriate adapter (`adapters/[framework]/SETUP.md`)
5. Update `thread_id` in BRIEF.md files:
   - Old: `discord_thread_id: 123456789`
   - New: `thread_id: discord:123456789`
6. Create tasks in TICK.md for each active workstream:
   ```bash
   tick add "Workstream description" --tag workstream-name
   ```

## v1.0.0 — 2026-03-24

Initial release. OpenClaw + Discord only, flat workstreams directory, task management as external recommendation.
