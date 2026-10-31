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
--                            two overrides, "" for false (the skin's own); its `outline`, when
--                            not nil, writes skin.outline (LibKa0s v1.82.0, D-06).
--   KCM.SkinOverride()       the stored overrides: font, texture, each an LSM key or false for
--                            the skin's own; false, false before AceDB.
--   KCM.ApplySkinIgnore(p,f) moves the applied exceptions (`Skin:SetIgnore`), live; no argument
--                            applies the stored pair, a nil half keeps that half.
--   KCM.ApplySkinOverride(f,t) moves the applied overrides (`Skin:SetOverride`), live; no
--                            argument applies the stored pair, a nil half keeps that half.
--   KCM.ApplySkinOutline(m)  moves the applied Font outline (`Skin:SetOutline`), live; no
--                            argument applies the stored skin.outline.
--   KCM.SKIN_OUTLINE_OPTIONS the outline row's values: "all", "hud", "off", the library's order.
--   KCM.ApplySkinChoice(s,k) moves the applied skin (`Skin:SetChoice`, which repaints every frame
--                            recorded for this owner and THEN fires OnLooksChanged). No argument
--                            applies the stored pair with its exceptions, overrides and outline
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
--   KCM.SkinPanelOn()        true while the Scope's "Ignore settings panel" is off (the live
--                            exception, Skin:GetIgnore); false degraded. The settings surfaces
--   KCM.SkinPanelColor(name) draw through the three panel helpers, never KCM.SkinColor / S.Text:
--   KCM.SkinPanelEscape(name) each answers the skin while the panel is skinned and the STOCK look
--   KCM.SkinPanelText(fs, r) (the host copy of Ka0s Default, today's pixels) while it is ignored.
--                            The reorder lists take this owner plainly: ReorderList is
--                            panel-scoped by default (WidgetsReorder minor 3). See below.
--   KCM.SkinPaintAce(w)      an AceGUI widget this addon acquired itself, painted for this
--   KCM.SkinPaintAceTree(c)  owner (`Skin:PaintAce` / `Skin:PaintAceTree`, the owner bound).
--   KCM.SkinOnRelease(w, fn) host release work chained onto the widget's own OnRelease
--                            (`Skin:OnRelease`), so it and the skin's restore both run.
--   KCM.SkinAcquire(ace, t)  `ace:Create(t)` then KCM.SkinPaintAce: every AceGUI widget the
--                            settings files acquire themselves.
--   KCM.MaybeShowSkinPicker() the first-run skin picker (LibKa0s OptionsSkinPicker, O3):
--                            `O.SkinPicker` while the profile's `skin.pickerSeen` is false and
--                            the addon stands up; held to PLAYER_REGEN_ENABLED in combat.
--                            Answers the frame, or nil, "queued" behind another Ka0s addon's.
--   KCM.HideSkinPicker()     takes a shown picker down or out of the queue WITHOUT marking it
--                            seen: the stand-down, and first on every profile event.
--   KCM.SkinPickerSpec()     the spec KCM.MaybeShowSkinPicker hands O.SkinPicker.
--   KCM.RunSkinVerb()        the reserved `/cm skin` verb's act (LibKa0s v1.82.0, D-16):
--                            O.SkinVerb with that spec, whatever `skin.pickerSeen` says.
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
local OUTLINE_PATH = "skin.outline"
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
KCM.SKIN_FALLBACK = {
    -- The settings pages' own rows and widgets (CM-02): the priority and slot rows' gold and gray
    -- labels, the icon buttons' and item rows' white labels, the drag icon's two states.
    ["text.accent"]    = { 1, 0.82, 0, 1 },
    ["text.disabled"]  = { 0.5, 0.5, 0.5, 1 },
    ["text.highlight"] = { 1, 1, 1, 1 },
    ["sem.unknown"]    = { 0.6, 0.6, 0.6, 1 },
    -- The GameTooltip lines this addon writes (skinning-§7: the lines, never the frame).
    ["gtip.title"]     = { 1, 0.82, 0, 1 },
    ["gtip.value"]     = { 1, 1, 1, 1 },
    -- The macro bar (CM-03): the unlocked bar's gold wash and the flyout indicator's arrow tint.
    -- The HUD's border styles and faces are strings this table does not carry: degraded, the bar
    -- draws the player's stored picks (modules/MacroBarButton.lua's BB.Follow).
    ["menu.hover"]     = { 1, 0.82, 0, 0.15 },
    ["icon.arrow"]     = { 1, 0.82, 0, 1 },
}
for name, def in pairs(KCM.SKIN_TOKENS) do KCM.SKIN_FALLBACK[name] = def.default end

