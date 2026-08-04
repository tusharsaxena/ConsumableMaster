-- SlashDump.lua — the `/cm dump <target>` diagnostics namespace.
--
-- Peeled out of core/SlashCommands.lua for CM-54: that file was 1408 LOC, and
-- this block is the largest self-contained thing in it. It uses none of the
-- slash parsing helpers — only KCM.Say and the addon's own state — so it lifts
-- whole, and it loads BEFORE SlashCommands.lua because that is the dependency
-- direction: the priority verb reads the `pick` target, never the reverse.
--
-- Adding a dump target is still one DUMP_TARGETS entry plus one DUMP_ORDER
-- name; both help surfaces render from those two tables.

local _, NS = ...
local KCM = NS

-- Same secret-safe seam as every other chat line (core/Constants.lua).
local say = KCM.Say

-- ---------------------------------------------------------------------------
-- Dump targets: single source of truth. Each entry has a one-line summary
-- (shown in help) and a handler. Add new dump targets here and they appear
-- in both `/cm` and `/cm dump` help output automatically.
-- ---------------------------------------------------------------------------

local DUMP_TARGETS = {}

DUMP_TARGETS.categories = {
    summary = "category metadata table",
    run = function()
        if not (KCM.Categories and KCM.Categories.LIST) then
            say("KCM.Categories.LIST not loaded.")
            return
        end
        if DevTools_Dump then
            DevTools_Dump(KCM.Categories.LIST)
        else
            for i, row in ipairs(KCM.Categories.LIST) do
                say(("  [%d] %s  macro=%s  display=%q  specAware=%s")
                    :format(i, row.key, row.macroName, row.displayName, tostring(row.specAware)))
            end
        end
    end,
}

DUMP_TARGETS.statpriority = {
    summary = "stat priority for current spec",
    run = function()
        if not (KCM.SpecHelper and KCM.SpecHelper.GetCurrent) then
            say("KCM.SpecHelper not loaded.")
            return
        end
        local classID, specID, specKey, specName = KCM.SpecHelper.GetCurrent()
        if not specKey then
            say("No active spec (low-level character?).")
            return
        end
        local priority = KCM.SpecHelper.GetStatPriority(specKey)
        say(("spec: %s  (classID=%s  specID=%s  key=%s)")
            :format(specName or "?", tostring(classID), tostring(specID), specKey))
        if DevTools_Dump then
            DevTools_Dump(priority)
        else
            say(("  primary: %s"):format(tostring(priority.primary)))
            say(("  secondary: %s"):format(table.concat(priority.secondary or {}, ", ")))
        end
    end,
}

DUMP_TARGETS.bags = {
    summary = "bag contents as itemID -> count",
    run = function()
        if not (KCM.BagScanner and KCM.BagScanner.Scan) then
            say("KCM.BagScanner not loaded.")
            return
        end
        local counts = KCM.BagScanner.Scan()
        if DevTools_Dump then
            DevTools_Dump(counts)
        else
            for id, n in pairs(counts) do
                say(("  %d x %d"):format(id, n))
            end
        end
    end,
}

