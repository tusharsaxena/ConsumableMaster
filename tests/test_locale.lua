-- tests/test_locale.lua — locales/enUS.lua, and the routing gate over the
-- addon's settings surface.
--
-- KCM.L is an identity table with a key-returning metatable, so a missing
-- translation can never blank a string: an unwrapped literal renders exactly as
-- it always did. That is what makes wrapping safe, and it is also what makes an
-- unwrapped literal invisible — nothing goes wrong at runtime, and only a
-- translator ever finds out.
--
-- THE SHAPE THIS FILE DELIBERATELY DOES NOT HAVE. The obvious locale case is a
-- `gmatch` for `L["…"]` over the sources, checked against the manifest. Four
-- repositories in the collection had one and it is `testing-§12`'s failure mode
-- written out: everything such a scan can find is already wrapped, so the one
-- thing it exists to catch is the one thing it cannot see. This repository never
-- had that case, which is why the settings surface accumulated ninety-odd bare
-- English literals with nothing going red (M4-21, CONSUMABLEMASTER-R-02).
--
-- What is here instead reads the TOC-derived source list for string LITERALS and
-- reports the ones that read as prose and are NOT subscripts of L. Every one of
-- them has to be recorded, with a reason, in the residue register at the foot of
-- this file before the suite goes green — and an entry whose literal has since
-- been wrapped, reworded or deleted is red too, so the register cannot decay
-- into a mute button.
--
-- WHAT IT COVERS, SAID PLAINLY, BECAUSE THE DOCS USED TO OVERCLAIM IT. The scan
-- reads `settings/` and the `modules/KCM*` widgets: the panel composers, the
-- settings CLI registry and the four custom widgets that draw settings-page
-- text. That is the surface `docs/settings-panel.md` makes its routing claim
-- about, and the surface the M4-21 acceptance criterion names. It is NOT the
-- whole addon. `/cm` command output (core/SlashCommands.lua, core/SlashDump.lua)
-- and the seeded category display names (defaults/Categories.lua) are still bare
-- English and are not scanned; that is a known gap this gate does not close and
-- does not pretend to. The gate's job is to stop the settings surface GROWING a
-- new bare literal, and to keep a complete, reasoned inventory of the one it
-- already has.

local h    = _G.KCM_TEST
local test = h.test
local ROOT = _G.KCM_TEST_ROOT or "."

local function readFile(rel)
    local fh = io.open(ROOT .. "/" .. rel, "r")
    if not fh then return nil end
    local body = fh:read("*a")
    fh:close()
    return body
end

-- The scanned surface, DERIVED from the TOC by a rule rather than typed as a
-- list. A hand-maintained list goes stale in the direction that matters: a new
-- settings file is simply never scanned, and the case then reports green over a
-- surface it never looked at. Because this is a rule, a `settings/` file added to
-- the TOC tomorrow is in scope the moment it loads.
local function inScope(rel)
    return rel:match("^settings/") ~= nil or rel:match("^modules/KCM") ~= nil
end