--- Components as a call site writes them: r, g, b for an opaque color and r, g, b, a otherwise (the
--- library's own text and vertex rule), so a site that passed three components before it read a
--- token still passes three on Ka0s Default. nil for no color.
local function arity(r, g, b, a)
    if r == nil then return nil end
    if a == nil or a == 1 then return r, g, b end
    return r, g, b, a
end

--- A color as a "|cffrrggbb" escape, each channel rounded to the nearest byte (0x88/255 rounds
--- back to 0x88), so markup a call site wrote as a literal keeps its bytes on Ka0s Default.
local function escape(r, g, b)
    if r == nil then return nil end
    local function byte(v) return math.floor(v * 255 + 0.5) end
    return ("|cff%02x%02x%02x"):format(byte(r), byte(g), byte(b))
end

--- The stock look of a color token: the host copy of Ka0s Default, which is the color each
--- converted surface drew before skins (the game's own look on this addon's rows).
local function stock(name)
    local c = KCM.SKIN_FALLBACK[name]
    if not c then return nil end
    return c[1], c[2], c[3], c[4] or 1
end

--- A color token's components as a call site writes them, read through KCM.Skin at call time, so
--- it answers the live skin, or the host copy degraded. nil for a token the skin leaves alone.
function KCM.SkinColor(name) return arity(KCM.Skin.Color(name)) end

--- A color token as a "|cffrrggbb" escape. nil for a token the skin leaves alone.
function KCM.SkinEscape(name) return escape(KCM.Skin.Color(name)) end

-- ---------------------------------------------------------------------------
-- The settings surfaces and the Scope's "Ignore settings panel"
-- ---------------------------------------------------------------------------
--
-- "Ignore settings panel" covers the settings panel and nothing else (D-01 of the 2026-10-30 skin
-- library follow-ups), so this addon's own rows on its settings pages (the KCM* widgets, the Stat
-- Priority and macro bar slot rows, the pages' warning lines and score tooltips) stay stock while
-- it is on, which is the default, as the library's rows on the same page do. The strings go
-- through the library's own panel scope (`S.Text(fs, role, { panel = true })`, SkinPaintExtras
-- minor 6) and the reorder lists through ReorderList's (panel-scoped by default). The raw colors
-- (SetColorTexture, SetVertexColor, ghost colors, tooltip escapes) no primitive draws, so those
-- gate on the same public answer, Skin:GetIgnore (D-03). Turning the exception either way
-- repaints live: SetIgnore repaints the recorded strings and notifies OnLooksChanged, and the
-- Options instance re-renders the open pages, so each row is drawn again through these.

--- A settings surface's color: the skin's while the panel is skinned, the stock one while not.
function KCM.SkinPanelColor(name)
    if KCM.SkinPanelOn() then return KCM.SkinColor(name) end
    return arity(stock(name))
end

--- A settings surface's escape: the skin's while the panel is skinned, the stock one while not.
function KCM.SkinPanelEscape(name)
    if KCM.SkinPanelOn() then return KCM.SkinEscape(name) end
    return escape(stock(name))
end

local ON_PANEL = { panel = true }

