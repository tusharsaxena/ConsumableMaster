-- tests/test_schema_tabs.lua — how the schema's rows lie out on a page: the
-- page -> tab -> row partition, the Master controls tab, every row's group, the
-- class-color companion and subsection headings. Split from tests/test_schema.lua
-- on 2026-10-31, which keeps what a row does; this keeps where it is drawn.
local h = _G.KCM_TEST
local test = h.test

-- ---------------------------------------------------------------------------
-- The page -> tab -> row partition
--
-- The settings panel is five pages now: four that carry a tab strip, and the
-- AceConfig-drawn Profiles page last, which carries no rows and no strip. These
-- three cases are what catch a row drifting into the wrong tab, a tab losing its
-- rows, and a category losing its tab -- none of which any other case would see,
-- because every one of them still renders something.
-- ---------------------------------------------------------------------------

test("schema: the page order lists five pages, each once, Profiles last", function(t)
    local KCM = h.loader.loadWithSchema()
    t.eqList(KCM.Settings.order, { "general", "macros", "statpriority", "macrobar", "profiles" },
        "the sidebar reads General, Macros, Stat Priority, Macro Bar, Profiles")
    local seen = {}
    for _, name in ipairs(KCM.Settings.order) do
        t.falsy(seen[name], "'" .. name .. "' appears once in the page order")
        seen[name] = true
    end
end)

test("schema: the Macros page carries one tab per category, in macroOrder", function(t)
    local KCM = h.loader.loadWithSchema()
    local seen = {}
    for _, key in ipairs(KCM.Settings.macroOrder) do
        t.falsy(seen[key], "'" .. key .. "' appears once in the tab order")
        seen[key] = true
        t.truthy(KCM.Categories.Get(key:upper()),
            "'" .. key .. "' names a real category")
    end
    for _, cat in ipairs(KCM.Categories.LIST) do
        t.truthy(seen[cat.key:lower()], cat.key .. " has a tab on the Macros page")
    end
    t.eq(#KCM.Settings.macroOrder, #KCM.Categories.LIST,
        "and the strip holds no tab that is not a category")
end)

