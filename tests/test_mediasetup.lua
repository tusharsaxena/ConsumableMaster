-- tests/test_mediasetup.lua — core/MediaSetup.lua, the LibKa0s-Media-1.0 seam.
--
-- WHAT EARNS THIS FILE is that every failure it can catch is silent in game. A
-- texture path that names a file which is not there draws nothing and raises
-- nothing; SetFont on a missing face leaves the console blank with no error and
-- no chat line. So the seam is exactly the kind of thing a green suite can sit
-- on top of forever — and the catalog it resolves against now lives in ANOTHER
-- REPO, one re-vendor away from renaming a mark out from under this addon.
--
-- These cases therefore assert on the ARGUMENT and the ANSWER, never on the
-- pixels: which folder name went in, which path came back, whether the file that
-- path names is on disk in this build.

local h = _G.KCM_TEST
local test = h.test
local loader = h.loader

-- The addon FOLDER, spelled once. This is the string the library builds every
-- path from, and it is deliberately NOT the frame-name prefix (KCM…) and not the
-- ## Title ("Consumable Master"): same-shaped strings, different questions.
local VENDORED = "Interface\\AddOns\\ConsumableMaster\\libs\\LibKa0s\\media\\"

-- ---------------------------------------------------------------------------
-- The seam
-- ---------------------------------------------------------------------------

test("MediaSetup: KCM.Icon answers the vendored path, extensionless", function(t)
    -- Extensionless is a contract, not a preference: the client appends the
    -- extension itself and a path carrying `.tga` is one of the two spellings
    -- that draw nothing at all.
    local KCM = loader.loadPure()
    t.eq(KCM.Icon("help"), VENDORED .. "icons\\help",
        "the help mark resolves into the vendored payload")
    t.falsy(KCM.Icon("help"):find("%.tga$"), "and the path carries no extension")
end)

test("MediaSetup: an icon the library does not ship answers nil", function(t)
    -- nil is a value the ladder in modules/MacroBar.lua can branch on. A
    -- plausible path to a texture that is not there is a control that is simply
    -- absent, forever, silently.
    local KCM = loader.loadPure()
    t.eq(KCM.Icon("nosuchicon"), nil)
end)

test("MediaSetup: KCM.MediaFont answers the vendored face, and only a face it ships", function(t)
    local KCM = loader.loadPure()
    t.eq(KCM.MediaFont("JetBrains Mono"), VENDORED .. "fonts\\JetBrainsMono-Regular.ttf")
    t.eq(KCM.MediaFont("Comic Sans"), nil)
end)

test("MediaSetup: the seam is told the addon FOLDER name, not the frame prefix", function(t)
    -- The one fact the whole file exists to carry. A vendored library cannot
    -- work out which folder it was copied into, so it asks — and this addon's
    -- frame globals say KCM while its folder says ConsumableMaster, which is
    -- exactly the pair of same-shaped strings a hand-typed constant gets wrong.
    -- red under: MediaSetup passing NS.name's prefix, a literal, or the title.
    local KCM = loader.loadPure()
    local Media = LibStub("LibKa0s-Media-1.0")
    t.truthy(Media, "the vendored Media major registered")
    t.eq(KCM.Icon("close"), Media.Icon("ConsumableMaster", "close"))
end)

-- ---------------------------------------------------------------------------
-- The console font, across the two repos that now describe it
-- ---------------------------------------------------------------------------

test("MediaSetup: the face the console names is one the library actually carries", function(t)
    -- core/DebugLogSetup.lua names "JetBrains Mono" and the library's FONTS is
    -- what RegisterLSM puts into LibSharedMedia. A name nobody registered
    -- renders in Blizzard's proportional fallback, which is the exact outcome
    -- shipping a monospace face was meant to prevent — and it renders quietly.
    loader.loadPure()
    local Media = LibStub("LibKa0s-Media-1.0")
    t.truthy(Media.FONTS["JetBrains Mono"],
        "the library's FONTS no longer carries the key the console asks for")
end)

test("MediaSetup: the console resolves its font through the seam, not a local copy", function(t)
    -- red under: core/DebugLogSetup.lua re-growing its own LSM:Register against
    -- an `Interface\AddOns\ConsumableMaster\media\fonts\…` path. That
    -- registration used to sit there and, because MediaSetup loads first, it
    -- overwrote the library's every login with a path only this addon carried.
    local root = _G.KCM_TEST_ROOT or "."
    local f = assert(io.open(root .. "/core/DebugLogSetup.lua", "r"))
    local src = f:read("*a")
    f:close()
    t.falsy(src:find("media\\fonts", 1, true) and src:find("LSM:Register", 1, true),
        "core/DebugLogSetup.lua registers a font path of its own again")
    t.truthy(src:find("KCM.MediaFont", 1, true), "it resolves the face through the seam")
end)