--- A settings surface's FontString in a text role ("accent", "disabled") or a color token's name
--- ("text.highlight", "sem.unknown"), through `S.Text(fs, role, { panel = true })`: skinned, the
--- skin's color and body face, recorded for the skin's replay; ignored, the library gives the
--- string its own face and color back and paints nothing, live both ways. The ROLE is a state
--- color (the disabled gray, the not-yet gray, the gold on a white template) that the template's
--- own color does not carry, so while the panel is ignored the role's stock color goes on after.
function KCM.SkinPanelText(fs, role)
    KCM.Skin.Text(fs, role, ON_PANEL)
    if KCM.SkinPanelOn() or type(fs) ~= "table" or type(fs.SetTextColor) ~= "function" then return end
    role = tostring(role)
    local r, g, b, a = stock(role:find(".", 1, true) and role or ("text." .. role))
    if r then fs:SetTextColor(r, g, b, a) end
end

KCM.SKIN_SOURCE_OPTIONS = {
    { value = "ka0s", text = "Ka0s skins" },
    { value = "eui",  text = "EllesmereUI" },
}

-- The Font outline modes (LibKa0s-Skin-1.0 minor 9's OUTLINE_MODES, in its order), with the Skin
-- tab's words. A copy rather than a read of the library's list, so the degraded arm has the row too.
KCM.SKIN_OUTLINE_OPTIONS = {
    { value = "all", text = "All text" },
    { value = "hud", text = "HUD text only" },
    { value = "off", text = "Off" },
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
--- `media` is `{ font = key|false, texture = key|false, outline = mode|nil }`: the Skin tab's Font
--- and texture pick, its Font outline and another addon's copy all hand it here, after
--- Skin:SetOverride / Skin:SetOutline moved the applied look, so each row's apply re-applies its
--- own half as a no-op. A nil outline leaves skin.outline alone.
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
        if media.outline ~= nil then seamSet(OUTLINE_PATH, media.outline) end
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

--- An AceGUI widget this addon acquires itself (skinning-§3): `ace:Create(wtype)`, then
--- KCM.SkinPaintAce. The settings files keep their own AceGUI handle, so this paints whichever
--- handle a file was given (the raw library, or the Options instance's owner proxy, which already
--- painted it: PaintAce for the same owner repaints in place). A type with no library painter
--- (SimpleGroup, and this addon's four KCM* types, which paint themselves from KCM.Skin) is
--- painted nothing, and nothing at all is painted while the Scope's Ignore settings panel is on.
--- KCM.SkinPaintAce is resolved at call time, so this reaches each arm's.
---
--- No `Skin:AliasAceType`: an alias is for a stock type under a second pool name, and none of the
--- four KCM* types is one. Each builds its own frame and paints itself (CM-02), so a base painter
--- aliased onto it would paint over its own tokens. No host OnRelease either: no settings file
--- sets one, so the library's restore is the only release work (KCM.SkinOnRelease is the door for
--- one added later).
function KCM.SkinAcquire(ace, wtype)
    local w = ace:Create(wtype)
    KCM.SkinPaintAce(w)
    return w
end

-- ---------------------------------------------------------------------------
-- The first-run skin picker (LibKa0s OptionsSkinPicker, LibKa0s#64; the rollout's O3 and X6)
-- ---------------------------------------------------------------------------
--
-- WHEN. Once per session, two seconds after the first PLAYER_ENTERING_WORLD (an event only an
-- addon that stands up registers), after OnInitialize applied the stored skin; and again after
-- every profile event (core/ConsumableMaster.lua's handler), because a new, copied or reset
-- profile carries its own `skin.pickerSeen`. Never while the addon stands down, and never in
-- combat: a start in combat is held for the PLAYER_REGEN_ENABLED edge, one target at most.
--
-- SEEN. The library calls `onClose` once per showing, by any route the player takes (Apply, its
-- close control, the gear, Escape), and once for a picker still queued behind another Ka0s addon's
-- when that addon's "Apply to all Ka0s addons" dismisses it unshown: that is the one write of
-- `skin.pickerSeen`, through KCM.Schema:Set. A close this addon makes itself (KCM.HideSkinPicker:
-- the stand-down, a profile event) is not the player's and writes nothing.
--
-- NO EYE (X6, D3). The eye previews a pick on an addon's primary window or test mode, and this
-- addon has neither (the unlocked macro bar is its own preview), so the spec carries no
-- `onPreview` and the picker draws no eye. A pick still previews live on the bar and the panel;
-- `set` (KCM.WriteSkinChoice) runs only on Apply, the gear or Apply to all.
--
-- QUEUED. One picker is up at a time across every Ka0s addon: while another addon's is up,
-- O.SkinPicker queues this one and answers nil, "queued", which KCM.MaybeShowSkinPicker passes
-- through; it shows when the other closes.

local PICKER_PATH = "skin.pickerSeen"
local pickerTarget       -- the one-shot PLAYER_REGEN_ENABLED target, while a start is held
local quietClose = false -- true while KCM.HideSkinPicker takes the picker down

--- The Options instance (KCM.Settings.Helpers carries its members), resolved at call time:
--- settings/OptionsSetup.lua loads far below, and its degraded stubs answer nil and do nothing.
local function pickerHost()
    return KCM.Settings and KCM.Settings.Helpers
end

--- The player's close: the picker seen, and nothing else. The library's put-back already wears the
--- stored choice, so the skin is not this callback's to move.
local function pickerClosed()
    if quietClose then return end
    seamSet(PICKER_PATH, true)
end

function KCM.SkinPickerSpec()
    return {
        owner = addonName, get = KCM.SkinChoice, set = KCM.WriteSkinChoice,
        -- The gear's default: O.OpenOptionsPanel("general"), the General page's own key
        -- (settings/General.lua's panelKey), then O.SelectTab("general", "Appearance"), the Skin
        -- tab's key on that page.
        page = "general", tab = "Appearance",
        onClose = pickerClosed,
    }
end

local function dropPickerDeferral()
    if pickerTarget then pickerTarget:UnregisterAllEvents(); pickerTarget = nil end
end

--- True while this profile has not closed the picker and the addon stands up.
local function pickerDue()
    local get = seamGet()
    if not get then return false end
    if KCM.IsStoodDown and KCM.IsStoodDown() then return false end
    return get(PICKER_PATH) == false
end

--- Takes a shown picker down (its pending preview put back) or out of the queue WITHOUT marking it
--- seen: the stand-down, a profile that has seen it, and first on every profile event. Drops a
--- held combat deferral.
function KCM.HideSkinPicker()
    dropPickerDeferral()
    local H = pickerHost()
    if not (H and type(H.HideSkinPicker) == "function") then return end
    quietClose = true
    local ok, err = pcall(H.HideSkinPicker)
    quietClose = false
    if not ok then error(err, 0) end
end

--- Show the picker when this profile has not seen it: answers O.SkinPicker's frame, or nil,
--- "queued" while another Ka0s addon's picker is up (it shows when that one closes), or nil.
function KCM.MaybeShowSkinPicker()
    local H = pickerHost()
    if not (H and type(H.SkinPicker) == "function") then return nil end
    if not pickerDue() then
        KCM.HideSkinPicker()
        return nil
    end
    if InCombatLockdown and InCombatLockdown() then
        if pickerTarget then return nil end
        pickerTarget = KCM.NewBusTarget and KCM.NewBusTarget()
        if not pickerTarget then return nil end
        KCM.SafeRegisterEvent(pickerTarget, "PLAYER_REGEN_ENABLED", function()
            dropPickerDeferral()
            KCM.MaybeShowSkinPicker()
        end, KCM.RejectedEvents)
        return nil
    end
    return H.SkinPicker(KCM.SkinPickerSpec())
end

--- The reserved `/cm skin` verb's act (LibKa0s v1.82.0, OptionsSkinPicker minor 3, ruling D-16):
--- O.SkinVerb with the spec the first-run start builds, so it shows the picker a new profile shows
--- whatever skin.pickerSeen says; a close still marks the profile seen. The library prints its own
--- lines (combat on every call, queued, unavailable); without LibKa0s the Options stub answers
--- nil, "absent" and this prints the library-absent line. The dispatcher refuses the verb while
--- the addon is disabled (it is not on settings/Slash.lua's live set). Answers the picker's frame,
--- or nil and the reason.
function KCM.RunSkinVerb()
    local H = pickerHost()
    local win, why
    if H and type(H.SkinVerb) == "function" then
        win, why = H.SkinVerb(KCM.SkinPickerSpec())
    else
        why = "absent"
    end
    if win == nil and why == "absent" and KCM.SlashCommands and KCM.SlashCommands.SayLibraryAbsent then
        KCM.SlashCommands.SayLibraryAbsent("skin")
    end
    return win, why
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
    -- A role ("accent") or, as the live primitive takes since SkinPaintExtras minor 5, a color
    -- token's name ("text.highlight", "cm.warn").
    S.Text = function(fs, role)
        role = tostring(role)
        local r, g, b, a = color(role:find(".", 1, true) and role or ("text." .. role))
        if r and fs and fs.SetTextColor then fs:SetTextColor(r, g, b, a) end
    end
    S.GetFont = function() return _G.STANDARD_TEXT_FONT end
    S.ChartStyle = function() return {} end
    S.BarStyle = function() return {} end
    -- LibKa0s v1.82.0 (SkinPaintExtras minor 7): never nil, since SetFont reads a nil flags as
    -- none and refuses a nil height. A picked flag as stored, "OUTLINE" for From skin or nothing
    -- stored (FontGroup's old default, the live one's answer while the fonts are ignored); a
    -- positive stored size as is, else 12 (no skin to scale it by).
    S.FontFlags = function(v)
        if type(v) == "string" and v ~= S.FROM_SKIN then return v end
        return "OUTLINE"
    end
    S.HudFontSize = function(size)
        local n = tonumber(size)
        return (n and n > 0) and n or 12
    end

    KCM.Skin = S
    function KCM.ApplySkinChoice() return false, false end
    function KCM.ApplySkinIgnore() return false, false end
    function KCM.ApplySkinOverride() return false end
    function KCM.ApplySkinOutline() return false end
    -- Nothing to paint an AceGUI row with: stock AceGUI, as the client draws it.
    function KCM.SkinPaintAce() return false end
    function KCM.SkinPaintAceTree() return 0 end
    KCM.SkinOnRelease = releaseByCallback
    -- No skin to ignore: the settings surfaces draw the stock look.
    function KCM.SkinPanelOn() return false end
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

--- The applied exceptions, read live from the library (the Scope rows' apply moves them through
--- KCM.ApplySkinIgnore): a copy without GetIgnore answers the panel skinned and fonts kept.
function KCM.SkinPanelOn()
    if type(Skin.GetIgnore) ~= "function" then return true end
    local panel = Skin:GetIgnore(addonName)
    return not panel
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

--- The applied Font outline: Skin:SetOutline, live (a repaint and OnLooksChanged). No argument
--- applies the stored mode; the library reads an unknown one as "hud". A copy without SetOutline
--- moves nothing.
function KCM.ApplySkinOutline(mode)
    if type(Skin.SetOutline) ~= "function" then return false end
    if mode == nil then
        local get = seamGet()
        mode = get and get(OUTLINE_PATH) or nil
    end
    return Skin:SetOutline(addonName, mode)
end

--- No argument applies the stored pair AND the stored exceptions, overrides and outline (KCM:OnInitialize,
--- the profile events); a nil half keeps that half and leaves the rest alone (each Skin tab row).
function KCM.ApplySkinChoice(source, skin)
    local whole = source == nil and skin == nil
    if whole then source, skin = KCM.SkinChoice() end
    local changed, reload = Skin:SetChoice(addonName, source, skin)
    if reload then sayReload() end
    if whole then
        KCM.ApplySkinIgnore()
        KCM.ApplySkinOverride()
        KCM.ApplySkinOutline()
    end
    return changed, reload
end
