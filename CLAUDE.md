# CLAUDE.md

**Ka0s Consumable Master** — an auto-managed consumable-macro addon for WoW: Midnight (Interface 120007, Ace3, Lua 5.1, English only).

## Standards compliance (read first)

This addon conforms to the **[Ka0s WoW Addon Standard](https://github.com/tusharsaxena/WowAddonStandards)** (declared as `X-Standard` in `ConsumableMaster.toc`). That repo is the source of truth for structure, naming, packaging, TOC layout, namespace/bus/compat patterns, and conventions. Frozen compliance audits live under `docs/audits/<date>/` (past code reviews under `docs/reviews/<date>/`).

**Deviation rule (MUST).** If a change you are about to make would deviate from the standard — or you notice existing code that already deviates — **stop and flag it to the user**. Never silently diverge. Let the user decide whether it should be:
1. a **tracked deviation** — a documented, intentional exception for this addon; or
2. a **change to the standard itself** — upstreamed to the [WowAddonStandards](https://github.com/tusharsaxena/WowAddonStandards) repo so every addon benefits.

This applies to both new work and anything you discover in passing.

## The `docs/` set — there is no `agent-context.md`

The canonical `docs/` set is exactly three files: **`ARCHITECTURE.md`** (what this addon is),
**`testing.md`** (how to verify) and **`smoke-tests.md`** (in-game checks) — plus the generated
`test-cases.md` and the topic-detail docs.

**`docs/agent-context.md` does not exist in this repo and MUST NOT be created.** The standard
deleted it in **v2.17.0**; shipping it is **anti-pattern #49**. It held `NEW_ADDON_CONTEXT.md` —
the scaffolding pack — which is fetched at runtime and never stored: a copy in the repo describes
the addon on the day it was born, forever, and because it loads as *working context* a stale copy
does not go quiet, it gets **followed** (documentation-§3). This root `CLAUDE.md` is the repo's
only agent brief.

Older audit bundles, review bundles, ledgers and plans under `docs/` predate v2.17.0 and still
name the file, and some describe a four-file or a pre-v2.3.0 `agent-context.md`-based set. Those
are **frozen history** — never treat them as a live requirement, and never "restore" the file.

## Hard rules

- **Never auto-stage, auto-commit, or auto-push.** Editing files on disk is fine; touching the git
  index is not — that includes `git add <file>`, `-A`, `-p`, `--renormalize`, and `git stash`.
  Offering to stage or commit at the end of a turn is fine; doing it yourself is not. **Exception:**
  invoking a commit-purpose slash command (e.g. `/wow-addon:commit`) *is* the instruction — a `y`
  through its confirmation flow authorizes `git add` + `git commit` on the files it named. Pushing
  still needs a separate ask.
- **Never bump the version without an explicit instruction.** Not `KCM.VERSION`
  (`core/ConsumableMaster.lua`), not `## Version:` in the TOC, not the README badge or inline
  version, and no changelog entry. Releases are the user's call.
- **Don't create docs or planning files unless asked.** Be terse, cite `file_path:line_number`, and
  comment only where the *why* is non-obvious.

## Read the docs

- **[docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md)** — what this addon is: layout, load order,
  namespace pattern, message bus, LibKa0s adoption, and the invariants worth not breaking.
- **[docs/testing.md](./docs/testing.md)** — how to verify: the headless gate, the vendored-LibKa0s
  copy diff, the toolchain, TDD policy, and badge sync.
- **[DEPENDENCIES.md](./DEPENDENCIES.md)** — what to install to build, run, test or release this
  addon, with WSL2/Ubuntu commands and a verification command per tool (`documentation-§7`).
- Topic detail in `docs/` as needed — `file-index.md`, `module-map.md`, `pipeline.md`,
  `data-model.md`, `macro-manager.md`, `macro-bar.md`, `midnight-quirks.md`, `common-tasks.md`,
  `debug.md`, `scope.md`, `smoke-tests.md`, `test-cases.md`, `automated-tests/`, `pending/LEDGER.md`.
  `test-cases.md` is **generated** — never hand-edit it. So is `automated-tests/RESULTS.md`, and a run bundle is frozen once written.
- User-facing reference: [README.md](./README.md).

## Gate

```
lua5.1 tests/run.lua    # headless test harness
luacheck .              # lint
```

Both must be green before committing. Neither gate can see the vendored library, so after any re-vendor of `libs/LibKa0s/` also run the copy diff in [docs/testing.md](./docs/testing.md#verifying-the-vendored-libka0s-copies). Manual in-game validation: [docs/smoke-tests.md](./docs/smoke-tests.md).

**At release, not at commit.** Produce a full automated-test bundle with
`lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` and review its diff before the tag — in the same
change that bumps the version. Between commits it is a **report, not a gate**: never fail a run or
block a commit on it, never tune the invocation, never hand-edit the output. **At the tag it gates** —
`/wow-addon:bump-version` refuses the bump unless the release run's `manifest.json` shows all four
suites at `pass` and zero functions above CCN 15, where a `skip` is not evaluated rather than a pass.
Rules: `performance-§10`, `automated-tests-§3`; how-to:
[docs/testing.md](./docs/testing.md#automated-test-records--the-consolidated-run).

**Static badges (Hard rule).** The README `[WoW]` and `[Tests]` badges are static and go stale silently — update each in the same change that moves its source. `[Tests]` ↔ `docs/test-cases.md`: when the suite changes (a case added/removed/renamed, or the pass count moves — i.e. whenever a failing test is resolved), regenerate (`lua5.1 tests/run.lua --list > docs/test-cases.md`) and bump the `Tests-<X>/<Y>_passing` count. `[WoW]` ↔ TOC `## Interface:`: both MUST show the same number and move together on every patch bump. Never defer to a follow-up. Details: [docs/testing.md](./docs/testing.md#test-case-inventory--badge).
