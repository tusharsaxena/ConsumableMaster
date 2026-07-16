-- tests/wow_mock.lua — a headless stand-in for the WoW client environment.
--
-- Installs into _G the globals the addon reads at load and call time: LibStub
-- (with Ace3 stubs), the C_* namespaces, legacy item/spell/spec globals, a
-- permissive CreateFrame, and helpers (CopyTable/wipe/strtrim/...). It also
-- exposes a controllable item / bag / spell / spec store so the pure layer can
-- be exercised deterministically.
--
-- Item-injection API (used by test suites):
--   M.setItem(id, { name=, subType=, quality=, ilvl=, tt={...} })
--       subType matches Classifier's English strings: "Potions",
--       "Food & Drink", "Flasks & Phials". tt is the parsed-tooltip table
--       Classifier/Ranker consume (healValue, healPct, manaValue, hasStatBuff,
--       isFeast, buffDurationSec, statBuffs={ {stat=,amount=} }, isConjured, …).
--   M.setBag(id, count)        -- owned count (drives BagScanner + GetItemCount)
--   M.setSpell(id, { name=, known= })
--   M.setSpec(classID, specIndex, specID, specName)  -- current player spec
--   M.setCombat(bool)          -- InCombatLockdown() return
--   M.setEquipped(slot, itemID) -- equip an item into a paperdoll slot (16 main
--       hand / 17 off hand); drives GetInventoryItemID for WeaponSlots
--
-- The message bus stub is keyed by (message, target) per the standard's
-- anti-pattern #33 so future NS.bus receivers are testable.

local M = {}

-- ---------------------------------------------------------------------------
-- Controllable stores
-- ---------------------------------------------------------------------------

M.items    = {}
M.bags     = {}   -- id -> count
M.bagSlots = {}   -- ordered { {itemID, stackCount} } for C_Container walking
M.spells   = {}   -- id -> { name, known }
M.spec     = { classID = 7, specIndex = 1, specID = 263, specName = "Enhancement" }
M.inCombat = false
M.output   = {}   -- captured print() lines
M.equipped = {}   -- slot -> itemID (main-hand 16 / off-hand 17)

function M.reset()
    M.items, M.bags, M.bagSlots, M.spells = {}, {}, {}, {}
    M.spec     = { classID = 7, specIndex = 1, specID = 263, specName = "Enhancement" }
    M.inCombat = false
    M.output   = {}
    M.equipped = {}
    M.macros   = {}       -- name -> { icon, body }
    M.busReg   = {}       -- "message" -> { [target] = callback }
end

function M.setItem(id, spec)
    spec = spec or {}
    M.items[id] = {
        name        = spec.name or ("Item " .. tostring(id)),
        subType     = spec.subType or "",
        quality     = spec.quality or 1,
        ilvl        = spec.ilvl or 1,
        tt          = spec.tt or {},
        -- classID/subClassID for GetItemInfoInstant. Default 0 (Consumable) to
        -- preserve existing tests; set explicitly to model armor/weapons/etc.
        classID     = spec.classID or 0,
        subClassID  = spec.subClassID or 0,
    }
end