-- The Macros strip, written out longhand: the designed tab order and the label
-- each tab shows. Derived from Categories.LIST it would agree with Categories.LIST
-- whatever that said, and the whole point of the case is that the strip a player
-- sees was DESIGNED -- basic consumables first, the two composites after the
-- categories they aggregate, the spec-aware set next, and the once-per-tier ones
-- last.
--
-- Row counts are not in the table because a category tab has no schema rows: its
-- body is a priority list, which is a collection and not a scalar. What is
-- countable is the strip, and "one tab per category, no more" is asserted by
-- "the Macros page carries one tab per category" above.
test("schema: the Macros strip is the designed run of tabs, in order", function(t)
    local KCM = h.loader.loadFullAddon()
    local want = {
        { "FOOD",       "Food"           },
        { "DRINK",      "Drink"          },
        { "HP_POT",     "Healing Potion" },
        { "MP_POT",     "Mana Potion"    },
        { "HS",         "Healthstone"    },
        { "HP_AIO",     "AIO Health"     },
        { "MP_AIO",     "AIO Mana"       },
        { "FLASK",      "Flask"          },
        { "CMBT_POT",   "Combat Potion"  },
        { "STAT_FOOD",  "Stat Food"      },
        { "WPN_ENCH",   "Weapon Enchant" },
        { "AUG_RUNE",   "Augment Rune"   },
        { "VANTUS",     "Vantus Rune"    },
        { "BLOODLUST",  "Bloodlust"      },
        { "BATTLE_REZ", "Battle Rez"     },
    }
    local tabs = KCM.Options.MacroTabs()
    t.eq(#tabs, #want, "the strip holds exactly the designed tabs")
    for i, entry in ipairs(want) do
        t.eq(tabs[i] and tabs[i].key, entry[1], "tab #" .. i .. " is " .. entry[1])
        t.eq(tabs[i] and tabs[i].label, entry[2],
            entry[1] .. " reads as '" .. entry[2] .. "'")
        t.truthy(tabs[i] and tabs[i].tooltip and tabs[i].tooltip ~= "",
            entry[1] .. " says what its tab is for")
    end
end)

-- The strip's labels are the categories' own displayName, never shortName --
-- shortName exists for the bar's 32px buttons, where "Rune" and "Brez" are all
-- that fit, and two tabs reading "Rune" and "Vantus" would say nothing about
-- which rune each meant.
test("schema: a Macros tab is labeled with the category's display name", function(t)
    local KCM = h.loader.loadFullAddon()
    for _, tab in ipairs(KCM.Options.MacroTabs()) do
        local cat = KCM.Categories.Get(tab.key)
        t.eq(tab.label, cat.displayName, tab.key .. " uses displayName")
    end
end)

-- The designed strip, tab by tab, with the row count each tab is supposed to
-- carry. The counts are the DESIGN's, written out longhand: derived from the
-- schema they would agree with the schema no matter what it said.
--
-- Buttons carries the two WHOLE-VALUE rows behind its controls (architecture-§5):
-- `macroBar.order`, which a drag on the bar writes, and `macroBar.shown`, which
-- its per-macro checkboxes write. The row engine draws neither -- a checkbox per
-- managed macro is a length no schema knows -- but both are rows.
test("schema: the Macro Bar page partitions into its designed tabs", function(t)
    local KCM = h.loader.loadFullAddon()
    local want = {
        -- General lost `Lock position` to the General page's Master controls tab
        -- (options-ui-§15); the appearance tabs gained the class-color companion
        -- beside every swatch (options-ui-§17) and Labels gained the font face, the font
        -- flags string and the font shadow the canonical font block mandates (options-ui-§16).
        -- Item 020 (CON-L04/L05/L06) folded the Visibility tab into General and moved
        -- Show tooltips and Bar opacity there: General 1 -> 6, Bar appearance 9 -> 8,
        -- Button appearance 13 -> 12, Visibility gone, still 64 rows in all.
        { "General",           6  },
        { "Layout",            8  },
        -- CM-03 (the skinning rollout) gave each of the three HUD style blocks its
        -- composed "follow the skin" companion: Bar appearance 8 -> 9, Button
        -- appearance 12 -> 13, Labels 12 -> 13.
        { "Bar appearance",    9  },
        { "Button appearance", 13 },
        { "Labels",            13 },
        { "Flyout",            16 },
        { "Buttons",           2  },
    }

    -- Partition by `group` in DECLARATION order, exactly as a tab strip does.
    local order, counts = {}, {}
    for _, row in ipairs(KCM.Settings.Schema) do
        if row.panel == "macrobar" then
            if counts[row.group] == nil then
                counts[row.group] = 0
                order[#order + 1] = row.group
            end
            counts[row.group] = counts[row.group] + 1
        end
    end

    local total = 0
    for i, entry in ipairs(want) do
        local group, n = entry[1], entry[2]
        total = total + n
        if n > 0 then
            t.eq(order[i], group, "tab #" .. i .. " is '" .. group .. "'")
            t.eq(counts[group], n, "'" .. group .. "' carries " .. n .. " rows")
        else
            t.eq(counts[group], nil,
                "'" .. group .. "' is bespoke and declares no schema row")
        end
    end
    t.eq(#order, 7, "all seven tabs are schema-backed, and none repeats")

    local rows = 0
    for _, row in ipairs(KCM.Settings.Schema) do
        if row.panel == "macrobar" then rows = rows + 1 end
    end
    t.eq(rows, total, "every Macro Bar row lands in exactly one tab")
end)

-- A group is a TAB, so its rows have to be contiguous: a row filed under a group
-- the page has already left draws that tab a second time, further down.
test("schema: no page's rows leave a group and come back to it", function(t)
    local KCM = h.loader.loadFullAddon()
    local closed, current, panel = {}, nil, nil
    for _, row in ipairs(KCM.Settings.Schema) do
        if row.panel ~= panel then
            closed, current, panel = {}, nil, row.panel
        end
        if row.group ~= current then
            t.falsy(closed[row.group],
                "row '" .. row.path .. "' reopens the '" .. tostring(row.group)
                .. "' tab, which would draw it twice")
            if current then closed[current] = true end
            current = row.group
        end
    end
end)

test("schema: the tab strips name only groups their rows declare", function(t)
    local KCM = h.loader.loadFullAddon()
    local declared = {}
    for _, row in ipairs(KCM.Settings.Schema) do
        if row.panel == "macrobar" then declared[row.group] = true end
    end
    for _, tab in ipairs(KCM.Settings.MACROBAR_TABS) do
        t.truthy(declared[tab.group], "the '" .. tab.group .. "' tab has rows behind it")
        t.truthy(tab.label and tab.label ~= "", tab.group .. " has a visible label")
        t.eq(type(tab.draw), "function", tab.group .. " knows how to draw itself")
    end
end)

-- ---------------------------------------------------------------------------
-- options-ui-§15 — the Master controls tab
-- ---------------------------------------------------------------------------
--
-- The one thing every player looks for first is in the same place, under the
-- same words, in every Ka0s addon: the General page's FIRST tab. Asserted over
-- the schema, because the schema IS the tab list — `group` is the partition key
-- and the tab label at once.

-- The canonical set (options-ui-§15) minus the two resets, which are the tab's
-- closing BUTTON PAIR rather than rows. Written out longhand and in order:
-- derived from the schema it would agree with the schema whatever that said.
--
-- `macroBar.locked` is `Lock frame`. The setting MOVED tabs and did not move
-- storage, which is the whole of "move, do not duplicate" — the Macro Bar page
-- must not also declare it, and the next case proves it does not.
--
-- `global.minimap.shown` is `Minimap button`, and it is LAST because that is the
-- canonical position: the composer emits it on the fourth line of the set, below
-- Lock frame / Debug console, as column 1 of `[Minimap button] [Test mode]`. This
-- addon declares no test mode — its preview switch is Lock frame, the
-- options-ui-§15 exemption — so the row opens a line of its own. It is the one
-- row in the block whose store is NOT the profile: launcher-§3 fixes LibDBIcon's
-- own table in db.global, and it is NOT sessionOnly either, which is what keeps
-- the global reset off it.
local MASTER_ROWS = {
    { "enabled",              "bool"   },
    { "visibility",           "string" },
    { "scale",                "number" },
    { "alpha",                "number" },
    { "macroBar.locked",      "bool"   },
    { "state.debugConsole",   "bool"   },
    { "global.minimap.shown", "bool"   },
}

-- red under: renaming the group, declaring any other general-page group ahead of
-- it, or hand-writing a row into the block out of canonical order.
test("schema: the General page opens on Master controls, carrying the canonical rows", function(t)
    local KCM = h.loader.loadFullAddon()

    local groups, seen = {}, {}
    local rows = {}
    for _, row in ipairs(KCM.Settings.Schema) do
        if row.panel == "general" then
            if not seen[row.group] then
                seen[row.group] = true
                groups[#groups + 1] = row.group
            end
            if row.group == "Master controls" then rows[#rows + 1] = row end
        end
    end

    t.eq(groups[1], "Master controls",
        "the FIRST group the General page declares is the canonical tab")
    t.eq(#rows, #MASTER_ROWS, "it holds exactly the rows this addon is entitled to")
    for i, want in ipairs(MASTER_ROWS) do
        t.eq(rows[i] and rows[i].path, want[1], "row #" .. i .. " is " .. want[1])
        t.eq(rows[i] and rows[i].type, want[2], want[1] .. " is a " .. want[2])
    end
    -- General visibility is a DROPDOWN, never a boolean: a boolean can only ever
    -- answer two of the four.
    local vis = KCM.Settings.Helpers.FindSchema("visibility")
    local values = KCM.Settings.Helpers.EnumValues(vis)
    t.truthy(type(values) == "table", "the visibility row offers a value list")
end)

-- A SESSION-ONLY ROW STILL NEEDS A DEFAULT. Three separate resets key on
-- `default ~= nil` before they will touch a row -- the global reset's session sweep
-- (core/ConsumableMaster.lua's restoreSessionRows), this page's Defaults button
-- (settings/General.lua's doResetGeneralPage) and `/cm reset` (settings/Slash.lua's
-- applyDefault) -- and OptionsCompose emits the debug-console row with no default of
-- its own, because it cannot know what a host's fresh session looks like. Declaring
-- it is the host's job and this is the case that says so.
--
-- red under: dropping `debugConsole = false` from the MasterControls spec's
-- `defaults`, or declaring a second session-only row without one.
test("schema: every session-only row declares a default, so a reset can reach it", function(t)
    local KCM = h.loader.loadFullAddon()
    local n = 0
    for _, row in ipairs(KCM.Settings.Schema) do
        if row.sessionOnly then
            n = n + 1
            t.truthy(row.default ~= nil,
                "'" .. tostring(row.path) .. "' declares a default")
        end
    end
    t.eq(n, 1, "the debug console is this addon's one session-only row")
end)

-- red under: leaving the old declaration in place anywhere it used to live.
test("schema: every moved Master controls setting is declared exactly once", function(t)
    local KCM = h.loader.loadFullAddon()
    for _, want in ipairs(MASTER_ROWS) do
        local n = 0
        for _, row in ipairs(KCM.Settings.Schema) do
            if row.path == want[1] then n = n + 1 end
        end
        t.eq(n, 1, "'" .. want[1] .. "' is declared once, on one page")
    end
end)

-- ---------------------------------------------------------------------------
-- options-ui-§13 — every row carries a group
-- ---------------------------------------------------------------------------
--
-- A page whose rows declare none cannot draw a strip: the library reports it and
-- renders the page untabbed, which is the defect rather than the shape
-- (anti-patterns #69). Three lines, and the one that catches a row added without
-- a tab to live on.
--
-- red under: dropping `group` from any row literal, or from a composer spec.
test("schema: every row on every page carries a group", function(t)
    local KCM = h.loader.loadFullAddon()
    for _, row in ipairs(KCM.Settings.Schema) do
        t.truthy(row.group and row.group ~= "",
            "row '" .. tostring(row.path) .. "' declares the tab it belongs to")
    end
end)

-- ---------------------------------------------------------------------------
-- options-ui-§17 — the class-color companion
-- ---------------------------------------------------------------------------
--
-- Every color row is followed IMMEDIATELY by its companion, which is what puts
-- the two on one line; the swatch carries `startsLine`, which is what stops an
-- odd number of widgets above them splitting the pair across two; and no color
-- row is ever disabled, because its ALPHA is still read under class color.
--
-- red under: adding a color row without its companion, adding `disabledIf` to
-- one, dropping `startsLine` from a swatch, or declaring any of this addon's
-- swatches `classColor = { source = "unit" }` — every one of them is chrome on a
-- bar the player owns, and the row's declaration is what an audit reads.
test("schema: every color row is followed by its class-color companion", function(t)
    local KCM = h.loader.loadFullAddon()
    local schema = KCM.Settings.Schema
    local colors = 0
    for i, row in ipairs(schema) do
        if row.type == "color" then
            colors = colors + 1
            local companion = schema[i + 1]
            t.truthy(companion and companion.type == "bool",
                "'" .. row.path .. "' is followed by a bool")
            t.truthy(companion and tostring(companion.path):find("useClassColor", 1, true),
                "…and that bool is its useClassColor companion")
            t.eq(companion and companion.label, "Use class color",
                "…labeled with the collection's one wording")
            t.eq(companion and companion.group, row.group, "…in the same tab")
            t.eq(companion and companion.subgroup, row.subgroup, "…under the same heading")
            t.eq(row.startsLine, true,
                "'" .. row.path .. "' opens its line so the pair cannot be split")
            -- This addon paints one bar that belongs to the player and tracks no
            -- unit, so every swatch on it is player-scoped. The declaration is
            -- what an audit reads; the path prefix decides nothing.
            t.eq(row.classColorSource, "player",
                "'" .. row.path .. "' declares whose class it means")
            t.eq(companion and companion.classColorSource, "player",
                "…and its companion agrees")
        end
        -- A COLOR row only: anti-pattern #74 is the swatch's. A media picker the
        -- skin governs is disabled by its `<key>FromSkin` companion on purpose
        -- (OptionsCompose's `fromSkin`, CM-03): while it is on, the picker is not read.
        if row.type == "color" then
            t.eq(row.disabledIf, nil,
                "color row '" .. tostring(row.path) .. "' carries no disabledIf (anti-patterns #74)")
        end
    end
    t.truthy(colors >= 7, "the addon still declares its seven swatches (" .. colors .. ")")
end)

-- ---------------------------------------------------------------------------
-- options-ui-§7 — a tab that mixes control types carries subsection headings
-- ---------------------------------------------------------------------------
--
-- The four Macro Bar tabs that merge a background block, a border block, a font
-- block and an icon block are the ones this catches. A `subgroup` MUST NOT
-- repeat its tab's name, and every row of a subgrouped tab must carry one --
-- a single unlabeled row among labeled ones is a block with no heading.
--
-- "Repeat" is checked WORD BY WORD, not on the whole string. `Bar` under
-- `Bar appearance` is a repeat -- it names the tab back at the reader instead of
-- naming the kind of control under the heading -- and a whole-string comparison
-- waved it through, which is how it shipped.
--
-- red under: dropping `subgroup` from any row of a mixed tab, or naming a
-- subgroup after any word of the tab it sits in.
test("schema: every mixed tab breaks its blocks up with subsection headings", function(t)
    local KCM = h.loader.loadFullAddon()
    local MIXED = {
        ["Layout"]            = { "Arrangement", "Size and spacing" },
        ["Bar appearance"]    = { "Background", "Border" },
        ["Button appearance"] = { "Background", "Border", "Icon" },
        ["Labels"]            = { "Text", "Position", "Font" },
        ["Flyout"]            = { "Behavior", "Placement", "Background", "Indicator" },
    }
    local function repeatsTabName(subgroup, group)
        local sub = tostring(subgroup):lower()
        for word in tostring(group):gmatch("%a+") do
            if word:lower() == sub then return true end
        end
        return false
    end
    local seenOrder, seenSet = {}, {}
    for _, row in ipairs(KCM.Settings.Schema) do
        if row.panel == "macrobar" and MIXED[row.group] then
            t.truthy(row.subgroup and row.subgroup ~= "",
                "row '" .. row.path .. "' sits under a heading")
            t.falsy(repeatsTabName(row.subgroup, row.group),
                "'" .. tostring(row.subgroup) .. "' does not repeat a word of its tab's name")
            local key = row.group .. "/" .. tostring(row.subgroup)
            if not seenSet[key] then
                seenSet[key] = true
                seenOrder[row.group] = seenOrder[row.group] or {}
                local list = seenOrder[row.group]
                list[#list + 1] = row.subgroup
            end
        end
    end
    for group, want in pairs(MIXED) do
        t.eqList(seenOrder[group] or {}, want,
            "'" .. group .. "' declares its headings once each, in order")
    end
end)