DUMP_TARGETS.item = {
    summary = "parsed tooltip + raw lines for <itemID> (e.g. /cm dump item 241304)",
    usage   = "item <itemID>",
    run = function(arg)
        local id = tonumber(arg or "")
        if not id then
            say("usage: /cm dump item <itemID>")
            return
        end
        if not (KCM.TooltipCache and KCM.TooltipCache.Get) then
            say("KCM.TooltipCache not loaded.")
            return
        end
        local entry = KCM.TooltipCache.Get(id)
        local name = (entry and entry.itemName)
            or (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id))
            or "?"
        say(("item %d  (%s)"):format(id, tostring(name)))

        if C_Item and C_Item.GetItemInfoInstant then
            local _, iType, iSubType, _, _, iClass, iSub = C_Item.GetItemInfoInstant(id)
            say(("  instant: type=%q  subType=%q  classID=%s  subClassID=%s")
                :format(tostring(iType), tostring(iSubType),
                        tostring(iClass), tostring(iSub)))
            local hits = KCM.Classifier and KCM.Classifier.MatchAny
                and KCM.Classifier.MatchAny(id) or {}
            if #hits > 0 then
                say(("  classified: %s"):format(table.concat(hits, ", ")))
            else
                say("  classified: |cffff4444(none)|r")
            end
        end

        if entry and entry.pending then
            say("  pending: tooltip data not yet loaded — try again in a moment.")
        elseif entry then
            local ok, reason = KCM.TooltipCache.IsUsableByPlayer(id)
            local playerLvl = UnitLevel("player") or 0
            if ok then
                say(("  usable: yes  (minLevel=%d, you=%d)"):format(entry.minLevel or 0, playerLvl))
            else
                say(("  usable: no   (%s)"):format(tostring(reason)))
            end
        end
        if DevTools_Dump then
            DevTools_Dump(entry)
        end

        if C_TooltipInfo and C_TooltipInfo.GetItemByID then
            local data = C_TooltipInfo.GetItemByID(id)
            if data and data.lines and #data.lines > 0 then
                say(("  raw tooltip lines (%d)"):format(#data.lines))
                for i, line in ipairs(data.lines) do
                    local left = line.leftText or ""
                    local right = line.rightText or ""
                    if right ~= "" then
                        say(("    [%2d] L=%q  R=%q"):format(i, left, right))
                    else
                        say(("    [%2d] %q"):format(i, left))
                    end
                end
            end
        end
    end,
}

DUMP_TARGETS.pick = {
    summary = "effective priority (with scores) + best-owned pick for a category",
    usage   = "pick <catKey>",
    run = function(arg)
        arg = (arg or ""):match("^(%S*)") or ""
        if arg == "" then
            say("usage: /cm dump pick <catKey>  (e.g. flask, hp_pot, stat_food)")
            if KCM.Categories and KCM.Categories.LIST then
                local keys = {}
                for _, cat in ipairs(KCM.Categories.LIST) do
                    table.insert(keys, cat.key:lower())
                end
                say("  known: " .. table.concat(keys, ", "))
            end
            return
        end
        local catKey = arg:upper()
        local cat = KCM.Categories and KCM.Categories.Get and KCM.Categories.Get(catKey)
        if not cat then
            say("unknown category: |cffffff00" .. arg .. "|r")
            return
        end
        if not (KCM.Selector and KCM.Selector.GetEffectivePriority) then
            say("KCM.Selector not loaded.")
            return
        end

        if cat.composite then
            say(("%s (composite)"):format(catKey))
            local cfg = KCM.db and KCM.db.profile and KCM.db.profile.categories
                and KCM.db.profile.categories[cat.key]
            if not cfg then
                say("no DB bucket for composite category.")
                return
            end
            local function describePick(refKey)
                local pick = KCM.Selector.PickBestForCategory(refKey)
                if not pick then return "(no pick)" end
                if KCM.ID and KCM.ID.IsSpell(pick) then
                    local sid = KCM.ID.SpellID(pick)
                    local name = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(sid)) or "?"
                    return ("spell:%d %s"):format(sid or 0, name)
                end
                local tt = KCM.TooltipCache and KCM.TooltipCache.Get(pick)
                local name = (tt and tt.itemName)
                    or (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(pick))
                    or "?"
                return ("%d %s"):format(pick, name)
            end
            local sections = {
                { label = "In Combat",     orderField = "orderInCombat"    },
                { label = "Out of Combat", orderField = "orderOutOfCombat" },
            }
            for _, section in ipairs(sections) do
                say(("  %s"):format(section.label))
                local arr = cfg[section.orderField] or {}
                if #arr == 0 then
                    say("    (none)")
                else
                    for i, ref in ipairs(arr) do
                        local enabled = not (cfg.enabled and cfg.enabled[ref] == false)
                        local tag = enabled and "|cff44ff44[on]|r " or "|cff888888[off]|r"
                        say(("    %d. %s %s -> %s"):format(i, tag, ref, describePick(ref)))
                    end
                end
            end
            if KCM.MacroManager and KCM.MacroManager.BuildCompositeBody then
                local body = KCM.MacroManager.BuildCompositeBody(cat,
                    function(refKey) return KCM.Selector.PickBestForCategory(refKey) end)
                if body then
                    say("  macro body")
                    for line in body:gmatch("[^\n]+") do
                        say("    " .. line)
                    end
                else
                    say("no usable picks — macro would show empty-state stub.")
                end
            end
            return
        end

        local ctx
        if cat.specAware and KCM.SpecHelper then
            local _, _, specKey, specName = KCM.SpecHelper.GetCurrent()
            if specKey then
                ctx = { specPriority = KCM.SpecHelper.GetStatPriority(specKey) }
                say(("%s for spec %s (%s)"):format(catKey, specName or "?", specKey))
                say(("  primary=%s  secondary=%s"):format(
                    tostring(ctx.specPriority.primary),
                    table.concat(ctx.specPriority.secondary or {}, ">")))
            else
                say(("%s (no active spec)"):format(catKey))
            end
        else
            say(("%s"):format(catKey))
        end

        local priority = KCM.Selector.GetEffectivePriority(catKey)
        local pick = KCM.Selector.PickBestForCategory(catKey)
        if KCM.Ranker and KCM.Ranker.BuildContext then
            ctx = KCM.Ranker.BuildContext(catKey, priority, ctx)
        end

        say(("  effective priority (%d entries)"):format(#priority))
        for i, id in ipairs(priority) do
            local name, did, have
            if KCM.ID and KCM.ID.IsSpell(id) then
                local sid = KCM.ID.SpellID(id)
                did = ("spell:%d"):format(sid or 0)
                if C_Spell and C_Spell.GetSpellName then
                    name = C_Spell.GetSpellName(sid)
                end
                name = name or "?"
                have = sid and IsPlayerSpell and IsPlayerSpell(sid) or false
            else
                did = tostring(id)
                local tt = KCM.TooltipCache and KCM.TooltipCache.Get(id)
                name = (tt and tt.itemName)
                    or (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id))
                    or "?"
                have = KCM.BagScanner and KCM.BagScanner.HasItem and KCM.BagScanner.HasItem(id) or false
            end
            local score = (KCM.Ranker and KCM.Ranker.Score and KCM.Ranker.Score(catKey, id, ctx)) or 0
            local haveTag = have and "|cff44ff44[owned]|r" or "|cff888888[---]|r"
            local pickTag = (id == pick) and "  |cffffd100<-- pick|r" or ""
            say(("  %2d. %s %8.1f  %s  %s%s"):format(i, haveTag, score, did, name, pickTag))
        end
        if not pick then
            say("no owned item — macro would show empty-state stub.")
        end
    end,
}

-- Ordered keys so help output is stable. Add new dump names here in the
-- order you want them shown.
local DUMP_ORDER = { "categories", "statpriority", "bags", "item", "pick" }

local function printDumpLines(prefix)
    for _, name in ipairs(DUMP_ORDER) do
        local target = DUMP_TARGETS[name]
        if target then
            local label = target.usage or name
            say(("  |cffffff00%s%s|r%s |cffffffff%s|r")
                :format(prefix, label, string.rep(" ", math.max(1, 18 - #label)), target.summary))
        end
    end
end

local function dumpHelp()
    say("dump targets")
    printDumpLines("/cm dump ")
end

local function dumpDispatch(rest)
    rest = rest or ""
    local head, tail = rest:match("^(%S*)%s*(.-)$")
    head = (head or ""):lower()
    if head == "" then
        dumpHelp()
        return
    end
    -- Shortcut: `/cm dump <itemID>` routes to the `item` target.
    if tonumber(head) then
        DUMP_TARGETS.item.run(head)
        return
    end
    local target = DUMP_TARGETS[head]
    if target then
        target.run(tail)
        return
    end
    say("Unknown dump target: |cffffff00" .. head .. "|r")
    dumpHelp()
end

-- Published for core/SlashCommands.lua (whose `priority` verb renders composite
-- categories through the `pick` target) and for settings/Slash.lua, which wires
-- Dispatch in as the `dump` verb.
KCM.SlashDump = {
    Dispatch = dumpDispatch,
    Help     = dumpHelp,
    TARGETS  = DUMP_TARGETS,
}