function M.setBag(id, count)
    count = count or 1
    M.bags[id] = count
    M.bagSlots[#M.bagSlots + 1] = { itemID = id, stackCount = count }
end

function M.setSpell(id, spec)
    spec = spec or {}
    M.spells[id] = { name = spec.name or ("Spell " .. tostring(id)), known = spec.known ~= false }
end

function M.setSpec(classID, specIndex, specID, specName)
    M.spec = { classID = classID, specIndex = specIndex, specID = specID, specName = specName }
end

function M.setCombat(v) M.inCombat = v and true or false end

function M.setEquipped(slot, id) M.equipped[slot] = id end

-- ---------------------------------------------------------------------------
-- Permissive frame + widget stubs
-- ---------------------------------------------------------------------------

local function makeStub()
    local t = {}
    local mt = {}
    mt.__index = function(_, _) return function(...) return t end end
    setmetatable(t, mt)
    t.frame = t
    return t
end
M.makeStub = makeStub

-- ---------------------------------------------------------------------------
-- Ace3 stubs
-- ---------------------------------------------------------------------------

local function makeAceAddon(NS)
    local AceAddon = {}
    function AceAddon:NewAddon(targetOrName, ...)
        local addon = type(targetOrName) == "table" and targetOrName or NS
        -- Embed the no-op mixin surface the addon expects from AceEvent /
        -- AceConsole so registrations at load don't blow up.
        addon.RegisterEvent       = addon.RegisterEvent       or function() end
        addon.UnregisterEvent     = addon.UnregisterEvent     or function() end
        addon.RegisterChatCommand = addon.RegisterChatCommand or function() end
        addon.ScheduleTimer       = addon.ScheduleTimer       or function() end
        M.embedMessaging(addon)
        _G.KCM = addon
        return addon
    end
    function AceAddon:GetAddon() return NS end
    return AceAddon
end

-- Install AceEvent-style messaging onto `target`: RegisterMessage /
-- UnregisterMessage / SendMessage. The registry is keyed by (message, target)
-- (anti-pattern #33) and SendMessage broadcasts to every target registered for
-- that message — matching AceEvent's addon-global message semantics, so a
-- message sent on one embed reaches receivers on any other embed.
local function embedMessaging(target)
    target.RegisterMessage = function(self, message, handler)
        M.busReg[message] = M.busReg[message] or {}
        M.busReg[message][self] = handler or message
    end
    target.UnregisterMessage = function(self, message)
        if M.busReg[message] then M.busReg[message][self] = nil end
    end
    target.SendMessage = function(_, message, ...)
        local reg = M.busReg[message]
        if not reg then return end
        for tgt, h in pairs(reg) do
            if type(h) == "function" then h(tgt, message, ...)
            elseif type(h) == "string" and tgt[h] then tgt[h](tgt, message, ...) end
        end
    end
    return target
end
M.embedMessaging = embedMessaging

local function makeAceEvent()
    local AceEvent = {}
    function AceEvent.Embed(_, target) return embedMessaging(target) end
    return AceEvent
end
M.makeAceEvent = makeAceEvent

local function makeAceDB()
    local AceDB = {}
    -- Deep-merge defaults into a fresh profile/global so KCM.db.profile mirrors
    -- the live client shape closely enough for the pure layer.
    local function deepcopy(src)
        if type(src) ~= "table" then return src end
        local out = {}
        for k, v in pairs(src) do out[k] = deepcopy(v) end
        return out
    end
    function AceDB:New(_, defaults)
        defaults = defaults or {}
        local db = {}
        db.profile = deepcopy(defaults.profile or {})
        db.global  = deepcopy(defaults.global or {})
        db.char    = deepcopy(defaults.char or {})
        return db
    end
    return AceDB
end

-- ---------------------------------------------------------------------------
-- Install everything into _G, bound to namespace NS
-- ---------------------------------------------------------------------------

function M.install(NS)
    M.reset()

    local libs = {
        ["AceAddon-3.0"]   = makeAceAddon(NS),
        ["AceEvent-3.0"]   = makeAceEvent(),
        ["AceConsole-3.0"] = makeStub(),
        ["AceDB-3.0"]      = makeAceDB(),
        -- AceGUI: Create returns a permissive widget stub; GetWidgetVersion
        -- returns 0 (a number, so widget files' `>= Version` guard compares
        -- cleanly and proceeds to register). Everything else is a no-op.
        ["AceGUI-3.0"]     = setmetatable({
                                Create = function() return makeStub() end,
                                RegisterWidgetType = function() end,
                                RegisterLayout = function() end,
                                GetWidgetVersion = function() return 0 end,
                                WidgetVersions = {},
                             }, { __index = function() return function() return makeStub() end end }),
        ["LibSharedMedia-3.0"] = setmetatable(
            { Register = function() return true end, Fetch = function() return "font.ttf" end,
              MediaType = { FONT = "font" } },
            { __index = function() return function() end end }),
    }
    _G.LibStub = function(name) return libs[name] end

    _G.CreateFrame = function() return makeStub() end
    _G.UIParent = makeStub()
    _G.GameTooltip = makeStub()
    _G.UISpecialFrames = {}
    _G.StaticPopupDialogs = {}
    _G.StaticPopup_Show = function() end
    _G.YES, _G.NO = "Yes", "No"
    _G.BackdropTemplateMixin = {}
    _G.NORMAL_FONT_COLOR = { r = 1, g = 1, b = 1 }

    _G.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
        M.output[#M.output + 1] = table.concat(parts, " ")
    end

    -- Lua/WoW shared helpers
    _G.CopyTable = function(src)
        local function dc(s)
            if type(s) ~= "table" then return s end
            local o = {}
            for k, v in pairs(s) do o[k] = dc(v) end
            return o
        end
        return dc(src)
    end
    _G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    _G.time = function() return os.time() end
    _G.date = function(fmt) return os.date(fmt) end
    _G.GetTime = function() return os.clock() end
    _G.strtrim = function(s) return (s or ""):gsub("^%s+", ""):gsub("%s+$", "") end
    _G.strsplit = function(sep, s)
        local out = {}
        for part in (s or ""):gmatch("([^" .. sep .. "]+)") do out[#out + 1] = part end
        return table.unpack and table.unpack(out) or unpack(out)
    end
    _G.hooksecurefunc = function() end

    -- Combat / unit
    _G.InCombatLockdown = function() return M.inCombat end
    _G.UnitClass = function() return nil, nil, M.spec.classID end
    _G.UnitLevel = function() return 80 end
    _G.UnitName  = function() return "Tester" end
    _G.IsPlayerSpell = function(spellID)
        local s = M.spells[spellID]
        return s ~= nil and s.known == true
    end
    _G.IsSpellKnown = _G.IsPlayerSpell

    -- Spec APIs (Compat wraps these post Sprint 1)
    _G.GetSpecialization = function() return M.spec.specIndex end
    _G.GetSpecializationInfo = function(idx)
        if idx == M.spec.specIndex then return M.spec.specID, M.spec.specName end
        return nil
    end
    _G.GetNumClasses = function() return 13 end
    _G.GetNumSpecializations = function() return 1 end
    _G.GetNumSpecializationsForClassID = function() return 1 end
    _G.GetSpecializationInfoForClassID = function(classID, idx)
        if classID == M.spec.classID and idx == M.spec.specIndex then
            return M.spec.specID, M.spec.specName
        end
        return nil
    end
    _G.GetClassInfo = function(classID) return "Class" .. tostring(classID) end

    -- Item / spell legacy globals
    _G.GetItemInfo = function(id)
        local it = M.items[id]
        if not it then return nil end
        -- name, link, quality, ilvl, reqLevel, class, subType, ...
        return it.name, "link", it.quality, it.ilvl, 0, "Consumable", it.subType
    end
    _G.GetSpellInfo = function(spellID)
        local s = M.spells[spellID]
        return s and s.name or nil
    end
    _G.GetInventoryItemID = function(_, slot) return M.equipped[slot] end

    -- Macro APIs
    _G.GetMacroIndexByName = function(name) return M.macros[name] and M.macros[name].idx or 0 end
    _G.GetNumMacros = function()
        local n = 0
        for _ in pairs(M.macros) do n = n + 1 end
        return n
    end
    _G.CreateMacro = function(name, icon, body)
        local idx = 1
        for _ in pairs(M.macros) do idx = idx + 1 end
        M.macros[name] = { idx = idx, icon = icon, body = body }
        return idx
    end
    _G.EditMacro = function(idx, _, icon, body)
        for _, m in pairs(M.macros) do
            if m.idx == idx then m.icon, m.body = icon, body; return idx end
        end
        return 0
    end

    -- Namespaced client tables
    _G.C_Timer = { After = function(_, fn) if fn then fn() end end }
    _G.C_AddOns = { GetAddOnMetadata = function() return "" end }
    _G.C_Item = {
        GetItemInfoInstant = function(id)
            local it = M.items[id]
            if not it then return nil end
            -- itemID, itemType, itemSubType, equipLoc, icon, classID, subClassID
            return id, "Consumable", it.subType, "", 0, it.classID, it.subClassID
        end,
        GetItemCount = function(id) return M.bags[id] or 0 end,
        GetItemNameByID = function(id) return M.items[id] and M.items[id].name or nil end,
    }
    _G.C_Spell = {
        GetSpellName = function(spellID) return M.spells[spellID] and M.spells[spellID].name or nil end,
        GetSpellInfo = function(spellID)
            local s = M.spells[spellID]
            return s and { name = s.name } or nil
        end,
    }
    _G.C_Container = {
        GetContainerNumSlots = function(bag) return bag == 0 and #M.bagSlots or 0 end,
        GetContainerItemInfo = function(bag, slot)
            if bag ~= 0 then return nil end
            return M.bagSlots[slot]
        end,
    }
    _G.C_TooltipInfo = { GetItemByID = function() return nil end }
    _G.Settings = setmetatable({}, { __index = function() return function() end end })
    _G.NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5

    return NS
end

return M
