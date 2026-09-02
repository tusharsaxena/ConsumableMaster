-- core/MacroBarModel.lua — pure slot bookkeeping for the macro bar.
--
-- Owns the answer to "which KCM macros are on the bar, in what order" without
-- touching a single frame. modules/MacroBar.lua renders whatever this returns;
-- settings/MacroBar.lua and `/cm bar` mutate through it. Keeping it pure means
-- reorder / prune / drift-repair logic is unit-tested headlessly.
--
-- The bar is CM-only by construction: slot identity is a category KEY, never an
-- arbitrary macro or item, so nothing outside KCM.Categories.LIST can ever
-- occupy a slot. NormalizeOrder is the repair seam — a saved order from an
-- older version (or one hand-edited in SavedVariables) gets unknown keys
-- dropped and newly-shipped categories appended rather than silently ignored.

local _, NS = ...
local KCM = NS
KCM.MacroBarModel = KCM.MacroBarModel or {}
local BM = KCM.MacroBarModel

-- Every category key in Categories.LIST order. The bar's *default* order is
-- the cosmetic panel order (dbDefaults.profile.macroBar.order); this is the
-- fallback used to append keys the saved order has never seen.
function BM.AllKeys()
    local out = {}
    local list = KCM.Categories and KCM.Categories.LIST or {}
    for i, row in ipairs(list) do out[i] = row.key end
    return out
end

-- Repair a saved order in place-safe fashion: drop unknown / duplicate keys,
-- append any known key that's missing (in `allKeys` order). Returns the new
-- array plus a `changed` flag so callers can skip a pointless DB write.
function BM.NormalizeOrder(order, allKeys)
    allKeys = allKeys or BM.AllKeys()
    local known = {}
    for _, k in ipairs(allKeys) do known[k] = true end

    local out, seen, changed = {}, {}, false
    for _, k in ipairs(order or {}) do
        if known[k] and not seen[k] then
            seen[k] = true
            out[#out + 1] = k
        else
            changed = true      -- unknown key or duplicate — dropped
        end
    end
    for _, k in ipairs(allKeys) do
        if not seen[k] then
            seen[k] = true
            out[#out + 1] = k
            changed = true      -- category shipped after this order was saved
        end
    end
    return out, changed
end

-- ---------------------------------------------------------------------------
-- Visibility: the addon-wide master setting INTERSECTED with the bar's own
-- ---------------------------------------------------------------------------
--
-- Two combat-conditional settings govern whether the bar is on screen, and they
-- are different settings: `db.profile.visibility` is options-ui-§15's addon-wide
-- General visibility, `macroBar.combatMode` is this one instance's Combat
-- visibility. Applying one and ignoring the other is what makes a control look
-- broken, so they are INTERSECTED -- the bar shows only where both say show.
--
-- Answers what to hand Blizzard's secure visibility driver, or the literal
-- "show" / "hide" where the answer does not depend on combat at all. A driver
-- string rather than a Show()/Hide() decision wherever combat is involved,
-- because only the secure manager can flip it mid-fight.
--
-- Pure, and here rather than in modules/MacroBar.lua, because the intersection
-- is a truth table and a truth table is exactly what a headless suite can pin.
local MASTER_IN_COMBAT  = { inCombat = true }
local MASTER_OUT_COMBAT = { outOfCombat = true }

function BM.ResolveVisibility(master, combatMode)
    if master == "never" then return "hide" end

    local masterIn  = MASTER_IN_COMBAT[master or "always"] or false
    local masterOut = MASTER_OUT_COMBAT[master or "always"] or false
    -- What the bar's own mode says about each half of the fight.
    local barIn  = combatMode ~= "HIDE_IN_COMBAT"
    local barOut = combatMode ~= "ONLY_IN_COMBAT"

    local showIn  = barIn  and not masterOut
    local showOut = barOut and not masterIn

    if showIn and showOut then return "show" end
    if showIn then return "[combat] show; hide" end
    if showOut then return "[combat] hide; show" end
    return "hide"
end

-- Index of `key` in `order`, or nil.
function BM.IndexOf(order, key)
    for i, k in ipairs(order or {}) do
        if k == key then return i end
    end
    return nil
end

-- Swap two slots by category key — the drag-and-drop reorder primitive.
-- Mutates `order` and returns true, or returns false if either key is absent
-- (or both name the same slot, which is a no-op the caller can skip).
function BM.Swap(order, a, b)
    if not (order and a and b) or a == b then return false end
    local ia, ib = BM.IndexOf(order, a), BM.IndexOf(order, b)
    if not (ia and ib) then return false end
    order[ia], order[ib] = order[ib], order[ia]
    return true
end

-- The ordered keys the bar actually renders. `shown[key] == false` hides a
-- slot; an unset key defaults to visible so a category shipped after the
-- profile was written shows up rather than vanishing.
function BM.VisibleKeys(order, shown)
    shown = shown or {}
    local out = {}
    for _, k in ipairs(order or {}) do
        if shown[k] ~= false then out[#out + 1] = k end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- db-backed convenience wrappers. Everything above is data-in/data-out; these
-- three read (and repair) db.profile.macroBar so the UI layers don't each
-- reimplement the nil ladder.
-- ---------------------------------------------------------------------------

function BM.Config()
    return KCM.db and KCM.db.profile and KCM.db.profile.macroBar or nil
end

function BM.IsEnabled()
    local cfg = BM.Config()
    return (cfg and cfg.enabled) and true or false
end

-- Saved order, repaired against the shipped category list. Writes the repaired
-- array back only when NormalizeOrder actually changed something.
function BM.Order()
    local cfg = BM.Config()
    if not cfg then return {} end
    local order, changed = BM.NormalizeOrder(cfg.order)
    if changed then cfg.order = order end
    return order
end

function BM.Visible()
    local cfg = BM.Config()
    if not cfg then return {} end
    return BM.VisibleKeys(BM.Order(), cfg.shown)
end

-- Macro name for a slot, e.g. "FOOD" -> "KCM_FOOD". Returns nil for a key that
-- isn't a shipped category.
function BM.MacroName(catKey)
    local cat = KCM.Categories and KCM.Categories.Get and KCM.Categories.Get(catKey)
    return cat and cat.macroName or nil
end

-- Both label forms for a slot: the full display name and the abbreviation used
-- when the full one won't fit a button. `shortName` is optional metadata in
-- defaults/Categories.lua and falls back to the display name.
function BM.Labels(catKey)
    local cat = KCM.Categories and KCM.Categories.Get and KCM.Categories.Get(catKey)
    if not cat then return catKey or "", catKey or "" end
    local full = cat.displayName or cat.key
    return full, cat.shortName or full
end

-- Reverse lookup used by the drag-drop handler: a macro name off the cursor
-- back to the category key that owns it, or nil if it isn't a KCM macro.
function BM.KeyForMacroName(macroName)
    if not macroName then return nil end
    local list = KCM.Categories and KCM.Categories.LIST or {}
    for _, row in ipairs(list) do
        if row.macroName == macroName then return row.key end
    end
    return nil
end
