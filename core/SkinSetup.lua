-- core/SkinSetup.lua — the LibKa0s-Skin-1.0 seam: which skin this addon wears (skinning-§3).
--
-- ---------------------------------------------------------------------------
-- WHAT IT PUBLISHES
-- ---------------------------------------------------------------------------
--
--   KCM.Skin                 the owner's facade, `Skin:For("ConsumableMaster")`: the painting
--                            vocabulary (Shell, Button, Text, ...) and Token / Color / Resolve /
--                            OnLooksChanged. Every surface that draws reads its colors here.
--   KCM.SkinChoice()         the stored (source, skin) pair, read through the schema seam;
--                            "ka0s", "ka0s" before AceDB has built the profile.
--   KCM.WriteSkinChoice(s,k,i,m) the write seam: every half through KCM.Schema:Set, the one door
--                            `/cm set` and the panel already write through (architecture-§5);
--                            `i`, the Scope's `{ panel, fonts }`, writes the two exceptions, and
--                            `m`, the Font and texture section's `{ font, texture }`, writes the
--                            two overrides, "" for false (the skin's own).
--   KCM.SkinOverride()       the stored overrides: font, texture, each an LSM key or false for
--                            the skin's own; false, false before AceDB.
--   KCM.ApplySkinIgnore(p,f) moves the applied exceptions (`Skin:SetIgnore`), live; no argument
--                            applies the stored pair, a nil half keeps that half.
--   KCM.ApplySkinOverride(f,t) moves the applied overrides (`Skin:SetOverride`), live; no
--                            argument applies the stored pair, a nil half keeps that half.
--   KCM.ApplySkinChoice(s,k) moves the applied skin (`Skin:SetChoice`, which repaints every frame
--                            recorded for this owner and THEN fires OnLooksChanged). No argument
--                            applies the stored pair with its exceptions and overrides
--                            (KCM:OnInitialize, the profile events); a nil half keeps that half
--                            (each Skin tab row's apply).
--   KCM.SKIN_SOURCE_OPTIONS  the source row's values, and KCM.SKIN_OPTIONS the skin row's (every
--   KCM.SKIN_OPTIONS         registered skin, in the library's order). settings/General.lua
--                            reads both at file load.
--   KCM.SKIN_TOKENS          this addon's own tokens (skinning-§1): a color it draws that no
--                            library token holds exactly, each with Ka0s Default's value and the
--                            library role it follows in every other skin.
--   KCM.SKIN_FALLBACK        the host copy of the Ka0s Default values the DEGRADED facade
--                            answers, limited to the tokens this addon reads.
--   KCM.SkinColor(name)      a color token as a call site writes it (three components when
--                            opaque), so a literal that became a token keeps its arity.
--   KCM.SkinEscape(name)     a color token as a "|cffrrggbb" escape, rounded to the byte, so
--                            markup written as a literal keeps its bytes on Ka0s Default.
--   KCM.SkinPaintAce(w)      an AceGUI widget this addon acquired itself, painted for this
--   KCM.SkinPaintAceTree(c)  owner (`Skin:PaintAce` / `Skin:PaintAceTree`, the owner bound).
--   KCM.SkinOnRelease(w, fn) host release work chained onto the widget's own OnRelease
--                            (`Skin:OnRelease`), so it and the skin's restore both run.
--
-- ---------------------------------------------------------------------------
-- WHERE IT LOADS
-- ---------------------------------------------------------------------------
--
-- At FILE LOAD, never at PLAYER_LOGIN (skinning-§1): the EllesmereUI provider has to offer the
-- owner to EllesmereUI before EllesmereUI dispatches its skins. After core/CoreSetup.lua and
-- before every file that builds a frame (the launcher, the debug console, the macro bar, the
-- settings pages), so KCM.Skin exists for all of them; settings/General.lua reads the two option
-- lists at file load and is far below. Nothing here reads the profile at load: RegisterOwner calls
-- `get` once, before AceDB exists, and it answers Ka0s Default; the profile's pair is applied by
-- KCM.ApplySkinChoice right after AceDB is built (core/ConsumableMaster.lua).
--
-- ---------------------------------------------------------------------------
-- WHY A ROW'S apply PASSES ONE HALF
-- ---------------------------------------------------------------------------
--
-- The Skin tab and another addon's "Copy to every Ka0s addon" both call Skin:SetChoice FIRST and
-- write the store after, one half at a time. A row reaction that re-applied the whole stored pair
-- would apply the half-written one in between: a second repaint, to a skin the player never
-- picked. Applying only the row's own half against the applied choice makes each write a no-op
-- (SetChoice is idempotent), so a pick is ONE effective SetChoice and one repaint, while a bare
-- `/cm set skin.skin obsidian` still repaints.
--
-- Nothing skin-related keys off a settings message. A surface that has to rebuild on a skin change
-- subscribes to KCM.Skin.OnLooksChanged, which fires after the new skin is resolved and the
-- recorded frames are repainted.

local addonName, NS = ...
local KCM = NS

local Skin = LibStub and LibStub("LibKa0s-Skin-1.0", true)

local SOURCE_PATH, SKIN_PATH = "skin.source", "skin.skin"
local PANEL_PATH, FONTS_PATH = "skin.ignorePanel", "skin.ignoreFonts"
local FONT_PATH, TEXTURE_PATH = "skin.font", "skin.texture"
local DEFAULT = "ka0s"

-- The brand the Skin tab and the copy confirmation print (skinning-§1's `opts.label`).
local LABEL = "Ka0s Consumable Master"

-- ---------------------------------------------------------------------------
-- The owner tokens (skinning-§1; LibKa0s v1.80.0, Skin minor 7)
-- ---------------------------------------------------------------------------
--
-- Each is a color this addon draws under Ka0s Default whose exact value no library token holds,
-- so Ka0s Default answers `default`, today's pixels, and every other skin answers the `follow`
-- token's value in that skin (the rollout's X1, X2 and X12: never snapped to the nearest library
-- token, which would move a Ka0s Default pixel; named in this addon's own `cm.` namespace, never a
-- library family's).
KCM.SKIN_TOKENS = {
    -- CM-G1: the priority rows' icon buttons (up, down, delete) light this gold wash under the
    -- pointer (modules/KCMIconButton.lua). No library hover wash sits at 0.25; it follows the
    -- list rows' own hover wash.
    ["cm.iconHover"] = { default = { 1, 0.82, 0, 0.25 }, follow = "list.hover" },
    -- CM-G2: the settings pages' warning lines (no spec, empty list, no sub-categories, no
    -- categories), drawn |cffff8800. sem.warn is { 1, 0.5, 0 }, two levels off; it follows it.
    ["cm.warn"] = { default = { 1, 0x88 / 255, 0, 1 }, follow = "sem.warn" },
    -- CM-G3: the two grays the score tooltip writes into GameTooltip lines (settings/Category.lua):
    -- the note (|cff888888) follows the tooltip's muted gray, the summary (|cffaaaaaa) its subtle one.
    ["cm.tipNote"] = { default = { 0x88 / 255, 0x88 / 255, 0x88 / 255, 1 }, follow = "gtip.muted" },
    ["cm.tipSummary"] = { default = { 0xaa / 255, 0xaa / 255, 0xaa / 255, 1 }, follow = "gtip.subtle" },
}

-- The Ka0s Default values the DEGRADED facade answers, limited to the tokens this addon reads.
-- Both arms publish the table, so tests/test_skin.lua can hold each entry to the live facade's
-- Ka0s Default answer: a copy that drifts goes red there. A surface converted to a token adds the
-- token here in the same change. The owner tokens' entries are their own defaults.
KCM.SKIN_FALLBACK = {}
for name, def in pairs(KCM.SKIN_TOKENS) do KCM.SKIN_FALLBACK[name] = def.default end

--- A color token's components AS A CALL SITE WRITES THEM: r, g, b for an opaque color and r, g,
--- b, a otherwise (the library's own text and vertex rule), so a site that passed three components
--- before it read a token still passes three on Ka0s Default. nil for a token the skin leaves
--- alone. Read through KCM.Skin at call time, so it answers the live skin, or the host copy
--- degraded.
function KCM.SkinColor(name)
    local r, g, b, a = KCM.Skin.Color(name)
    if r == nil then return nil end
    if a == nil or a == 1 then return r, g, b end
    return r, g, b, a
end

--- A color token as a "|cffrrggbb" escape, each channel rounded to the nearest byte (0x88/255
--- rounds back to 0x88), so markup a call site wrote as a literal keeps its bytes on Ka0s Default. nil for a token
--- the skin leaves alone.
function KCM.SkinEscape(name)
    local r, g, b = KCM.Skin.Color(name)
    if r == nil then return nil end
    local function byte(v) return math.floor(v * 255 + 0.5) end
    return ("|cff%02x%02x%02x"):format(byte(r), byte(g), byte(b))
end

KCM.SKIN_SOURCE_OPTIONS = {
    { value = "ka0s", text = "Ka0s skins" },
    { value = "eui",  text = "EllesmereUI" },
}

-- The skin row's values: every registered skin, Ka0s Default first. Without the library the one
-- skin the degraded facade can draw.
KCM.SKIN_OPTIONS = {}
if Skin and type(Skin.Skins) == "function" then
    for _, def in ipairs(Skin:Skins()) do
        KCM.SKIN_OPTIONS[#KCM.SKIN_OPTIONS + 1] = { value = def.key, text = def.label or def.key }
    end
end
if #KCM.SKIN_OPTIONS == 0 then KCM.SKIN_OPTIONS[1] = { value = DEFAULT, text = "Ka0s Default" } end

-- The schema seam's read and write, resolved at CALL time: settings/Panel.lua builds them far
-- below this file. Read through Helpers.Get, written through KCM.Schema:Set (the SetAndRefresh
-- door), which settings/Panel.lua publishes on both arms, so a degraded install still stores.
local function seamGet()
    local H = KCM.Settings and KCM.Settings.Helpers
    if not (KCM.db and KCM.db.profile and H and H.Get) then return nil end
    return H.Get
end

local function seamSet(path, value)
    if not (KCM.db and KCM.db.profile and KCM.Schema and KCM.Schema.Set) then return end
    KCM.Schema:Set(path, value)
end

--- The stored pair, lazily and nil-safely: Ka0s Default until the profile store exists.
function KCM.SkinChoice()
    local get = seamGet()
    if not get then return DEFAULT, DEFAULT end
    return get(SOURCE_PATH) or DEFAULT, get(SKIN_PATH) or DEFAULT
end

--- A stored override as the profile keeps it: the LSM key, or "" for the skin's own.
local function storedKey(v)
    if type(v) == "string" and v ~= "" then return v end
    return ""
end

--- The write seam: every half through KCM.Schema:Set (validate, store, the [Set] line, apply).
--- `media` is `{ font = key|false, texture = key|false }`: the Skin tab's Font and texture pick and
--- another addon's copy both hand it here, after Skin:SetOverride moved the applied pair, so each
--- row's apply re-applies its own half as a no-op.
function KCM.WriteSkinChoice(source, skin, ignore, media)
    if source ~= nil then seamSet(SOURCE_PATH, source) end
    if skin ~= nil then seamSet(SKIN_PATH, skin) end
    if type(ignore) == "table" then
        seamSet(PANEL_PATH, ignore.panel == true)
        seamSet(FONTS_PATH, ignore.fonts == true)
    end
    if type(media) == "table" then
        seamSet(FONT_PATH, storedKey(media.font))
        seamSet(TEXTURE_PATH, storedKey(media.texture))
    end
end

--- The stored overrides, nil-safely: each an LSM key, or false for the skin's own; false, false
--- until the profile store exists.
function KCM.SkinOverride()
    local get = seamGet()
    if not get then return false, false end
    local font, texture = storedKey(get(FONT_PATH)), storedKey(get(TEXTURE_PATH))
    return font ~= "" and font or false, texture ~= "" and texture or false
end

--- The stored exceptions, nil-safely: false, false until the profile store exists.
local function storedIgnore()
    local get = seamGet()
    if not get then return false, false end
    return get(PANEL_PATH) == true, get(FONTS_PATH) == true
end

-- AceGUI keeps ONE callback per event name (options-ui-§19). Without the library's chain there is
-- no skin restore to share the release with, so the host's work takes the callback.
local function releaseByCallback(widget, fn)
    if type(widget) ~= "table" or type(fn) ~= "function" or type(widget.SetCallback) ~= "function" then
        return nil
    end
    widget:SetCallback("OnRelease", function(w) fn(w) end)
    return fn
end

-- ---------------------------------------------------------------------------
-- The degraded arm
-- ---------------------------------------------------------------------------

if not Skin then
    local function color(name)
        local c = KCM.SKIN_FALLBACK[name]
        if c then return c[1], c[2], c[3], c[4] or 1 end
    end
    local function noop() end
    local S = { owner = addonName, apiVersion = 3, FROM_SKIN = "@skin" }
    -- Every vocabulary name answers, and a primitive with no host meaning is a no-op that never
    -- raises. The list is LibKa0s-Skin-1.0's VOCAB; tests/test_skin.lua holds this table to the
    -- live facade key for key.
    for _, name in ipairs({
        "Shell", "Panel", "Inset", "FadeRegions", "FadeNineSlice", "Button", "WhiteButtonLabel",
        "StateButtonLabel", "EditBox", "Checkbox", "Dropdown", "ScrollBar", "Tab", "SetTabSelection",
        "CloseButton", "PageButton", "SquareIcon", "SortHeaderBar", "Font", "White", "ApplyBarFill",
        "GetAccentColor", "GetPanelColor", "GetFont",
        "TitleBar", "Divider", "Footer", "Card", "Slider", "NavItem", "Drawer", "ListRow", "MenuFrame",
        "Tooltip", "Strip", "Cover", "Text", "ChartStyle", "BarStyle", "IconBorder", "GlowColor",
        "BarTexture",
    }) do S[name] = noop end

    S.Token = function(name) return KCM.SKIN_FALLBACK[name] end
    S.Color = color
    S.Resolve = function(kind, value, fromSkin)
        if fromSkin or value == S.FROM_SKIN then return S.Token(kind) end
        return value
    end
    S.OnLooksChanged = function(fn) return fn end   -- the skin never changes without the library
    S.IsEnabled = function() return false end
    S.GetStyle = function() return "ka0s:" .. DEFAULT end
    S.Text = function(fs, role)
        local r, g, b, a = color("text." .. tostring(role))
        if r and fs and fs.SetTextColor then fs:SetTextColor(r, g, b, a) end
    end
    S.GetFont = function() return _G.STANDARD_TEXT_FONT end
    S.ChartStyle = function() return {} end
    S.BarStyle = function() return {} end

    KCM.Skin = S
    function KCM.ApplySkinChoice() return false, false end
    function KCM.ApplySkinIgnore() return false, false end
    function KCM.ApplySkinOverride() return false end
    -- Nothing to paint an AceGUI row with: stock AceGUI, as the client draws it.
    function KCM.SkinPaintAce() return false end
    function KCM.SkinPaintAceTree() return 0 end
    KCM.SkinOnRelease = releaseByCallback
    return
end

-- ---------------------------------------------------------------------------
-- The live seam
-- ---------------------------------------------------------------------------

KCM.Skin = Skin:For(addonName)
Skin:RegisterOwner(addonName, {
    label  = LABEL,
    get    = KCM.SkinChoice,
    set    = KCM.WriteSkinChoice,
    tokens = KCM.SKIN_TOKENS,
})

-- The one line a reload request earns on the path that has no popup of its own (a profile event
-- leaving an EllesmereUI that painted this session). The Skin tab raises the library's popup for
-- its own picks.
local function sayReload()
    local L = KCM.L
    local line = L and L["Reload your interface (/reload) to finish changing the skin."]
        or "Reload your interface (/reload) to finish changing the skin."
    if KCM.Say then KCM.Say(line) end
end

-- The AceGUI rows (SkinAce.lua). The Options instance's O.AceGUI is the owner proxy, which paints
-- on Create already; PaintAce for the same owner repaints in place, so a host call after it is
-- harmless, and it is what paints a widget acquired any other way (AceConfigDialog's, on the
-- Profiles page). Each guards on the member, so a copy whose SkinAce did not attach paints nothing.
function KCM.SkinPaintAce(widget)
    if type(Skin.PaintAce) ~= "function" then return false end
    return Skin:PaintAce(addonName, widget)
end

function KCM.SkinPaintAceTree(container)
    if type(Skin.PaintAceTree) ~= "function" then return 0 end
    return Skin:PaintAceTree(addonName, container)
end

function KCM.SkinOnRelease(widget, fn)
    if type(Skin.OnRelease) ~= "function" then return releaseByCallback(widget, fn) end
    return Skin:OnRelease(widget, fn)
end

function KCM.ApplySkinIgnore(panel, fonts)
    if type(Skin.SetIgnore) ~= "function" then return false, false end
    if panel == nil and fonts == nil then panel, fonts = storedIgnore() end
    local changed, reload = Skin:SetIgnore(addonName, panel, fonts)
    if reload then sayReload() end
    return changed, reload
end

--- No argument applies the stored overrides; a nil half keeps that half, false or "" clears it
--- (the skin's own). A copy without SetOverride moves nothing.
function KCM.ApplySkinOverride(font, texture)
    if type(Skin.SetOverride) ~= "function" then return false end
    if font == nil and texture == nil then font, texture = KCM.SkinOverride() end
    return Skin:SetOverride(addonName, font, texture)
end

--- No argument applies the stored pair AND the stored exceptions and overrides (KCM:OnInitialize,
--- the profile events); a nil half keeps that half and leaves the rest alone (each Skin tab row).
function KCM.ApplySkinChoice(source, skin)
    local whole = source == nil and skin == nil
    if whole then source, skin = KCM.SkinChoice() end
    local changed, reload = Skin:SetChoice(addonName, source, skin)
    if reload then sayReload() end
    if whole then
        KCM.ApplySkinIgnore()
        KCM.ApplySkinOverride()
    end
    return changed, reload
end
