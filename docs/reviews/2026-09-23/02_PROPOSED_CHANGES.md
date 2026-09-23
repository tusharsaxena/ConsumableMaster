# 02 — Proposed changes (HLD + LLD)

**Standard version resolved:** Ka0s WoW Addon Standard **v2.64.0 (2026-09-23)**. The index was read with `curl`, and the
section files were read verbatim from `../WowAddonStandards` at `e68795f`, which carries the same index version. The standards
cross-check **was performed**. Every change below was checked against it, and each one names the rule that shaped it.

**Scope rule:** No change below targets a path under `libs/` or `tests/_kit/`. There are **no upstream changes** in this cycle
(see *Upstream change-set*).

---

## HLD — themes

### T1 — A write deferred in combat is replayed as it was queued (F-001)

**Rationale.** The combat queue already stores the exact body it deferred (`pendingUpdates[name].body`,
`modules/MacroManager.lua:412-420`). The trouble is that `FlushPending` throws that body away and rebuilds one through
`M.SetMacro`, and `M.SetMacro` only knows the single-item shape. Composites were fixed years ago by dispatching on
`entry.cat.composite`. The per-hand category was never given its own dispatch.

**Chosen.** Non-composite entries replay the queued body through `commitMacro`. That is the one write tail every macro write
already uses (F-006 of an earlier cycle made it the only one). Composites keep their re-pick, because it re-reads the enabled set
and the section orders.

**Alternatives rejected.**
- *Add a third `perHand` branch that calls `SetWeaponEnchantMacro`.* This fixes today's category, but it leaves the rebuild
  asymmetry in place for the next category shape. It also has to carry both picks on the entry, and today it carries one.
- *Request a recompute on regen instead of flushing.* This changes the documented "last write wins, one write per macro" contract
  and doubles the work on every regen.

**Trade-off.** A single-category entry now writes the body computed when it was queued, instead of re-deriving it from `itemID`.
The two are identical unless a setting that feeds the body changes mid-combat. Any such setting change goes through the schema
seam, which requests a recompute, and that re-queues the entry, so the newest body still wins.

### T2 — The single write seam never stores a shared default (F-002, part of F-006)

**Rationale.**
- `savedvariables-§2` makes `defaults/Profile.lua` the **one** declaration of every default, so that table must never be mutated.
- The `order` and `map` validators already hand back fresh tables for exactly this reason (`settings/Panel.lua:929`). The `color`
  validator was the one arm that did not.

**Chosen.** The color validator returns a shallow copy.

**Additionally.** `tests/wow_mock.lua`'s AceDB `SetProfile` should model the real `removeDefaults` over the outgoing profile.
That makes this whole class of aliasing bug visible headlessly.

**Alternatives rejected.**
- *Copy in `applyDefault` (the Slash descriptor) only.* That fixes one door. The validator is the seam every door passes through
  (`options-ui-§1`, `architecture-§5`).
- *Deep-freeze `KCM.dbDefaults` with a metatable.* AceDB's `removeDefaults` calls `setmetatable(db, nil)` on whatever it is
  handed, so the freeze would be stripped on exactly the path in question.

### T3 — Setup survives the stand-down, and standing up rebuilds from the current state (F-003, F-004, F-007)

**Rationale.**
- `slash-commands-§7` ("What MUST survive") names the settings-category registration as **setup**. A parked registration therefore
  has to replay whatever the latch says.
- `performance-§6` says standing up rebuilds from the **current** state, which includes the bag contents that
  `PLAYER_ENTERING_WORLD` would have walked.

**Chosen.**
1. Extract the parked-registration replay out of `KCM:OnRegenEnabled` into one named helper, and call it from **both** branches.
   The extraction *removes* three `and` decisions from a function sitting at CCN 15, the release gate's cap, so it moves the
   complexity down rather than sideways.
2. Extract `OnPlayerEnteringWorld`'s discover-and-sweep into one published pipeline step, called by PEW and by the latch's
   `standUp`. The step is shared, not copied.
