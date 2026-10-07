-- tests/test_envsetup.lua — core/EnvSetup.lua: the LibKa0s-Env-1.0 seam.
--
-- What is asserted here is THE SEAM, not the library. LibKa0s' own suite covers
-- the ladder inside GetAddOnMetadata, and a second copy of those cases here is
-- exactly the consumer-side duplication testing-§8 forbids. What only this repo
-- can check is that this addon's two helpers answer what its two inline copies
-- answered — including the one in settings/Panel.lua that asked for the addon
-- folder by hardcoded literal — and that they still answer with the library
-- absent.

local h = _G.KCM_TEST
local test = h.test
local loader = h.loader

test("EnvSetup: KCM.Meta reads THIS addon's TOC", function(t)
    local KCM = loader.loadPure()
    t.eq(KCM.Meta("Title"), "Consumable Master", "the fixture manifest, read by folder name")
end)

test("EnvSetup: KCM.Version prefers the TOC over the in-code constant", function(t)
    local KCM = loader.loadPure()
    -- Which is the whole reason the seam reads the manifest at all: a packaged
    -- addon whose TOC can be read must never report the constant somebody forgot
    -- to edit. The fixture carries no Version by default (tests/wow_mock.lua says
    -- why), so this case supplies one for its own duration.
    local saved = loader.mock.metadata.ConsumableMaster.Version
    loader.mock.metadata.ConsumableMaster.Version = "9.9.9-toc"
    local v = KCM.Version()
    loader.mock.metadata.ConsumableMaster.Version = saved
    t.eq(v, "9.9.9-toc", "the TOC wins over KCM.VERSION")
end)

test("EnvSetup: KCM.Version falls back to this addon's own constant", function(t)
    local KCM = loader.loadPure()
    -- The fallback lives at the call site rather than in the library, so proving
    -- it still works is the seam's job. Reached by removing C_AddOns, the only
    -- reader any admitted client has, which is what a client that cannot answer
    -- looks like.
    local savedC = _G.C_AddOns
    _G.C_AddOns = nil
    local v = KCM.Version()
    _G.C_AddOns = savedC
    t.eq(v, KCM.VERSION, "KCM.VERSION, never nil — it goes straight into the /cm banner")
end)

test("EnvSetup: the seam still answers with LibKa0s absent", function(t)
    -- A real degraded load, not a hand-stubbed one: libs/LibKa0s/ is simply not
    -- loaded and core/EnvSetup.lua runs its own ladder for real (testing-§8).
    local KCM = loader.loadPureDegraded()
    t.eq(type(KCM.Meta), "function", "KCM.Meta survives a degraded load")
    t.eq(type(KCM.Version), "function", "KCM.Version survives a degraded load")
    t.eq(KCM.Meta("Notes"), "A fixture.", "and still reads this addon's own TOC")
    t.eq(KCM.Version(), KCM.VERSION, "and still answers a version string")
end)

test("EnvSetup: Meta never reads the bare GetAddOnMetadata global", function(t)
    -- red under: the bare-global rung
    -- The library-absent ladder is two rungs: LibKa0s-Env, then
    -- C_AddOns.GetAddOnMetadata, else nil. The bare global left the client with
    -- the 11.0 AddOns purge, so no admitted client (## Interface 120100) can
    -- reach a third rung; one planted here must never be asked.
    local KCM = loader.loadPureDegraded()
    local calls = 0
    local savedC, savedG = _G.C_AddOns, _G.GetAddOnMetadata
    _G.C_AddOns = nil
    _G.GetAddOnMetadata = function()
        calls = calls + 1
        return "from the bare global"
    end
    local v = KCM.Meta("Title")
    _G.C_AddOns, _G.GetAddOnMetadata = savedC, savedG
    t.eq(calls, 0, "the bare GetAddOnMetadata global is never called")
    t.eq(v, nil, "Env and C_AddOns absent: Meta answers nil")
end)

test("EnvSetup: Notes comes through the seam, not a hardcoded folder name", function(t)
    local KCM = loader.loadPure()
    -- settings/Panel.lua asked C_AddOns for "ConsumableMaster" as a string
    -- literal. The mock's manifest is keyed by name and answers "" for any other,
    -- so a literal that drifts from the folder shows up here instead of in a
    -- silently empty About page.
    t.eq(KCM.Meta("Notes"), "A fixture.")
end)
