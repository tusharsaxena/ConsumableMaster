# Scope

What's in scope, what's out, and the resolved decisions that shaped the contract. The contract itself (macro behavior, slash UX, settings panel) is documented in [README.md](../README.md) — this doc records the *boundary* decisions so a fresh contributor can tell whether a feature request is in or out of scope without re-litigating it.

## In scope

- **Account-wide consumable macros** — thirteen single-pick categories (FOOD, DRINK, HP_POT, MP_POT, HS, VANTUS, FLASK, CMBT_POT, STAT_FOOD, WPN_ENCH, AUG_RUNE, BLOODLUST, BATTLE_REZ) plus two combat-conditional composites (HP_AIO, MP_AIO). Identified by name, never by slot.
- **Auto-rewriting macro bodies** based on bag contents, spec, and a per-category scorer.
- **Spec-aware ranking** for FLASK / CMBT_POT / STAT_FOOD / WPN_ENCH against per-spec stat priority (primary + ordered secondary).
- **Spell entries** (e.g. Recuperate as a Food entry) via opaque-numeric IDs (positive = item, negative = spell sentinel).
- **Settings panel** integrated into Blizzard's AddOns settings + matching `/cm` slash CLI for every panel-shaped operation.
- **Auto-discovery** from bag scans, bounded by a 30-day stale-discovered sweep.
- **Combat-deferred writes** with bounded retry on flush.
- **A CM-only macro bar** (on and unlocked by default, switchable off) holding the managed macros as secure buttons, with configurable layout / geometry / chrome / labels / visibility, drag-to-swap reordering, and a per-slot hover flyout listing every currently-usable candidate in that category. Deliberately narrow: it hosts *only* `KCM_*` macros — it is not a general-purpose action-bar replacement, and it will not accept arbitrary items, spells or foreign macros. See [macro-bar.md](./macro-bar.md).

## Out of scope

These have been considered and explicitly declined. A change of heart needs an issue + design discussion, not a stealth PR.

