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
    M.cursor   = nil      -- { kind, arg } as GetCursorInfo would report
    M.cooldowns = {}      -- opaque KCM id -> { start, duration, enable }
    M.secretCooldowns = false  -- SecretWhenCooldownsRestricted in effect?
    _G.issecretvalue  = nil
    M.stateDrivers = {}   -- frame -> { state = macro conditional }
    M.attributeDrivers = {} -- frame -> { attribute = macro conditional }
end

-- Put an item/spell cooldown on the mock clock. Key is the opaque KCM ID
-- (positive itemID, negative spell sentinel), matching MacroDisplay's input.
function M.setCooldown(id, start, duration, enable)
    M.cooldowns[id] = { start, duration, enable }
end

-- A stand-in for a Midnight SECRET number: comparing or doing arithmetic on one
-- is an immediate error, which is precisely how the real thing behaves for
-- tainted code. Flag it through issecretvalue so KCM.Compat.IsSecret sees it.
local secretMeta
local function secretError() error("attempt to compare a secret number value") end
secretMeta = {
    __lt = secretError, __le = secretError,
    __add = secretError, __sub = secretError, __mul = secretError, __div = secretError,
}

function M.secret(value)
    return setmetatable({ value = value }, secretMeta)
end

-- Turn the spell cooldown API secret for the duration of a test, mirroring the
-- SecretWhenCooldownsRestricted predicate coming into effect in combat.
function M.setCooldownsRestricted(on)
    M.secretCooldowns = on and true or false
    _G.issecretvalue = on and function(v)
        return type(v) == "table" and getmetatable(v) == secretMeta
    end or nil
end

-- A stand-in for a LuaDurationObject. Records what it was configured with so a
-- test can assert the right span reached it, but exposes no comparison surface
-- the addon is allowed to use.
function M.makeDuration(start, duration)
    local d = { start = start, duration = duration }
    function d:SetTimeFromStart(s, dur, rate)
        self.start, self.duration, self.modRate = s, dur, rate
    end
    return d
end

-- A real item reports a localized subType DISPLAY string and a
-- locale-independent numeric classID/subClassID together. Keep the mock
-- consistent so a test that sets a readable subType gets the matching numeric
-- class the Classifier / WeaponSlots now key on. Explicit classID/subClassID
-- in the spec still override (e.g. a non-English subType with a real subclass,
-- to prove locale-independence).
local SUBTYPE_CLASS = {
    ["Food & Drink"]      = { 0, 5 },
    ["Potions"]           = { 0, 1 },
    ["Flasks & Phials"]   = { 0, 3 },
    ["Other"]             = { 0, 8 },
    ["One-Handed Swords"] = { 2, 7 },  ["Two-Handed Swords"] = { 2, 8 },
    ["One-Handed Axes"]   = { 2, 0 },  ["Two-Handed Axes"]   = { 2, 1 },
    ["Daggers"]           = { 2, 15 }, ["Polearms"]          = { 2, 6 },
    ["Fist Weapons"]      = { 2, 13 }, ["Warglaives"]        = { 2, 9 },
    ["One-Handed Maces"]  = { 2, 4 },  ["Two-Handed Maces"]  = { 2, 5 },
    ["Staves"]            = { 2, 10 },
    ["Shields"]           = { 4, 6 },  -- Armor / Shield (not enhanceable)
}