local SOURCES = {}
for _, rel in ipairs(h.loader.tocFiles()) do
    if inScope(rel) then SOURCES[#SOURCES + 1] = rel end
end

-- Lua's own lexer, reduced to the two questions asked here: where does each
-- string literal start, and is it inside an `L[…]` subscript. Each question gets
-- its own function below and `scanLiterals` is left as the dispatch between
-- them, because the one function that answered both was the repository's only
-- complexity warning (M4c-01).
--
-- A `gmatch` for `"…"` cannot be used instead. This repository's comments are
-- prose and quote strings freely, so `body:gmatch('"(.-)"')` reports a paragraph
-- ABOUT a string as a string. The lexer skips comments; where it cannot
-- (long-bracket literals, of which the scanned surface has none) it loses a
-- report rather than inventing one, and that failure direction is the deliberate
-- one.

-- Question one. Given `i` at an opening quote, where does the literal end?
-- Answers with the index of the closing quote — or of the newline or the end of
-- file that ran out first, since an unterminated literal is a syntax error the
-- lint gate catches long before this scan sees the file, and guessing further
-- would only turn one bad file into a bad report about the next one.
local function endOfQuoted(src, i, n)
    local q, j = src:sub(i, i), i + 1
    while j <= n do
        local d = src:sub(j, j)
        if d == "\\" then j = j + 2
        elseif d == q or d == "\n" then break
        else j = j + 1 end
    end
    return j
end

-- Question two. Given `i` at a character that is neither a newline, a comment
-- opener nor a quote, how deep inside an `L[…]` subscript does the scan stand
-- after it? Answers with that depth and the position to resume from.
--
-- The depth tracks the SUBSCRIPT, not the character in front of the quote,
-- because a key is allowed to be built by concatenation across lines —
-- `settings/Category.lua`'s mouseover tooltip is one — and a check on the
-- preceding eight characters calls the second fragment of such a key unrouted.
-- The `L` has to be a whole word, so `AIO_SECTION_LABEL[field]` is not a locale
-- lookup.
local function subscriptDepth(src, i, c, lDepth)
    if lDepth > 0 then
        if c == "[" then return lDepth + 1, i + 1 end
        if c == "]" then return lDepth - 1, i + 1 end
        return lDepth, i + 1
    end
    if c == "L" and src:sub(i - 1, i - 1):match("[%w_]") == nil then
        local open = src:match("^L%s*()%[", i)
        if open then return 1, open + 1 end
    end
    return 0, i + 1
end

local function scanLiterals(src)
    local out, i, n, line, lineStart, lDepth = {}, 1, #src, 1, 1, 0
    while i <= n do
        local c = src:sub(i, i)
        if c == "\n" then
            line, i = line + 1, i + 1
            lineStart = i
        elseif c == "-" and src:sub(i + 1, i + 1) == "-" then
            i = src:find("\n", i, true) or (n + 1)
        elseif c == '"' or c == "'" then
            local j = endOfQuoted(src, i, n)
            out[#out + 1] = {
                text      = src:sub(i + 1, j - 1),
                line      = line,
                wrapped   = lDepth > 0,
                -- `KCM.Debug(tag, fmt, …)` is the debug console's sink, not chat.
                -- Its format strings are developer diagnostics that docs/debug.md
                -- governs and that no translator should ever be shown. Every such
                -- call in the scanned surface opens on the line its format string
                -- sits on, which is what makes the same-line test sufficient.
                debugArg  = src:sub(lineStart, i - 1):find("KCM.Debug(", 1, true) ~= nil,
                statement = src:sub(lineStart, i - 1),
            }
            i = j + 1
        else
            lDepth, i = subscriptDepth(src, i, c, lDepth)
        end
    end
    return out
end

-- Prose, as distinct from an identifier, a pattern, an event name or a path: at
-- least one three-letter run, and two alphabetic words with a space between them.
-- A leading `/` exempts a slash-command SYNTAX literal, which a player types
-- verbatim in every language.
--
-- The floor is honest about what it cannot see. A one-word label — "Reset",
-- "Icon", the hand tag's own "MH" — reads exactly like a table key or an event
-- token to any mechanical test, so this gate does not claim to catch one. It
-- catches the sentences, which is where an unrouted string actually hurts.
local function isProse(s)
    if s:match("^%s*/") then return false end
    return s:find("%a%a%a") ~= nil and s:find("%a+%s+%a+") ~= nil
end

-- ---------------------------------------------------------------------
-- The residue register
-- ---------------------------------------------------------------------
--
-- Every prose literal in the scanned surface that does NOT go through L, with
-- the class that says why. This is a register, not a mute button: the staleness
-- case below fails when an entry stops matching the tree, so a line that gets
-- wrapped, reworded or deleted takes its entry with it.
--
-- The classes, each argued once rather than sixty-nine times:
--
--   DIAGNOSTIC      Reaches chat only when the addon is already broken — it names
--                   a Lua error out of a pcall, a malformed schema row, or a seam
--                   that failed to build. The audience is whoever reads the bug
--                   report, not a player using the addon, and docs/debug.md owns
--                   the wording.
--   VALIDATOR       A `nil, reason` pair a schema validator returns, which
--                   settings/Panel.lua and the `/cm set` path paste into a
--                   DIAGNOSTIC line assembled somewhere else. Keying the clause
--                   alone keys half a sentence and pins the English word order of
--                   the other half.
--   DEGRADED STEM   core/CoreSetup.lua builds ONE degraded-install sentence that
--                   four seams append their own tail to, so a tampered install
--                   says the same thing about WHY and a different thing about
--                   WHAT. The stem is outside the scanned surface; keying a tail
--                   alone keys half a sentence, and keying the stem at each site
--                   would end the sharing that is the point of it.
--   SPLIT COLOR     The sentence's spans carry different colors mid-line, so one
--                   key would have to carry `|c…|r` inside translatable text and
--                   would depend on the color stack restoring the outer span — a
--                   rendering question no headless case can settle. Keying the
--                   spans separately re-creates exactly the word-order-pinning
--                   fragments this collection has spent the cycle removing.
--   FRAGMENT        A word or clause substituted into a format string at the call
--                   site. Keying it alone keys an English word into an English
--                   sentence's grammar.
--   LIB DESCRIPTOR  A field crossing to LibKa0s. A library descriptor must never
--                   be handed KCM.L (LIBKA0S-05, "the L trap"), and the slash
--                   override table is resolved through `rawget` precisely so a
--                   key-echoing locale table falls through — so KCM.L could not
--                   supply these even if it were passed. A translator restores
--                   them by handing the descriptor a PLAIN table of just these
--                   keys; locales/enUS.lua records that.
--   DEAD            Kept as a record of the wording it was meant to restore. The
--                   library's own parsers read lib.STRINGS directly and never
--                   pass through Sl:Text, so an instance override cannot reach
--                   them (LIBKA0S-09, issue #16). Routing a string nothing
--                   renders is noise.
--   CLI SURFACE     A `/cm` verb description or reply. `/cm` prints these
--                   seventeen verbs and core/SlashCommands.lua's five
--                   sub-command tables through one lib.FormatRow, and four
--                   fifths of that listing lives outside the scanned surface.
--                   Routing this fifth alone would split one help listing
--                   between two locales; the command surface is one decision,
--                   and it is not this one.
--   NOT YET ROUTED  A plain user-facing sentence in a settings page that would
--                   route cleanly and simply has not been. M4-21 scoped this
--                   repository's routing to the six widget labels
--                   CONSUMABLEMASTER-R-02 names; these are the rest of the
--                   settings surface's chat text. They are listed in full and by
--                   name so the size of the gap is a number a reader can act on
--                   rather than an impression, and so that routing one is a
--                   two-line change that this file notices.
--   DEBUG SCOPE     The scope a bulk act names in its one debug-console line,
--                   `[Set] <act> <scope>: N rows` (debug-logging-§10), handed to
--                   Helpers.Bulk rather than to KCM.Debug on the same line, which
--                   is the only reason the debug-sink exemption above cannot see
--                   it. Same audience and same owner as a KCM.Debug format:
--                   developer diagnostics docs/debug.md governs, never chat.
local RESIDUE = {
    -- settings/Panel.lua
    {"settings/Panel.lua", "|cff808080cannot open settings during combat — Blizzard's category-switch is protected|r",
     "NOT YET ROUTED"},
    {"settings/Panel.lua", "|cffff0000schema error|r: ", "DIAGNOSTIC"},
    {"settings/Panel.lua", "<no path>", "DIAGNOSTIC"},
    {"settings/Panel.lua", "row is not a table", "DIAGNOSTIC"},
    {"settings/Panel.lua", "missing or empty `path`", "DIAGNOSTIC"},
    {"settings/Panel.lua", ", so the settings panel is unavailable, and so are /cm list, ", "DEGRADED STEM"},
    {"settings/Panel.lua", "the list.", "DEGRADED STEM"},
    {"settings/Panel.lua", "in combat — Defaults is blocked until combat ends.", "NOT YET ROUTED"},
    {"settings/Panel.lua", "defaults action failed: ", "DIAGNOSTIC"},
    {"settings/Panel.lua", "onChange for ", "DIAGNOSTIC"},
    {"settings/Panel.lua", "button onClick failed: ", "DIAGNOSTIC"},
    {"settings/Panel.lua", "expected boolean", "VALIDATOR"},
    {"settings/Panel.lua", "expected number", "VALIDATOR"},
    {"settings/Panel.lua", "expected string", "VALIDATOR"},
    {"settings/Panel.lua", "allowed values: ", "VALIDATOR"},
    {"settings/Panel.lua", "expected color table", "VALIDATOR"},
    {"settings/Panel.lua", "invalid value for ", "DIAGNOSTIC"},
    {"settings/Panel.lua", "value must not be nil", "VALIDATOR"},
    {"settings/Panel.lua", "expected true or false for ", "VALIDATOR"},
    {"settings/Panel.lua", "expected a list", "VALIDATOR"},
    {"settings/Panel.lua", "expected a table", "VALIDATOR"},
    {"settings/Panel.lua", "settings tab '", "DIAGNOSTIC"},
    {"settings/Panel.lua", "settings panel unavailable on this client; use /cm.", "NOT YET ROUTED"},

    -- settings/General.lua
    {"settings/General.lua", "in combat — %s deferred until regen.", "FRAGMENT"},
    {"settings/General.lua", "macro writes", "FRAGMENT"},
    {"settings/General.lua", "rewrote all macros. If action bar icons still look stale, /reload to force the bars to refresh.",
     "NOT YET ROUTED"},
    {"settings/General.lua", "Consumable Master", "LIB DESCRIPTOR"},
    {"settings/General.lua", "macro bar position reset.", "NOT YET ROUTED"},
    {"settings/General.lua", "Master enable ", "SPLIT COLOR"},
    {"settings/General.lua", "General page", "DEBUG SCOPE"},

    -- settings/MacroBar.lua
    {"settings/MacroBar.lua", "macro bar slot order reset.", "NOT YET ROUTED"},
    {"settings/MacroBar.lua", "Macro Bar page", "DEBUG SCOPE"},

    -- settings/Category.lua
    {"settings/Category.lua", "icon-button onClick failed: ", "DIAGNOSTIC"},
    {"settings/Category.lua", "unknown spellID: ", "NOT YET ROUTED"},
    {"settings/Category.lua", "unknown itemID: ", "NOT YET ROUTED"},
    {"settings/Category.lua", "expected a positive numeric ID or a pasted link; got: ", "NOT YET ROUTED"},
    {"settings/Category.lua", "spec-aware category: no active spec — can't add.", "NOT YET ROUTED"},

    -- settings/Slash.lua — the seventeen verb descriptions and their replies.
    {"settings/Slash.lua", "Show this help", "CLI SURFACE"},
    {"settings/Slash.lua", "Open the settings panel", "CLI SURFACE"},
    {"settings/Slash.lua", "Settings panel unavailable.", "CLI SURFACE"},
    {"settings/Slash.lua", "Print addon version", "CLI SURFACE"},
    {"settings/Slash.lua", "A/B performance capture — `/cm perf` opens the step panel", "CLI SURFACE"},
    {"settings/Slash.lua", "perf capture unavailable.", "CLI SURFACE"},
    {"settings/Slash.lua", "Toggle the debug window; `on`/`off` set logging — `/cm debug [on|off]`", "CLI SURFACE"},
    {"settings/Slash.lua", "Debug console unavailable.", "CLI SURFACE"},
    {"settings/Slash.lua", "Force macros to resync from bags", "CLI SURFACE"},
    {"settings/Slash.lua", "in combat — picks computed now; macro writes will apply when combat ends.", "CLI SURFACE"},
    {"settings/Slash.lua", "auto-discovery found %d new item(s)", "CLI SURFACE"},
    {"settings/Slash.lua", "recomputed all categories.", "CLI SURFACE"},
    {"settings/Slash.lua", "Force a full rewrite of every KCM macro (icon + body)", "CLI SURFACE"},
    {"settings/Slash.lua", "rewrote all macros (body + icon). If action bar icons still look stale, /reload to force the bars to refresh.",
     "CLI SURFACE"},
    {"settings/Slash.lua", "Reset ONE setting to its default — `/cm reset <path>`", "CLI SURFACE"},
    {"settings/Slash.lua", "Reset every priority list and stat override to defaults (asks first)", "CLI SURFACE"},
    {"settings/Slash.lua", "StaticPopup unavailable.", "CLI SURFACE"},
    {"settings/Slash.lua", "List every schema setting and its current value", "CLI SURFACE"},
    {"settings/Slash.lua", "Print a setting's current value — `/cm get <path>`", "CLI SURFACE"},
    {"settings/Slash.lua", "Set a setting — `/cm set <path> <value>` (try /cm list)", "CLI SURFACE"},
    {"settings/Slash.lua", "Macro bar — `/cm bar [on|off|lock|unlock|reset]` (bare toggles it)", "CLI SURFACE"},
    {"settings/Slash.lua", "Per-category priority list editor — try `/cm priority` for the list", "CLI SURFACE"},
    {"settings/Slash.lua", "Per-spec stat priority editor — try `/cm stat` for the list", "CLI SURFACE"},
    {"settings/Slash.lua", "Composite-category editor (HP_AIO, MP_AIO) — try `/cm aio` for the list", "CLI SURFACE"},
    {"settings/Slash.lua", "expected a comma-separated list of keys", "VALIDATOR"},
    {"settings/Slash.lua", "expected KEY=on|off pairs, comma-separated", "VALIDATOR"},
    {"settings/Slash.lua", "edited with %s, not with /cm set", "VALIDATOR"},
    {"settings/Slash.lua", "Dump internal state — try `/cm dump` for the list", "CLI SURFACE"},

    -- settings/Slash.lua — SLASH_STRINGS, the LibKa0s-Slash override table.
    {"settings/Slash.lua", "|cffffd100Ka0s Consumable Master|r v%s \\226\\128\\148 slash commands", "LIB DESCRIPTOR"},
    {"settings/Slash.lua", "Unknown command: |cffffff00%s|r", "LIB DESCRIPTOR"},
    {"settings/Slash.lua", "Usage: %s get <path>  (try /cm list)", "LIB DESCRIPTOR"},
    {"settings/Slash.lua", "Usage: %s reset <path> \\226\\128\\148 this resets ONE setting. ", "LIB DESCRIPTOR"},
    {"settings/Slash.lua", "The old global wipe is now |cffffff00/cm resetall|r, ", "LIB DESCRIPTOR"},
    {"settings/Slash.lua", "which still asks before it wipes.", "LIB DESCRIPTOR"},
    {"settings/Slash.lua", "expected true/false/on/off/1/0", "DEAD"},
    {"settings/Slash.lua", "Allowed values: %s", "DEAD"},
    {"settings/Slash.lua", "expected: r g b [a] (each 0-1 or 0-255)", "DEAD"},

    -- settings/Slash.lua — the degraded dispatcher's notice.
    {"settings/Slash.lua", "The LibKa0s library is missing", "DEGRADED STEM"},
    {"settings/Slash.lua", ", so /cm help, list, get, set and reset are unavailable. ", "DEGRADED STEM"},
    {"settings/Slash.lua", "These still work: ", "DEGRADED STEM"},
}

local CLASSES = {
    ["DIAGNOSTIC"] = true, ["VALIDATOR"] = true, ["DEGRADED STEM"] = true,
    ["SPLIT COLOR"] = true, ["FRAGMENT"] = true, ["LIB DESCRIPTOR"] = true,
    ["DEAD"] = true, ["CLI SURFACE"] = true, ["NOT YET ROUTED"] = true,
    ["DEBUG SCOPE"] = true,
}

-- ---------------------------------------------------------------------
-- The scan
-- ---------------------------------------------------------------------

-- Per file: what it routes, what it leaves bare, and how much it was read.
local routedIn, unrouted, exempted = {}, {}, {}
local scannedLiterals, routedCount, unroutedCount = 0, 0, 0

for _, rel in ipairs(SOURCES) do
    -- Hard assert rather than a tolerant skip. A source the scan cannot open is a
    -- surface it did not look at, and a gate that goes quiet when it cannot look
    -- is worse than no gate at all.
    local body = assert(readFile(rel), rel .. " is unreadable")
    local lits = scanLiterals(body)

    routedIn[rel] = {}
    for _, lit in ipairs(lits) do
        if lit.wrapped then routedIn[rel][lit.text] = lit.line end
    end

    for _, lit in ipairs(lits) do
        scannedLiterals = scannedLiterals + 1
        if lit.wrapped then
            routedCount = routedCount + 1
        elseif not lit.debugArg and isProse(lit.text) then
            -- THE JOIN-KEY EXEMPTION. A bare literal whose exact text is ALSO
            -- routed through L in the same file is a join key for that label, not
            -- a second piece of prose: `settings/MacroBar.lua` writes
            -- `{ group = "Bar appearance", label = L["Bar appearance"] }` and every
            -- row on the page names its group by that same English string.
            -- Reporting it would be asking for `group = L["Bar appearance"]`, which
            -- makes the join key depend on the locale and silently unjoins every
            -- row on a translated client. The exemption exists only BECAUSE the
            -- visible copy is routed, which is what the fence case below checks.
            if routedIn[rel][lit.text] then
                exempted[#exempted + 1] = { file = rel, text = lit.text, line = lit.line }
            else
                unrouted[rel] = unrouted[rel] or {}
                if not unrouted[rel][lit.text] then
                    unrouted[rel][lit.text] = lit.line
                    unroutedCount = unroutedCount + 1
                end
            end
        end
    end
end

-- The register in the same shape, so both directions are a lookup.
local recorded = {}
for _, entry in ipairs(RESIDUE) do
    recorded[entry[1]] = recorded[entry[1]] or {}
    recorded[entry[1]][entry[2]] = entry[3]
end

-- ---------------------------------------------------------------------
-- The seam itself
-- ---------------------------------------------------------------------

test("Locale: KCM.L is published as a table", function(t)
    local KCM = h.loader.loadPure()
    t.truthy(KCM.L, "KCM.L exists")
    t.eq(type(KCM.L), "table", "KCM.L is a table")
end)

test("Locale: an unknown key falls back to itself verbatim", function(t)
    local KCM = h.loader.loadPure()
    -- The fallback is what makes wrapping safe and what makes an unwrapped
    -- literal invisible; both halves of this file rest on it.
    t.eq(KCM.L["a string nobody translated"], "a string nobody translated",
        "an unset key returns the key")
    t.eq(KCM.L["%s in bags    %s not in bags"], "%s in bags    %s not in bags",
        "the fallback preserves format conversions")
end)

test("Locale: the enUS manifest carries only entries that differ from their key", function(t)
    local KCM = h.loader.loadPure()
    -- enUS is identity by construction, so a row written into the table can only
    -- be there to make a display string differ from its lookup key. An identity
    -- row is a row the metatable already answers, and it would go stale silently.
    for k, v in pairs(KCM.L) do
        t.eq(type(v), "string", ("manifest entry %q holds a string"):format(tostring(k)))
        t.truthy(v ~= k,
            ("manifest entry %q is identity — the metatable already answers it"):format(tostring(k)))
    end
end)

-- ---------------------------------------------------------------------
-- The routing gate
-- ---------------------------------------------------------------------

test("Locale: the literal scan reads the settings surface it is meant to guard", function(t)
    -- The guard on the guard. A lexer that silently matched nothing would make
    -- every case below pass over a surface full of bare English, which is the
    -- exact failure this file was written to end.
    t.truthy(#SOURCES >= 7,
        ("the TOC put %d files in the scanned surface"):format(#SOURCES))
    t.truthy(scannedLiterals > 700,
        ("the scan read %d string literals across them"):format(scannedLiterals))
    t.truthy(routedCount > 200,
        ("and found %d of them routed through L"):format(routedCount))
    t.truthy(unroutedCount > 0,
        "and still reports the known residue rather than an empty set")
end)

test("Locale: every user-facing literal in the settings surface is routed or recorded", function(t)
    -- THE ACCEPTANCE CASE. A bare prose literal added to a settings file is red
    -- here, named by file, line and text, until it is either wrapped in L or
    -- given a class in the register above.
    for rel, texts in pairs(unrouted) do
        for text, line in pairs(texts) do
            t.truthy(recorded[rel] and recorded[rel][text] ~= nil,
                ("%s:%d: %q is user-facing text that neither goes through L nor is "
                 .. "recorded as residue in tests/test_locale.lua"):format(rel, line, text))
        end
    end
end)

test("Locale: every recorded residue literal is still unrouted in the file that names it", function(t)
    -- The direction that keeps the register from becoming a mute button: an entry
    -- whose literal was wrapped, reworded or deleted goes red here rather than
    -- sitting on as a license for a string that no longer exists.
    for _, entry in ipairs(RESIDUE) do
        local rel, text = entry[1], entry[2]
        local found = unrouted[rel] and unrouted[rel][text]
        t.truthy(found,
            ("%s no longer holds the unrouted literal %q — drop its residue entry")
                :format(rel, text))
    end
end)

test("Locale: every residue entry carries one of the declared classes", function(t)
    -- A free-text reason decays into a shrug. The class is the argument, it is
    -- written out once above, and a new entry has to pick one of them or say why
    -- a tenth class exists.
    for _, entry in ipairs(RESIDUE) do
        t.truthy(CLASSES[entry[3]],
            ("%s: %q is filed under %q, which is not a declared class")
                :format(entry[1], entry[2], tostring(entry[3])))
    end
end)

test("Locale: the join-key exemption only ever covers a string the same file routes", function(t)
    -- The fence around the one exemption the scan makes for itself. Re-derived by
    -- a DIFFERENT mechanism than the one that granted it -- a plain gmatch for the
    -- single-line `L["…"]` form, rather than the lexer's bracket depth -- because a
    -- fence built out of the same table it is fencing asserts nothing. An
    -- exempted literal is exempt BECAUSE its visible copy is routed a line away,
    -- so this also cross-checks the lexer against the naive reading on every
    -- string the two can both see.
    t.truthy(#exempted > 0, "the exemption is live rather than theoretical")
    local byGmatch = {}
    for _, rel in ipairs(SOURCES) do
        byGmatch[rel] = {}
        for key in assert(readFile(rel)):gmatch('L%[%s*"(.-)"%s*%]') do
            byGmatch[rel][key] = true
        end
    end
    for _, e in ipairs(exempted) do
        t.truthy(byGmatch[e.file] and byGmatch[e.file][e.text],
            ("%s:%d: %q was exempted as a join key without a routed label to join to")
                :format(e.file, e.line, e.text))
    end
end)

test("Locale: the two custom widgets route their labels through L", function(t)
    -- CONSUMABLEMASTER-R-02. Both files draw into a FontString, so the headless
    -- suite cannot read what the player sees; what it can hold is that the six
    -- labels are still subscripts of L rather than literals. The hand tag's three
    -- keys are below the prose floor above and would not be caught by the scan,
    -- which is exactly why they are pinned by name here.
    local expected = {
        ["modules/KCMMacroDragIcon.lua"] = { "Macro not created yet", "Drag to action bar" },
        ["modules/KCMItemRow.lua"]       = { "MH+OH", "MH", "OH", "[Loading]" },
    }
    for rel, keys in pairs(expected) do
        local routed = routedIn[rel]
        t.truthy(routed, rel .. " is inside the scanned surface")
        for _, key in ipairs(keys or {}) do
            t.truthy(routed and routed[key],
                ("%s draws %q through L"):format(rel, key))
        end
    end
end)

test("Locale: the color escapes on the drag-icon labels stay outside the key", function(t)
    -- The half of CONSUMABLEMASTER-R-02 a routing check alone would miss. A
    -- translator must never have to carry `|c…|r` through a translation, so the
    -- key is the sentence and the escapes are concatenated around it.
    local body = assert(readFile("modules/KCMMacroDragIcon.lua"))
    for _, key in ipairs({ "Macro not created yet", "Drag to action bar" }) do
        t.falsy(body:find('L%["|c[^"]*' .. key),
            ("%q is keyed without its color escape"):format(key))
    end
    t.truthy(body:find('"|cff999999" .. L["Macro not created yet"] .. "|r"', 1, true),
        "the disabled label concatenates gray around its key")
    t.truthy(body:find('"|cffffd100" .. L["Drag to action bar"] .. "|r"', 1, true),
        "the enabled label concatenates gold around its key")
end)