- **Localization — tracked deviation from the standard.** English-only, and this is a **documented, intentional deviation** from the Ka0s Standard's `localization-§4` (anti-pattern **#37**: don't match localized game data against English text). A standards audit *should* flag it — that is expected, not an oversight. The **ratified record is the register row** in [ARCHITECTURE.md → Documented deviations](./ARCHITECTURE.md#documented-deviations), which carries the rule, the date and the re-check trigger; what follows here is the reasoning behind it. The deviation's scope is now narrow: **`core/TooltipCache.lua` tooltip-TEXT parsing** — heal/mana/stat magnitudes, the `Augment Rune` marker, and the weapon-application effect are read from English tooltip strings, and there is no stable-ID substitute for parsing a numeric magnitude out of free text. Item and weapon **classification** was moved *off* the localized subType display string onto the locale-independent numeric `classID`/`subClassID` (`core/Classifier.lua`, `core/WeaponSlots.lua`), so category and weapon-affinity detection already work on every client. Localizing the remaining tooltip-text parsing is planned for a later release.
- **Per-character macros.** Everything is account-wide. Per-character profiles aren't needed for the addon's purpose; AceDB is configured with a single account-wide profile by default.
- **Per-encounter / per-boss priorities.** No fight-specific lists.
- **Auto-buying consumables from vendors.** No vendor automation.
- **Cauldrons / phials** as separate categories. Phials are absorbed into FLASK by subclass (Flask/Phial, subClassID 3). Cauldrons don't have a managed macro. Weapon oils and whetstones are the WPN_ENCH category, and augment runes are the AUG_RUNE category — both matched by tooltip effect rather than by item class.
- **Bandages.** First aid is a separate workflow; not relevant to current Midnight endgame.
- **Profile import/export.** Settings live in `ConsumableMasterDB` per-account; no serialization layer.
- **LDB / minimap icon.**
- **A general-purpose action bar.** The macro bar hosts `KCM_*` macros only. Paging, stances, arbitrary items/spells/macros, and per-button keybindings are Bartender/ElvUI territory (keybindings are tracked as a possible narrow exception).
- **Drag-and-drop reordering** of priority list rows. The ↑ / ↓ buttons are simpler and match the rest of the panel's keyboard-and-mouse interaction model.
- **Shopping-list / restock reminders.**
- **Feasts** in `STAT_FOOD`. Personal feasts and ground feasts are excluded from the seed; users wanting a feast macro can add the item ID manually.
- **Utility potions** in `CMBT_POT`. Invisibility, slow fall, swiftness, absorb potions are not throughput buffs and don't belong in the combat-pot macro.

## Resolved decisions

Decisions made during requirements review and v1.0.0 launch — these are settled, not open.

- **Spec key shape.** `<classID>_<specID>` numeric pair. UI displays human-readable names (e.g. "Shaman — Enhancement"); persistence uses the numeric form so it's locale-independent.
- **AceDB profile model.** Single account-wide profile. No profile switcher.
- **Macro adoption.** If a `KCM_*`-named macro pre-exists when the addon first runs, the addon adopts it (rewrites the body on next event). The addon never renames user macros and never calls `DeleteMacro` on a `KCM_*` slot.
- **Reset confirmation.** Blizzard `StaticPopupDialogs` yes/no popup, registered with `preferredIndex = 3` to dodge the popup-slot taint cascade that affects slots 1 / 2 when other addons have used them earlier in the session.
- **Conjured / vendor food handling.** The candidate set is built dynamically via the classifier (item subclass + tooltip) and ordered by the ranker (parsed heal/mana, ilvl, quality, conjured bonus). Defaults ship a known-good seed; auto-discovery handles new items. No static "small seed list" approach.
- **Cyan `[CM]` chat prefix.** `KCM.PREFIX` (`core/Constants.lua`) is the single source of truth for the cyan `|cff00ffff[CM]|r` tag; all one-shot chat routes through the shared secret-safe `KCM.Say` seam (`core/SlashCommands.lua`'s `say` is just `local say = KCM.Say`). Raw `print(...)` calls are banned outside that seam — the only sanctioned `print` is inside generated macro-body `/run print(...)` strings.
- **Debug-console font — Blizzard-default styling everywhere except the mandated debug font (compliant).** Every user-facing surface in the addon (settings panel, all `KCM*` AceGUI widgets) uses stock Blizzard font objects, stock `Interface\...` textures/atlases, and Blizzard border textures — no custom media. The **one** intentional exception is the on-screen debug console (`core/DebugLogSetup.lua`): its `ScrollingMessageFrame` and Copy box default to **JetBrains Mono**, which now arrives inside the vendored LibKa0s payload (`libs/LibKa0s/media/fonts/JetBrainsMono-Regular.ttf`) rather than in a copy of its own under `media/fonts/`. The window is drawn by `LibKa0s-DebugLog-1.0` and the face and its LibSharedMedia registration are the library's too: `core/MediaSetup.lua` tells the library this addon's folder name, `core/DebugLogSetup.lua` asks it for the path and hands that to the console, and the fallback rung stays here — Blizzard's own `Fonts\ARIALN.TTF`, a **real client font**, because `SetFont` on a path to a file that is not there draws nothing and raises nothing. The same payload carries the shared icon catalog, which is where the macro bar's help mark and the console's copy / clear / close marks come from; this addon draws no art of its own beyond `media/logos/`. **This is compliance, not a deviation.** The Ka0s Standard's `debug-logging-§2` *requires* a shipped monospace font for the debug console and names **JetBrains Mono (Regular, OFL)** as the reference font, and its "Sanctioned styling exception" bullet states a standards audit **MUST NOT** flag the shipped console font (nor the addon logo, `options-ui-§6` / `layout-§3`) as non-Blizzard "shipped art." The rationale the standard bakes in: the console is a **developer-facing diagnostic** where a fixed-width font is a hard readability requirement (aligned `<HH:MM:SS> | [tag] …` columns) and Blizzard ships no monospace font object. The font is **not** user-configurable and there is intentionally **no** in-addon LSM picker — the LSM registration merely exposes it to other addons; the addon pins it by name (also standard-sanctioned). Everything else stays Blizzard-default; a *new* custom-media surface beyond these two sanctioned assets would still need flagging under the [../CLAUDE.md](../CLAUDE.md) deviation rule.

## Where the contract lives

- User-facing behavior: [README.md](../README.md) — macro categories, slash commands, FAQ, troubleshooting.
- Module map, invariants, LibKa0s adoption, repository/environment notes: [ARCHITECTURE.md](./ARCHITECTURE.md). The root [../CLAUDE.md](../CLAUDE.md) is a stub carrying the standards-compliance rule and the hard rules, and points here.