function M.setItem(id, spec)
    spec = spec or {}
    local cls = SUBTYPE_CLASS[spec.subType]
    M.items[id] = {
        name        = spec.name or ("Item " .. tostring(id)),
        subType     = spec.subType or "",
        quality     = spec.quality or 1,
        ilvl        = spec.ilvl or 1,
        tt          = spec.tt or {},
        -- classID/subClassID for GetItemInfoInstant — derived from subType when
        -- not given (real items keep them consistent); explicit spec overrides.
        classID     = spec.classID or (cls and cls[1]) or 0,
        subClassID  = spec.subClassID or (cls and cls[2]) or 0,
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

-- Methods a frame only has if its template grants them. Modelling this is the
-- difference between the harness catching a "attempt to call a nil value" crash
-- and shipping it: a fully permissive stub answers SetFrameRef on a plain button
-- and the bug only shows up in the client. Returning nil (rather than raising)
-- matches the client exactly, so `if frame.SetFrameRef then` guards still work.
-- Getters the addon does arithmetic on. The catch-all below returns the stub
-- table itself (so method chains work), which explodes the moment a caller writes
-- `frame:GetFrameLevel() + 1`. These return numbers instead.
-- GetName is concatenated into child frame names, so it has to be a string.
local STRING_GETTERS = { GetName = true, GetDebugName = true }

local NUMERIC_GETTERS = {
    GetFrameLevel = 0, GetWidth = 0, GetHeight = 0, GetStringWidth = 0,
    GetAlpha = 1, GetScale = 1, GetEffectiveScale = 1, GetNumPoints = 0,
    GetLeft = 0, GetRight = 0, GetTop = 0, GetBottom = 0,
}

local TEMPLATE_METHODS = {
    -- SecureHandler*Template — the secure-snippet surface
    SetFrameRef = "SecureHandler", GetFrameRef = "SecureHandler",
    Execute     = "SecureHandler", WrapScript  = "SecureHandler",
    -- BackdropTemplate
    SetBackdrop            = "Backdrop",
    SetBackdropColor       = "Backdrop",
    SetBackdropBorderColor = "Backdrop",
}

local function makeStub(template, name)
    local t = {}
    local mt = {}
    template = tostring(template or "")
    t._name = name

    -- Attributes are stored for real, not swallowed. The macro bar's secure
    -- snippets gate on them (kcmEntries, kcmGrace), so a test can assert the Lua
    -- side put the right values within the snippet's reach.
    t._attrs = {}
    t.SetAttribute = function(self, k, v) (self._attrs or t._attrs)[k] = v end
    t.GetAttribute = function(self, k) return (self._attrs or t._attrs)[k] end
    mt.__index = function(_, key)
        local need = TEMPLATE_METHODS[key]
        if need and not template:find(need, 1, true) then
            return nil          -- the client wouldn't have this method either
        end
        local num = NUMERIC_GETTERS[key]
        if num then return function() return num end end
        if STRING_GETTERS[key] then
            return function(self) return (self and self._name) or t._name or "MockFrame" end
        end
        return function(...) return t end
    end
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
        -- LibSharedMedia: enough of the real surface for the settings layer's
        -- LSMValues() lists and the macro bar's border fetch. `media` mirrors
        -- LSM's own default registrations for the media types we read.
        ["LibSharedMedia-3.0"] = setmetatable(
            {
                Register  = function() return true end,
                MediaType = { FONT = "font", BORDER = "border" },
                media     = {
                    border = { "None", "Blizzard Dialog", "Blizzard Tooltip" },
                    font   = { "Friz Quadrata TT", "JetBrains Mono" },
                },
                List = function(self, mediaType) return self.media[mediaType] end,
                Fetch = function(self, mediaType, key)
                    for _, name in ipairs(self.media[mediaType] or {}) do
                        if name == key then return mediaType .. ":" .. key end
                    end
                    return nil
                end,
            },
            { __index = function() return function() end end }),
    }
    _G.LibStub = function(name) return libs[name] end

    -- 4th arg is the template list; the stub grants template-gated methods from it.
    _G.CreateFrame = function(_, name, _, template) return makeStub(template, name) end
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
    _G.GetMacroInfo = function(idx)
        for name, m in pairs(M.macros) do
            if m.idx == idx then return name, m.icon, m.body end
        end
        return nil
    end
    _G.PickupMacro = function(idx) M.cursor = { "macro", idx } end
    _G.GetCursorInfo = function()
        if not M.cursor then return nil end
        return M.cursor[1], M.cursor[2]
    end
    _G.ClearCursor = function() M.cursor = nil end

    -- Secure visibility driver. The macro bar hands combat-conditional
    -- show/hide to these rather than calling Show/Hide in combat; the mock just
    -- records the last macro-conditional string per frame so tests can assert it.
    M.stateDrivers = {}
    _G.RegisterStateDriver = function(frame, state, value)
        M.stateDrivers[frame] = M.stateDrivers[frame] or {}
        M.stateDrivers[frame][state] = value
    end
    _G.UnregisterStateDriver = function(frame, state)
        if M.stateDrivers[frame] then M.stateDrivers[frame][state] = nil end
    end
    -- Attribute drivers feed combat state into secure snippets, which have no
    -- InCombatLockdown of their own.
    M.attributeDrivers = {}
    _G.RegisterAttributeDriver = function(frame, attribute, value)
        M.attributeDrivers[frame] = M.attributeDrivers[frame] or {}
        M.attributeDrivers[frame][attribute] = value
    end
    _G.UnregisterAttributeDriver = function(frame, attribute)
        if M.attributeDrivers[frame] then M.attributeDrivers[frame][attribute] = nil end
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
        GetItemIconByID = function(id) return M.items[id] and ("icon:" .. id) or nil end,
        GetItemCooldown = function(id)
            local cd = M.cooldowns[id]
            if not cd then return 0, 0, 1 end
            return cd[1], cd[2], cd[3] or 1
        end,
    }
    _G.C_Spell = {
        GetSpellName = function(spellID) return M.spells[spellID] and M.spells[spellID].name or nil end,
        GetSpellInfo = function(spellID)
            local s = M.spells[spellID]
            return s and { name = s.name } or nil
        end,
        GetSpellTexture = function(spellID)
            return M.spells[spellID] and ("spellicon:" .. spellID) or nil
        end,
        -- isEnabled/isActive are the two NeverSecret fields of the real
        -- SpellCooldownInfo — the only ones a tainted caller may branch on once
        -- cooldowns are restricted. M.secretCooldowns makes startTime/duration
        -- come back as values that error on comparison, exactly as they do
        -- mid-fight on a live 12.0 client.
        GetSpellCooldown = function(spellID)
            local cd = M.cooldowns[-spellID]
            if not cd then
                return { startTime = 0, duration = 0, isEnabled = true, isActive = false }
            end
            local start, duration = cd[1], cd[2]
            if M.secretCooldowns then start, duration = M.secret(start), M.secret(duration) end
            return {
                startTime = start, duration = duration,
                isEnabled = cd[3] ~= false, isActive = true,
            }
        end,
        GetSpellCooldownDuration = function(spellID)
            local cd = M.cooldowns[-spellID]
            if not cd then return nil end
            return M.makeDuration(cd[1], cd[2])
        end,
    }
    -- Duration objects (12.0). Opaque by design: the addon may only hand one
    -- back to Cooldown:SetCooldownFromDurationObject, never read it.
    _G.C_DurationUtil = {
        CreateDuration = function() return M.makeDuration() end,
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
