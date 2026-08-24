-- core/EnvSetup.lua — the LibKa0s-Env-1.0 seam: where this addon reads its own
-- TOC manifest (library-stack-§7).
--
-- ---------------------------------------------------------------------------
-- WHAT THIS REPLACED
-- ---------------------------------------------------------------------------
--
-- Two inline C_AddOns ladders, neither of them in core/Compat.lua and so neither
-- of them findable by any audit of the shim file: the version read behind the
-- `/cm version` verb and the help header (settings/Slash.lua), and the About
-- page's addon-notes read (settings/Panel.lua). The metadata reader was written
-- ELEVEN times across nine addons before the library carried it — six copies in
-- a core/Compat.lua in four spellings, and five more inlined at the call site
-- like these two. Not one of the eleven behaved differently from any other,
-- which is what made it the library's business rather than this addon's.
--
-- core/Compat.lua KEEPS everything it has. It never held a metadata shim, and
-- what it does hold — the spec and spell namespace migration — is a live client
-- transition rather than a copy of anybody else's file.
--
-- ---------------------------------------------------------------------------
-- WHY THE LIBRARY HAS TO BE TOLD OUR NAME
-- ---------------------------------------------------------------------------
--
-- Same reason core/MediaSetup.lua passes it: LibKa0s is VENDORED, so a copy
-- cannot know which addon folder it sits in. `addonName` is the FIRST VARARG
-- every TOC-loaded file gets — not KCM.PREFIX, not the `## Title`, and not a
-- hand-typed literal. Here those read "ConsumableMaster", "[CM]" and "Consumable
-- Master", and only the first is the folder.
--
-- The literal is the reason this seam is worth a file rather than a tidy-up:
-- settings/Panel.lua asked for `"ConsumableMaster"` as a string, one rename away
-- from reading a manifest that is not ours. A wrong name answers nil and raises
-- nothing, so the About page would simply have gone quietly blank.
--
-- ---------------------------------------------------------------------------
-- WHY THE FALLBACKS ARE WRITTEN OUT RATHER THAN LEFT TO ANSWER nil
-- ---------------------------------------------------------------------------
--
-- Because this is a seam, not a feature. An install missing LibKa0s must get
-- exactly what this addon got before the library existed, so each helper below
-- repeats the ladder its inline copy ran. Nothing here resolves at load beyond
-- the LibStub lookup, which is why this file's TOC position is conventional —
-- unlike core/MediaSetup.lua's, which is load-bearing.
--
-- ---------------------------------------------------------------------------
-- WHAT THE SEAM MUST NOT CHANGE
-- ---------------------------------------------------------------------------
--
-- Any answer. Both inline copies already agreed with the library rung for rung,
-- so a difference in what comes back here is a defect in the adoption rather
-- than an improvement. tests/test_envsetup.lua pins it on both arms.

local addonName, NS = ...
local KCM = NS

local Env = LibStub and LibStub("LibKa0s-Env-1.0", true)

--- One field of this addon's TOC manifest, or nil.
---
--- NIL IS A REAL ANSWER, twice over: the library may be absent AND the client may
--- expose no reader at all, which is what a headless run looks like. A field the
--- TOC does not carry also answers nil on a perfectly healthy client. Callers
--- that need a value supply their own — settings/Panel.lua's `or ""`.
---
--- @param field string  a TOC key: "Version", "Title", "Notes", "Author", …
--- @return string|nil
function KCM.Meta(field)
    if Env then return Env.GetAddOnMetadata(addonName, field) end
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(addonName, field)
    end
    if GetAddOnMetadata then
        return GetAddOnMetadata(addonName, field)
    end
    return nil
end

--- This addon's version string, preferring the TOC over the in-code constant.
--- Never nil.
---
--- The fallback stays visible HERE rather than inside the library because which
--- constant this addon falls back to is genuinely its own business — and because
--- a packaged addon whose TOC can be read should never report the constant
--- somebody forgot to edit (slash-commands-§3).
---
--- `KCM.VERSION` is read at CALL time rather than captured as an upvalue.
--- core/Namespace.lua publishes it and loads earlier, so an upvalue would work
--- today; reading it live is what keeps that ordering from becoming a second
--- thing this file depends on.
---
--- @return string
function KCM.Version()
    if Env then return Env.Version(addonName, KCM.VERSION) or "?" end
    local v = KCM.Meta("Version")
    if v and v ~= "" then return v end
    return KCM.VERSION or "?"
end
