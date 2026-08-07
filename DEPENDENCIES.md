# Dependencies — Ka0s Consumable Master

Everything you need installed to run, develop, test or release this addon, with commands that work
on **WSL2 / Ubuntu** (the collection's development environment). Required by the Ka0s WoW Addon
Standard, `documentation-§7`.

Every entry names **what needs it and how that is known** — a `file:line`, an import, or a
documented command. Nothing here is listed on a hunch; where something is only plausibly required,
it says so in those words.

This file answers **what to install**. [`docs/testing.md`](./docs/testing.md) answers **how to
verify**. Neither repeats the other.

---

## 1. Runtime (in-game) — what a player needs

**World of Warcraft (Retail), Interface `120007`.** Nothing else.

| Thing | Required? | Evidence |
|-------|-----------|----------|
| WoW Retail client, Interface 120007 | Yes | `ConsumableMaster.toc:1` (`## Interface: 120007`) |
| Any other addon | **No** | The TOC has **no `## Dependencies:` line at all** — there is no hard addon dependency. |
| Ace3, LibStub, CallbackHandler-1.0, LibSharedMedia-3.0 | No — **vendored** | Listed as `## OptionalDeps` (`ConsumableMaster.toc:12`) and shipped inside the package under `libs/` (`libs/AceAddon-3.0/`, `libs/AceConsole-3.0/`, `libs/AceDB-3.0/`, `libs/AceEvent-3.0/`, `libs/AceGUI-3.0/`, `libs/AceGUI-3.0-SharedMediaWidgets/`, `libs/CallbackHandler-1.0/`, `libs/LibSharedMedia-3.0/`, `libs/LibStub/`). If the player also runs a standalone copy, LibStub picks the newer one. |
| `LibKa0s` v1.8.2 | No — **vendored** | `libs/LibKa0s/`; provenance claimed by the `Bundles [LibKa0s](…) vX.Y.Z (MIT).` line in **`CLAUDE.md`** (it moved out of `README.md` at test-kit revision 9) and byte-verified against that LibKa0s tag by `tests/test_vendor_sync.lua`. |

Nothing is fetched at package time: `.pkgmeta` has **no `externals:` block** and sets
`enable-nolib-creation: no`. The player installs one folder (`library-stack`, `packaging`).

---

## 2. Development — the contributor toolchain

Four things, and `git`. Install all of them with:

```sh
sudo apt update
sudo apt install -y lua5.1 luarocks git
sudo luarocks install luacheck
sudo apt install -y pipx && pipx ensurepath && pipx install lizard
```

Then open a new shell (`pipx ensurepath` edits your profile) and run the verification column below.

| Tool | Version | Why — with evidence | Install | Verify |
|------|---------|---------------------|---------|--------|
| **Lua 5.1** — and the binary **must be named `lua5.1` on `PATH`** | **5.1 exactly. Not a preference.** | Two independent reasons. (a) The suite **shells out to the literal string `lua5.1`**: `tests/test_runner_list.lua:19` (`io.popen("lua5.1 " .. root .. "/tests/run.lua --list 2>&1")`) and `:56` (`os.execute("lua5.1 " .. root .. "/tests/run.lua --list > /dev/null 2>&1")`). With no `lua5.1` on `PATH` those cases fail, no matter what `lua` points at. (b) The client runs 5.1, so the harness targets 5.1 and lint enforces it: `.luacheckrc:7` sets `std = "lua51"`, which rejects anything outside the 5.1 standard library. (c) The vendored test kit — which **is** the harness, loaded by `tests/run.lua` — sandboxes every chunk with `setfenv` (`tests/_kit/loader.lua:31`, `:50`), and `setfenv` does not exist after 5.1. | `sudo apt install -y lua5.1` | `lua5.1 -v` → `Lua 5.1.5` |
| **luacheck** | **Any recent.** Pinning would be false precision — the config uses no version-specific feature. | The lint half of the green gate. `docs/testing.md:15`, `CLAUDE.md` "Gate" block; configured by `.luacheckrc`. | `sudo apt install -y luarocks && sudo luarocks install luacheck` | `luacheck --version` |
| **lizard** | **Any recent.** Same reasoning — the invocation uses only stock flags. Record whatever version you used in the report header. | Feeds the `complexity` suite of `tests/_kit/run-automated-tests.sh`, recorded in every run bundle (`automated-tests`). | `sudo apt install -y pipx && pipx ensurepath && pipx install lizard` | `lizard --version` |
| **git** | Any recent. | Beyond version control, one suite **executes `git`**: `tests/test_vendor_sync.lua` delegates to the vendored kit, whose `tests/_kit/vendor_sync.lua:154` runs `git -C "<sibling>" …` to compare `libs/LibKa0s/` and `tests/_kit/` against the LibKa0s tag this repo's `CLAUDE.md` claims. | `sudo apt install -y git` | `git --version` |
| **A sibling `LibKa0s` checkout** (not software) | matching the tag the `Bundles [LibKa0s](…)` line in `CLAUDE.md` names | `tests/_kit/vendor_sync.lua:145` resolves `SIBLING = ROOT .. "/../LibKa0s"` (the `/../LibKa0s` default at `:70`). Absent, the two vendor-sync cases **report a `skip` carrying their reason rather than failing** — `siblingTag()` calls `T.skip("<sibling> checkout absent — the vendored payload was NOT compared")` when the sibling has no `HEAD:LibKa0s/Core.lua` (`:191-193`), which is the one sanctioned quiet case. The suite is still green without the checkout, but the vendored-payload check is then not actually running, and a `skip` is not a pass. | `git clone https://github.com/tusharsaxena/LibKa0s ../LibKa0s` | `ls ../LibKa0s/LibKa0s` |
| **POSIX `ls`** | any | Directory listing shells out rather than depending on LuaFileSystem: `tests/_kit/framework.lua:214` (`collect(('ls -A "%s" 2>/dev/null'):format(dir))`, with a `dir /b` cmd.exe fallback on the next line). Present on any Ubuntu; listed because it is a real, non-obvious runtime requirement of the harness. | preinstalled (coreutils) | `ls --version` |
| **`diff`** | any | The vendored-copy check in `docs/testing.md:26-29` is four `diff -r` invocations, run after any re-vendor and before any release. | preinstalled (diffutils) | `diff --version` |
| **`luac`** (optional) | 5.1 | Single-file syntax check, `docs/testing.md:17`. Ships with the `lua5.1` package. | included with `lua5.1` | `luac -v` |

### Why `pipx` and not `pip` for lizard

Ubuntu 24.04 marks its system Python **externally managed** (PEP 668), so `pip install lizard`
**fails** with an `error: externally-managed-environment` — an instruction that looks correct and
is not. `pipx` installs the tool into its own virtualenv and puts the entry point on `PATH`, which
is what you want for a command-line tool anyway.

The documented alternative, if you would rather not install `pipx`:

```sh
pip3 install --user --break-system-packages lizard
```

That flag overrides the PEP 668 marker deliberately. It works, but it writes into the
system-managed user site directory, which is the situation PEP 668 exists to prevent. Prefer
`pipx`.

### Not required, despite appearances

- **LuaFileSystem (`lfs`).** Deliberately avoided — `tests/_kit/framework.lua:197-215` shells out to
  `ls -A` (with a `dir /b` fallback) specifically so `lfs` is not a dependency. Do not add it.
- **Any Lua later than 5.1.** "5.2 will probably work" is false here: `lua5.1` is named literally
  in two test cases (above) and `.luacheckrc` pins `std = "lua51"`.
- **A WoW client, to develop.** The whole suite runs headless against `tests/wow_mock.lua`. You
  need the client only for the in-game smoke tests (`docs/smoke-tests.md`).

---

## 3. Release / assets

**None of this is needed to build, run or test the addon.** You can fix a typo, run both gates and
ship a change with nothing beyond section 2 installed.

| Thing | Needed for | Notes |
|-------|-----------|-------|
| **The CurseForge packager** | Producing the distributable zip | Runs on CurseForge's side from `.pkgmeta`; nothing to install locally. `.pkgmeta` has no `externals:` block, so packaging fetches nothing. |
| **`lizard`** | The `complexity` suite of the automated-test run made before a release tag | Already listed in section 2. Its absence means the report is **stale, not that the addon is non-compliant** (`performance-§10`) — leave the previous report committed with its own header and say so in the release notes. Never hand-edit it. |
| **`diff`, `git`, a sibling `LibKa0s`** | The pre-release vendored-copy check | `docs/testing.md:19-51`. Already listed in section 2. |

### Bundled assets — licensed content, not build dependencies

These ship inside the addon. They are **not** software you install and **not** things any build
step regenerates, so they are recorded here for their licensing rather than as dependencies:

- **JetBrains Mono** — `media/fonts/JetBrainsMono-Regular.ttf`, under the SIL Open Font License
  (`media/fonts/OFL.txt`). Registered with LibSharedMedia at `core/DebugLogSetup.lua:39-40` and used
  as the debug console's reference font. Nothing on your machine needs JetBrains Mono installed;
  the client reads the `.ttf` out of the addon folder.
- **Logos and screenshots** — `media/logos/`, `media/screenshots/`. Hand-produced and committed.
  `media/screenshots/` is excluded from the package (`.pkgmeta` ignore list).

**No image or font tooling is required.** There is no script in this repo that regenerates any
asset — no `scripts/` directory, no Python, no Pillow, no ImageMagick. If one is added, it belongs
in this section in the same change.

### Not evidenced

Nothing else was found. Specifically: no Python is used anywhere in this repo, no vendored binaries
exist, and no system library is linked against. If you hit a missing tool that is not on this page,
that is a bug in this page — fix it here in the same change (`documentation-§7`,
`documentation-§5`).

---

## 4. Am I set up correctly?

Run these from the repo root. Both must be green; the third is a report, not a gate.

```sh
lua5.1 tests/run.lua                                    # headless suite — exits non-zero on failure
luacheck .                                              # lint — must be 0 warnings, 0 errors
lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .       # complexity report (performance-§10)
```

The first two are the commit gate. The third is the **release** checkpoint — regenerate
a full automated-test bundle and read its diff before tagging; it never gates a commit. Full detail, and
the vendored-copy diff to run after any re-vendor, in [`docs/testing.md`](./docs/testing.md).