3. For F-004, correct the false comment and record the behavior as a **Known Limitation**. Hydrating the panel while disabled
   touches a question `slash-commands-§7` records as "Recorded, not ruled", so under this repo's deviation rule
   (`CLAUDE.md`, "Deviation rule") that change is **flagged for an owner decision**, not made silently.

**Alternatives rejected.**
- *For F-003, give the settings bootstrap frame its own `PLAYER_REGEN_ENABLED` listener.* That is a second regen listener, which
  the existing design refuses on purpose (`settings/Panel.lua:1261-1266`), and the realistic trigger is already covered by the
  latch's pending registration.
- *For F-004, keep `GET_ITEM_INFO_RECEIVED` registered while disabled.* That is anti-pattern #85, the draw-gate shape the whole
  latch exists to remove.

### T4 — API currency on the hot item reads (F-005)

**Chosen.** Add a `KCM.Compat.GetItemInfo` ladder (`C_Item.GetItemInfo` first, the global as fallback) and route
`Ranker.itemFields` and `TooltipCache.Get` through it (anti-pattern #10: "route through Compat"). The unused `subType` is dropped
from `itemFields`' fetch, its cache entry and its return.

### T5 — One act, one wording, and the truth on every surface (F-008 to F-012)

**Chosen.** Small, targeted wording and predicate fixes:
- `/cm resetall` gets an accurate help line.
- Both reset doors share one combat guard, which moves into the act itself.
- The "above" tooltip is corrected.
- The bare `/cm bar` toggle reads the stored flag.
- The lock confirmation tells the truth when the bar is switched off.
- `/cm enable|disable` prints the one canonical echo (`slash-commands-§5`), not two lines.

### T6 — Test integrity (F-006, F-013)

**Chosen.**
- Add red-first cases under F-001 to F-003 (`testing-§12`, and `testing-§13` characterization before the `FlushPending` refactor).
- Make the mock's `SetProfile` faithful.
- Replace the two assertions that cannot fail.

### T7 — Comment, doc and dead-code hygiene (F-014 to F-017)

**Chosen.**
- Correct each stale comment in place.
- Remove the unread `KCM.Settings.GENERAL_TABS` export.
- Leave `O.SetMacroTab` alone. It is a deliberate test seam, and the finding is informational.
- Build the About logo path from `addonName`.

---

## Upstream change-set

**None.** No finding in `01_FINDINGS.md` is tagged `[upstream]`. So:
- this cycle produces no LibKa0s change and no minor bump;
- no re-vendor is **required** by this review;
- the vendored payload already matches `../LibKa0s/LibKa0s/` byte-for-byte.

If the wider remediation plan re-vendors LibKa0s into every addon, that is its own commit. It is not a dependency of any change
here.

---

## LLD — change set

### C-01 — `FlushPending` replays the queued body (F-001)

- **Files:** `modules/MacroManager.lua` (`M.FlushPending`, `:587-623`) and `tests/test_macromanager.lua`.
- **Before** (`:596-602`):
  ```lua
  for name, entry in pairs(pendingUpdates) do
      local ok, result
      if entry.cat and entry.cat.composite then
          ok, result = pcall(M.SetCompositeMacro, entry.cat, nil)
      else
          ok, result = pcall(M.SetMacro, name, entry.itemID, entry.catKey)
      end
  ```
- **After:**
  ```lua
  -- A composite re-picks (its body depends on the enabled set and the two
  -- section orders); every other shape replays EXACTLY the body it queued,
  -- through the one write tail. Rebuilding through SetMacro knew only the
  -- single-item shape and flushed a per-hand body as `/use item:<oil>` (F-001).
  local function replay(name, entry)
      if entry.cat and entry.cat.composite then
          return pcall(M.SetCompositeMacro, entry.cat, nil)
      end
      return pcall(commitMacro, name, entry.body, entry.itemID, entry.catKey)
  end
  ...
  for name, entry in pairs(pendingUpdates) do
      local ok, result = replay(name, entry)
  ```
- **Risk.** `commitMacro` re-runs `applyBodyLimit`, which is idempotent on an already-limited body, and it derives the icon from
  `itemID` exactly as the original write did. If combat resumes mid-flush, `queueForCombat` reads `pending = pendingUpdates[name]`
  and preserves `attempts`, just as the `SetMacro` route did.
- **Tests, in `testing-§13` order.**
  1. **First**, a characterization case pinning today's single-category flush (the FOOD case at `:330` already does this).
  2. **Then** the new red-first case:
     `FlushPending replays a per-hand body with its slot lines (red under: the SetMacro rebuild)`. It should assert
     `mock.macros["KCM_WPN_ENCH"].body` contains `/use 16` and `/use 17` after a deferred `SetWeaponEnchantMacro` plus a flush.
  3. A second case on `/cm rewritemacros` in combat, asserting the `WPN_ENCH` body survives the flush.
- **Standards.** Keeps MacroManager as the sole protected-API caller (`events-frames-taint-§4`). Adds no second write path.
- **Test movement:** about +2 cases.

### C-02 — The color validator copies, and the mock's `SetProfile` is faithful (F-002, part of F-006)

- **Files:** `settings/Panel.lua` (`VALIDATORS.color`, `:920-923`), `tests/wow_mock.lua` (`db.SetProfile`, `:491-499`), and
  `tests/test_schema.lua` or `tests/test_profiles.lua`.
- **Validator, after:**
  ```lua
  -- A FRESH table, exactly as `order` and `map` answer: a row's `default` IS
  -- the dbDefaults table, and storing it by reference lets AceDB's
  -- removeDefaults empty the shipped default on the next profile switch (F-002).
  color = function(_, value)
      if type(value) ~= "table" then return nil, "expected color table" end
      local out = {}
      for k, v in pairs(value) do out[k] = v end
      return out
  end,
  ```
- **Mock `SetProfile`.** Before swapping, strip defaults from the outgoing profile the way real AceDB does. Port
  `removeDefaults`' scalar and sub-table arms. The `*`/`**` arms are unused by this addon's defaults, and the comment should say
  so. The `db.profiles` store semantics stay unchanged.
- **Tests (red-first).**
  1. `schema: resetting a color row stores a copy, never the dbDefaults table` (red under: `return value`).
  2. `profiles: a profile switch after a color reset leaves the shipped default intact`. Assert
     `#KCM.dbDefaults.profile.macroBar.barBackdropColor == 4` after `/cm reset macroBar.barBackdropColor` then `db:SetProfile("B")`.
     This goes red under the old validator, but only once the mock models `removeDefaults`.
- **Risk.** Any suite that asserted identity (`rawequal(stored, row.default)`) would now fail. None was found by grep.
  Allocation is one 4-slot table per color write, and color writes happen on the settings path only.
- **Standards.** `savedvariables-§2` (one declaration, never mutated), `options-ui-§1` (fix at the single seam), `testing-§12`
  (the new case is falsifiable against the old code).
- **Test movement:** about +2 cases.

### C-03 — The parked-registration replay runs on both regen branches (F-003)

- **Files:** `core/ConsumableMaster.lua` (`KCM:OnRegenEnabled`, `:623-657`) and `tests/test_settingsui_optionsui.lua` (or
  `tests/test_disabled.lua`).
- **After:**
  ```lua
  -- SETUP, not a feature (slash-commands-§7 "What MUST survive"): a settings
  -- category refused under lockdown is registered on the next regen whether or
  -- not the addon is stood down.
  local function replayParkedSettings()
      local S = KCM.Settings
      if S and S.registerPending and S.Register then S.Register() end
  end

  function KCM:OnRegenEnabled()
      if KCM.IsStoodDown and KCM.IsStoodDown() then
          if KCM.MacroBar and KCM.MacroBar.FlushPending then KCM.MacroBar.FlushPending() end
          replayParkedSettings()
          self:UnregisterEvent("PLAYER_REGEN_ENABLED")
          return
      end
      ... -- macro flush, bar flush unchanged
      replayParkedSettings()
  end
  ```
- **Complexity.** `lizard` counts this function at CCN 15 today, the tag gate's cap (`automated-tests-§3`). The three `and`s
  leave it for the helper, so the function should read about 12 and the helper about 4. This removes decisions rather than
  relocating a body (anti-pattern #52). The next release run should confirm it.
- **Tests.** Add `Settings: a registration parked while the addon is disabled is replayed on regen` (red under the current early
  return). Keep the existing case at `:777-797` as it is. Its "red under: … moving the replay onto a second
  PLAYER_REGEN_ENABLED registration" still holds.
- **Test movement:** +1.

### C-04 — Tell the truth about the panel while disabled (F-004)

- **Files:** `core/ConsumableMaster.lua:213-218` (comment) and `docs/ARCHITECTURE.md` → `## Known Limitations` (`:331`).
- **Change.**
  - Rewrite the comment. The panel refresh still runs on a recompute, but while stood down nothing requests one, because
    `GET_ITEM_INFO_RECEIVED` and the options `PANEL_REFRESH` subscription are both stood down. Remove the dead pointer to "the
    toggle's onChange in settings/Panel.lua".
  - Add a Known Limitations bullet: rows opened while disabled can read `[Loading]` until the page is re-rendered.
- **Deferred, needs an owner decision:** panel-owned hydration through LibKa0s-Item's `LoadItem` (the member
  `core/ItemSetup.lua:14-16` declines today) while the latch is down. That is an adoption decision, and it touches an open
  evolution, so per `CLAUDE.md`'s deviation rule it is flagged, not made.
- **Test movement:** 0.

### C-05 — Standing up runs the login pass (F-007)

- **Files:** `core/ConsumableMaster.lua` (`OnPlayerEnteringWorld`, `:582-597`), `core/LifecycleSetup.lua` (`standUp`,
  `:110-119`) and `tests/test_disabled.lua`.
- **After:**
  ```lua
  -- core/ConsumableMaster.lua
  function P.DiscoverAndSweep(reason)
      runAutoDiscovery(reason)
      if KCM.Selector and KCM.Selector.SweepStaleDiscovered then
          KCM.Selector.SweepStaleDiscovered(time())
      end
  end
  function KCM:OnPlayerEnteringWorld()
      P.DiscoverAndSweep("player_entering_world")
      requestRecompute("player_entering_world")
      if KCM.MacroBar and KCM.MacroBar.Update then KCM.MacroBar.Update() end
  end
  -- core/LifecycleSetup.lua standUp, before RequestRecompute:
  if KCM.Pipeline and KCM.Pipeline.DiscoverAndSweep then KCM.Pipeline.DiscoverAndSweep("stand_up") end
  ```
- **Standards.** `performance-§6` (rebuild from current state). There is one function, called twice, and no copy.
- **Test:** add `Disabled 9c: an item looted while disabled is discovered on the way back up`. It goes red under a `standUp` that
  skips the pass.
- **Test movement:** +1.

### C-06 — `KCM.Compat.GetItemInfo` for the two hot reads (F-005)

- **Files:** `core/Compat.lua`, `modules/Ranker.lua` (`itemFields`, `:83-96`), `core/TooltipCache.lua` (`:459`) and
  `tests/test_compat.lua`.
- **After:**
  ```lua
  -- core/Compat.lua
  function Compat.GetItemInfo(itemID)
      if C_Item and C_Item.GetItemInfo then return C_Item.GetItemInfo(itemID) end
      if GetItemInfo then return GetItemInfo(itemID) end
  end
  -- modules/Ranker.lua
  local _, _, quality, ilvl = KCM.Compat.GetItemInfo(itemID)
  ... scoreCache.fields[itemID] = { quality = quality, ilvl = ilvl, tt = tt }
  return quality, ilvl, nil, tt   -- or drop the third return and update the 15 destructurings
  ```
  Prefer dropping the third return and fixing the destructurings (`local quality, ilvl, tt = …`). Leaving a permanent `nil` slot
  is a naming lie.
- **Risk.**
  - `C_Item.GetItemInfo` has the same return order as the global.
  - The mock must expose `C_Item.GetItemInfo`. Add it to `tests/wow_mock.lua` if it is missing, delegating to the existing item
    table.
  - `.luacheckrc` already lists `C_Item`.
- **Test:** `compat: GetItemInfo prefers C_Item and falls back to the global`. Test movement: +1.

### C-07 — `/cm resetall`: accurate help line, one combat guard for the act (F-008)

- **Files:** `settings/Slash.lua:231`, `core/ConsumableMaster.lua` (`KCM.ResetAllToDefaults`, `:571-580`),
  `core/SlashCommands.lua:41-61` and `settings/General.lua:107-118`.
- **Change.**
  1. The description becomes `"Reset this profile to the addon's defaults — every setting and list (asks first)"`.
  2. `KCM.ResetAllToDefaults` refuses in combat. It returns `false, "combat"` and the caller words the refusal. Both doors then
     report the same outcome.
  3. `doResetAll` drops its own guard and says the one line.
  4. `KCM_CONFIRM_RESET`'s `OnAccept` distinguishes "combat" from "DB not ready".
  5. Optionally, collapse the two identical popups into one (`KCM_RESET_ALL`) shown by both doors.
- **Standards.** `options-ui-§12` ("one act, one wording").
- **Test movement.** About +1 (a combat refusal from both doors). If the popups are collapsed, the two test references to
  `KCM_CONFIRM_RESET` / `KCM_RESET_ALL` move with them.

### C-08 — Tooltip names the tab (F-009)

- **Files:** `settings/General.lua:367`, plus `locales/enUS.lua` if the key is registered there.
- **Change:** "…use Reset all settings on the Master controls tab." Test movement: 0, unless `tests/test_locale.lua` pins the old
  key, in which case update that pin in the same commit.

### C-09 — The bare `/cm bar` toggle reads the stored flag (F-010)

- **File:** `core/SlashCommands.lua:904`.
- **After:** `local on = not (KCM.MacroBarModel.Config() or {}).enabled`.
- **Test:** `slash: bare /cm bar toggles the stored flag during a perf hold`. Test movement: +1.

### C-10 — The lock confirmation says when the bar is off (F-011)

- **Files:** `core/LauncherSetup.lua:184-187` and `core/SlashCommands.lua:869-870`. The launcher calls the same `runLock` body
  through `KCM.SlashCommands.Verbs.RunLock`, so there is one wording.
- **Change.** Keep the write, because the lock is a stored preference and writing it is legitimate. When
  `cfg.enabled == false`, say `"macro bar unlocked (the bar is off — /cm bar on to show it)"`. The launcher reuses `RunLock`
  rather than keeping its own copy of the wording.
- **Test movement:** +1.

### C-11 — One echo for `enable` and `disable` (F-012)

- **File:** `settings/General.lua:249`.
- **Change.** Drop the `KCM.Say("Master enable …")` from the row's `onChange`.
  - The verbs keep their canonical `enabled = …` echo (`slash-commands-§5`).
  - The checkbox shows its own state.
  - `/cm set enabled …` already echoes.
- **Risk:** `tests/test_locale.lua` mentions the string. Update its registry in the same commit.
- **Test movement:** 0.

### C-12 — Replace two assertions that cannot fail (F-013)

- **File:** `tests/test_disabled.lua`.
- **At `:292`:** assert `t.truthy((ran or 0) > 0, …)`. If `__fireUnconditional` can legitimately return 0 there, delete the line,
  since `:296` already carries the falsification.
- **At `:378`:** delete the line.
- **Test movement:** the case count is unchanged (assertions only).

### C-13 — Correct the stale comments (F-014, F-015)

- **Files:**
  - `modules/MacroBar.lua:175`
  - `docs/ARCHITECTURE.md:340`
  - `defaults/Profile.lua:54,107,112`
  - `core/ConsumableMaster.lua:367-404`: delete the orphaned `restoreProfileDefaults` block, keeping its one still-true sentence
    about `CopyTable` versus aliasing only if a reader of `ResetAllToDefaults` needs it.
  - `settings/Slash.lua:25,271-305`: shrink the gate essay to what is true now. The library gates the live arm, and the degraded
    arm has no gate, which is acceptable because there is no latch there either.
  - `modules/Selector.lua:5,604`
  - `ConsumableMaster.toc:50,76,81`
  - `settings/OptionsSetup.lua:159-165`
- **Standards.** anti-pattern #66: the TOC comment edits change prose only, never line order. Test movement: 0.

### C-14 — Remove the unread export (F-016)

- **File:** `settings/General.lua:383`. Delete `KCM.Settings.GENERAL_TABS = TABS`.
- **Risk:** zero readers were found by grep across `core/`, `modules/`, `settings/` and `tests/`. Test movement: 0.

### C-15 — The About logo path from `addonName` (F-017)

- **File:** `settings/Panel.lua:148`.
- **After:**
  ```lua
  local addonName = KCM.name   -- set by core/Namespace.lua:13
  local LOGO_TEXTURE = ("Interface\\AddOns\\%s\\media\\logos\\%s.logo.tga"):format(addonName, addonName:lower())
  ```
  Same derivation as `core/LauncherSetup.lua:107-108`. Test movement: 0.

---

## Standards conformance per change

| Change | Rule(s) shaping it | New deviation? | Rejected option and the rule it broke |
|---|---|---|---|
| C-01 | `events-frames-taint-§4`, `testing-§13` | No | A second macro-writing path outside `commitMacro` (`events-frames-taint-§4` firewall) |
| C-02 | `savedvariables-§2`, `options-ui-§1`, `testing-§12` | No | A metatable freeze on `dbDefaults`, which AceDB's `removeDefaults` strips |
| C-03 | `slash-commands-§7` (What MUST survive), `performance-§11`, anti-pattern #52 | No | An inline branch pushing CCN past the tag gate (`automated-tests-§3`); a second regen listener |
| C-04 | `slash-commands-§7` (Recorded, not ruled), `CLAUDE.md` deviation rule | No | Keeping `GET_ITEM_INFO_RECEIVED` live while disabled (anti-pattern #85) |
| C-05 | `performance-§6` | No | Copying PEW's body into `standUp` (two copies drift) |
| C-06 | anti-pattern #10, `compat` | No | None |
| C-07 | `options-ui-§12` | No | None |
| C-08, C-09, C-10, C-11 | `slash-commands-§5`, `launcher-§2` | No | None |
| C-12 | `testing-§12` | No | None |
| C-13 | anti-pattern #66 | No | Reordering TOC lines while editing their comments |
| C-14, C-15 | `layout-§4` (file naming, via LauncherSetup's derivation) | No | None |

---

## Regression pressure and inventory movement

- **Expected cases added:** about **+9** (C-01 ×2, C-02 ×2, C-03, C-05, C-06, C-09, C-10), plus about +1 if C-07's combat refusal
  gets its own case. That takes the suite from 998 to roughly 1007–1008. The exact count is whatever `tests/run.lua --list`
  emits.
- **`docs/test-cases.md` and the README `[Tests]` badge MUST move in the same commit as each suite change** (`testing-§5`, and
  `CLAUDE.md`'s Static badges rule). Never defer them. Regenerate with `lua5.1 tests/run.lua --list > docs/test-cases.md`.
  Never hand-edit it.
- **Complexity:** C-03 should take `KCM:OnRegenEnabled` from CCN 15 to about 12, leaving no function at the cap. C-06 removes a
  field, which is neutral. This is a note for the next release's regeneration of `docs/automated-tests/`. **Do not** run
  `lizard` into the repo as part of this work.
- **Perf:** C-02 adds one small table per color write (settings path only, not hot). C-06 removes one string field per item per
  recompute pass. The offline `recompute` scenario (2551.1 bytes/iter today) is the number to compare in the same run, before
  and after.