test("MediaSetup: this addon no longer ships its own copy of the face", function(t)
    -- The bytes moved into the payload. Two copies of one face under one LSM key
    -- is a collision whose winner is load order, which is why the local one went.
    local root = _G.KCM_TEST_ROOT or "."
    local f = io.open(root .. "/media/fonts/JetBrainsMono-Regular.ttf", "rb")
    if f then f:close() end
    t.falsy(f, "media/fonts/ is back — the duplicate the seam exists to remove")
end)

-- ---------------------------------------------------------------------------
-- The catalog, against what this addon actually asks for
-- ---------------------------------------------------------------------------

test("MediaSetup: every mark this addon draws is one the library ships", function(t)
    -- The names are plain strings in this addon's source and the catalog is in
    -- another repo. A rename on either side answers nil, and nil draws nothing.
    local KCM = loader.loadPure()
    local Media = LibStub("LibKa0s-Media-1.0")
    local known = {}
    for _, name in ipairs(Media.ICONS) do known[name] = true end
    -- The marks this addon asks for by name: the macro bar's handle help button
    -- (modules/MacroBar.lua), plus the four the library draws on its own behalf
    -- once it is told our folder name — the console's copy/clear/close and the
    -- copy window's and perf panel's close.
    for _, name in ipairs({ "help", "copy", "clear", "close" }) do
        t.truthy(known[name], "this addon draws '" .. name ..
            "', which LibKa0s-Media does not ship")
        t.truthy(KCM.Icon(name), "KCM.Icon answered nil for " .. name)
    end
end)

test("MediaSetup: every name the library ships has a file in the vendored copy", function(t)
    -- The library's own suite checks its catalog against its own directory. This
    -- checks THE COPY: a re-vendor that dropped a file, or a packaging step that
    -- filtered it out, leaves a catalog naming art this build does not carry.
    loader.loadPure()
    local Media = LibStub("LibKa0s-Media-1.0")
    local root = (_G.KCM_TEST_ROOT or ".") .. "/libs/LibKa0s/media/icons/"
    local missing = {}
    for _, name in ipairs(Media.ICONS) do
        local fh = io.open(root .. name .. ".tga", "rb")
        if fh then fh:close() else missing[#missing + 1] = name end
    end
    t.eq(table.concat(missing, ", "), "", "catalog names with no file in the vendored payload")
end)

test("MediaSetup: the vendored payload carries the face and its licence", function(t)
    local root = (_G.KCM_TEST_ROOT or ".") .. "/libs/LibKa0s/media/fonts/"
    for _, name in ipairs({ "JetBrainsMono-Regular.ttf", "JetBrainsMono-OFL.txt" }) do
        local fh = io.open(root .. name, "rb")
        t.truthy(fh, "libs/LibKa0s/media/fonts/" .. name .. " is missing from this build")
        if fh then fh:close() end
    end
end)

-- ---------------------------------------------------------------------------
-- The TOC position, which is load-bearing here rather than conventional
-- ---------------------------------------------------------------------------

test("MediaSetup: it loads before the file that resolves the console font", function(t)
    -- core/DebugLogSetup.lua resolves its face EAGERLY at load — lib:New
    -- type-checks the field and raises at construction — so a MediaSetup that
    -- loaded after it would hand the library nil and abort that file entirely.
    local media, debuglog
    for i, rel in ipairs(loader.tocFiles()) do
        if rel == "core/MediaSetup.lua" then media = i end
        if rel == "core/DebugLogSetup.lua" then debuglog = i end
    end
    t.truthy(media, "core/MediaSetup.lua is not in the TOC")
    t.truthy(debuglog, "core/DebugLogSetup.lua is not in the TOC")
    t.truthy(media < debuglog,
        "MediaSetup must load before DebugLogSetup, which resolves its font at load")
end)

-- ---------------------------------------------------------------------------
-- Degraded
-- ---------------------------------------------------------------------------

test("MediaSetup: with no library there is no art and no face, and that is not an error", function(t)
    -- The art and the font are INSIDE the payload that is missing, so a degraded
    -- install has neither. KCM.Icon answering nil is what sends the macro bar's
    -- help button down to its Blizzard rung; KCM.MediaFont answering nil is what
    -- leaves the console on a REAL client font rather than on a dead path.
    local KCM = loader.loadPureDegraded()
    t.eq(KCM.Icon("help"), nil)
    t.eq(KCM.MediaFont("JetBrains Mono"), nil)
end)
