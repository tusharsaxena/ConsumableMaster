# CLAUDE.md — Ka0s Consumable Master

**Ka0s Consumable Master** — an auto-managed consumable-macro addon for WoW: Midnight (Interface 120007, Ace3, Lua 5.1, English only).

## Standards compliance (read first)

This addon conforms to the **[Ka0s WoW Addon Standard](https://github.com/tusharsaxena/WowAddonStandards)** (declared as `X-Standard` in `ConsumableMaster.toc`). That repo is the source of truth for structure, naming, packaging, TOC layout, namespace/bus/compat patterns, and conventions. Frozen compliance audits live under `docs/audits/<date>/` (past code reviews under `docs/reviews/<date>/`).

**Deviation rule (MUST).** If a change you are about to make would deviate from the standard — or you notice existing code that already deviates — **stop and flag it to the user**. Never silently diverge. Let the user decide whether it should be:
1. an **accepted deviation** — this addon intentionally differs; record it as a row in
   [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) → `## Documented deviations`, shaped
   `| Rule | What differs | Why | Decided | Re-check trigger |`, where Rule is the
   `filename-§N` reference. That register is the single home: the reasoning may live in the
   issue-audit GitHub issue or an audit bundle and the row cites it, but a deviation not in
   the register is not ratified; or
2. a **change to the standard itself** — upstreamed to the [WowAddonStandards](https://github.com/tusharsaxena/WowAddonStandards) repo so every addon benefits.

This applies to both new work and anything you discover in passing.

## The `docs/` set — there is no `agent-context.md`

The canonical `docs/` set is the **trio** — **`ARCHITECTURE.md`** (what this addon is),
**`testing.md`** (how to verify) and **`smoke-tests.md`** (in-game checks) — plus the five
verification-and-record docs `test-cases.md`, `performance.md`, `perf-analysis/README.md`,
`automated-tests/README.md` and `automated-tests/RESULTS.md`, plus the topic-detail docs in three
tiers: Tier 1's six (`scope.md`, `module-map.md`, `schema.md`, `settings-panel.md`,
`data-flow.md`, `common-tasks.md`) always present, whichever Tier 2 triggers have fired, and any
Tier 3 docs this addon ships (`documentation-§3`). `ARCHITECTURE.md` is the hub of that set, not
the whole of it.

**`docs/agent-context.md` does not exist in this repo and MUST NOT be created.** The standard
deleted it in **v2.17.0**; shipping it is **anti-pattern #49**. It held `NEW_ADDON_CONTEXT.md` —
the scaffolding pack — which is fetched at runtime and never stored: a copy in the repo describes
the addon on the day it was born, forever, and because it loads as *working context* a stale copy
does not go quiet, it gets **followed** (documentation-§3). This root `CLAUDE.md` is the repo's
only agent brief.

Older audit bundles, review bundles and plans under `docs/` predate v2.17.0 and still
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
  (`core/Namespace.lua`), not `## Version:` in the TOC, not the README badge or inline
  version, and no changelog entry. Releases are the user's call.
- **Don't create docs or planning files unless asked.** Be terse, cite `file_path:line_number`, and
  comment only where the *why* is non-obvious.

## Vendored payload — the LibKa0s provenance line

Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.24.0 (MIT).

That one line is the answer to "which LibKa0s does this build carry?", and it is a **gate input,
not a comment**: `tests/test_vendor_sync.lua` greps it out of this file and compares both vendored
payloads — `libs/LibKa0s/` and `tests/_kit/` — against that tag in the sibling `../LibKa0s`
checkout. So it moves in the **same commit** as the bytes it describes; a line and a payload that
disagree is exactly the drift the gate exists to catch. It lives here rather than in `README.md`
because it answers a maintainer's question on a page written for players — the kit stopped reading
`README.md` at revision 9 (LibKa0s v1.8.1), and there is no fallback.

LibKa0s supplies the chat printer, the debug console, the slash dispatcher and schema CLI, the
settings-panel shell, its row widgets and the schema composers behind the Master controls tab and the font / border / colour blocks, the reorder drag behind the priority rows, a composite's two combat sections and the stat-priority list, the shipped art and font, the TOC-manifest reader behind
`KCM.Meta` / `KCM.Version`, the item-link primitive behind the Add-by-ID box, and the perf-capture
harness. Nine of its majors are consumed — `Widgets` joined them when the priority rows took the
library's drag handle (`settings/Category.lua`, `settings/StatPriority.lua`); `Pool` alone ships in the payload unused. It is vendored whole-folder
and never patched in place — a fix goes upstream and re-vendors ([docs/testing.md](./docs/testing.md#verifying-the-vendored-libka0s-copies)).

## Read the docs

- **[docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md)** — what this addon is: layout, load order,
  namespace pattern, message bus, LibKa0s adoption, and the invariants worth not breaking.
- **[docs/testing.md](./docs/testing.md)** — how to verify: the headless gate, the vendored-LibKa0s
  copy diff, the toolchain, TDD policy, and badge sync.
- **[DEPENDENCIES.md](./DEPENDENCIES.md)** — what to install to build, run, test or release this
  addon, with WSL2/Ubuntu commands and a verification command per tool (`documentation-§7`).
- Topic detail in `docs/` — **Tier 1 is always present**: `scope.md`, `module-map.md`, `schema.md`, `settings-panel.md`, `data-flow.md`, `common-tasks.md`. Conditional and addon-specific docs vary; `docs/ARCHITECTURE.md` → `## Documentation map` lists every page under `docs/` and says which conditional ones do not apply here (`documentation-§3`).
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
