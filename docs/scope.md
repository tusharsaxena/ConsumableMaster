# Scope

What's in scope, what's out, and the resolved decisions that shaped the contract. The contract itself (macro behavior, slash UX, settings panel) is documented in [README.md](../README.md) — this doc records the *boundary* decisions so a fresh contributor can tell whether a feature request is in or out of scope without re-litigating it.

## In scope

- **Account-wide consumable macros** — eleven single-pick categories (FOOD, DRINK, HP_POT, MP_POT, HS, VANTUS, FLASK, CMBT_POT, STAT_FOOD, WPN_ENCH, AUG_RUNE) plus two combat-conditional composites (HP_AIO, MP_AIO). Identified by name, never by slot.
- **Auto-rewriting macro bodies** based on bag contents, spec, and a per-category scorer.
- **Spec-aware ranking** for FLASK / CMBT_POT / STAT_FOOD / WPN_ENCH against per-spec stat priority (primary + ordered secondary).
- **Spell entries** (e.g. Recuperate as a Food entry) via opaque-numeric IDs (positive = item, negative = spell sentinel).
- **Settings panel** integrated into Blizzard's AddOns settings + matching `/cm` slash CLI for every panel-shaped operation.
- **Auto-discovery** from bag scans, bounded by a 30-day stale-discovered sweep.
- **Combat-deferred writes** with bounded retry on flush.

## Out of scope

These have been considered and explicitly declined. A change of heart needs an issue + design discussion, not a stealth PR.

- **Localization — tracked deviation from the standard.** English-only, and this is a **documented, intentional deviation** from the Ka0s Standard's `localization-§4` (anti-pattern **#37**: don't match localized game data against English text). A standards audit *should* flag it — that is expected and recorded here, not an oversight. The deviation's scope is now narrow: **`core/TooltipCache.lua` tooltip-TEXT parsing** — heal/mana/stat magnitudes, the `Augment Rune` marker, and the weapon-application effect are read from English tooltip strings, and there is no stable-ID substitute for parsing a numeric magnitude out of free text. Item and weapon **classification** was moved *off* the localized subType display string onto the locale-independent numeric `classID`/`subClassID` (`core/Classifier.lua`, `core/WeaponSlots.lua`), so category and weapon-affinity detection already work on every client. Localizing the remaining tooltip-text parsing is planned for a later release.
- **Per-character macros.** Everything is account-wide. Per-character profiles aren't needed for the addon's purpose; AceDB is configured with a single account-wide profile by default.
- **Per-encounter / per-boss priorities.** No fight-specific lists.
- **Auto-buying consumables from vendors.** No vendor automation.
- **Cauldrons / phials** as separate categories. Phials are absorbed into FLASK by subclass (Flask/Phial, subClassID 3). Cauldrons don't have a managed macro. Weapon oils and whetstones are the WPN_ENCH category, and augment runes are the AUG_RUNE category — both matched by tooltip effect rather than by item class.
- **Bandages.** First aid is a separate workflow; not relevant to current Midnight endgame.
- **Profile import/export.** Settings live in `ConsumableMasterDB` per-account; no serialization layer.
- **LDB / minimap icon.**
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
- **Debug-console font — Blizzard-default styling everywhere except the mandated debug font (compliant).** Every user-facing surface in the addon (settings panel, all `KCM*` AceGUI widgets) uses stock Blizzard font objects, stock `Interface\...` textures/atlases, and Blizzard border textures — no custom media. The **one** intentional exception is the on-screen debug console (`modules/DebugLog.lua`): its `ScrollingMessageFrame` and Copy box default to the **bundled JetBrains Mono** (`media/fonts/JetBrainsMono-Regular.ttf`, registered through LibSharedMedia, with the Blizzard `Fonts\ARIALN.TTF` as fetch-failure fallback). **This is compliance, not a deviation.** The Ka0s Standard's `debug-logging-§2` *requires* a shipped monospace font for the debug console and names **JetBrains Mono (Regular, OFL)** as the reference font, and its "Sanctioned styling exception" bullet states a standards audit **MUST NOT** flag the shipped console font (nor the addon logo, `options-ui-§6` / `layout-§3`) as non-Blizzard "shipped art." The rationale the standard bakes in: the console is a **developer-facing diagnostic** where a fixed-width font is a hard readability requirement (aligned `<HH:MM:SS> | [tag] …` columns) and Blizzard ships no monospace font object. The font is **not** user-configurable and there is intentionally **no** in-addon LSM picker — the LSM registration merely exposes it to other addons; the addon pins it by name (also standard-sanctioned). Everything else stays Blizzard-default; a *new* custom-media surface beyond these two sanctioned assets would still need flagging under the [../CLAUDE.md](../CLAUDE.md) deviation rule.

## Where the contract lives

- User-facing behavior: [README.md](../README.md) — macro categories, slash commands, FAQ, troubleshooting.
- Engineer working notes: [agent-context.md](./agent-context.md) — hard rules, response style, working environment (the root [../CLAUDE.md](../CLAUDE.md) is a stub that points here).
- Module map + invariants: [ARCHITECTURE.md](./ARCHITECTURE.md).
