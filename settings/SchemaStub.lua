-- settings/SchemaStub.lua — the LibKa0s-Schema-1.0 degradation stub.
--
-- settings/Panel.lua builds the settings write seam as
--     LibStub("LibKa0s-Schema-1.0", true) or KCM.SchemaStub
-- and this file is the right-hand side: what the seam is on a load where the
-- library is absent. It is the stub LibKa0s docs/api/Schema/version-2-docs.md
-- prescribes under "The degradation stub", copied from that repo's
-- tests/test_schema.lua `referenceStub` and trimmed to what this addon calls.
--
-- A DELIBERATE, DOCUMENTED DUPLICATION. The Schema major is reached by host
-- writers that never needed Options or Slash -- `/cm bar on|off`, `/cm enable`,
-- the global reset and the macro bar's own writes all go through KCM.Schema:Set
-- -- and slash-commands-§1 keeps those verbs working without the library. A stub
-- that refused `Set` would leave every one of them dead on exactly the load it
-- exists to survive (anti-pattern #56, shape 2). So it is WRITE-COMPLETING and
-- LOG-SILENT: reads, writes, `normalize`, the reaction, the announce and the
-- sweep veto all work; the `[Set]` line, the bracket's tally and the profile
-- reset's count do not, because the degraded DebugLog stub discards those lines
-- anyway.
--
-- `writeThrough` is honored because the library honors it, but this addon hands
-- the seam no list yet (CM-18). tests/test_surface_parity.lua pins this stub's
-- surface against a live instance and its library half against the major by
-- name, so a member the major grows fails there first.

local _, NS = ...
local KCM = NS

local BRAND = "ConsumableMaster"

local stubLib = {}

local function copy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = copy(x) end
    return out
end

-- The primitives, lib level: a host whose own code calls them keeps one seam.
function stubLib.SplitPath(path)
    local parts = {}
    if path ~= nil then
        for seg in tostring(path):gmatch("[^%.]+") do parts[#parts + 1] = seg end
    end
    return parts
end

local function partsOf(p) return type(p) == "table" and p or stubLib.SplitPath(p) end

function stubLib.Read(root, p, first)
    local parts, node = partsOf(p), root
    first = first or 1
    if type(root) ~= "table" or #parts < first then return nil end
    for i = first, #parts do
        if type(node) ~= "table" then return nil end
        node = node[parts[i]]
    end
    return node
end

function stubLib.Write(root, p, value, first)
    local parts, node = partsOf(p), root
    first = first or 1
    if type(root) ~= "table" or #parts < first then return end
    for i = first, #parts - 1 do
        if type(node[parts[i]]) ~= "table" then node[parts[i]] = {} end
        node = node[parts[i]]
    end
    node[parts[#parts]] = value
end

function stubLib.SameValue(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do if not stubLib.SameValue(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

-- The instance's read half and its registry: rows held by reference, a linear
-- first-match FindRow, Reindex a no-op.
local function addRegistry(S, d)
    local rows = d.rows
    function S.AllRows() return rows end
    function S.FindRow(path)
        if type(path) ~= "string" then return nil end
        for _, row in ipairs(rows) do
            if type(row) == "table" and row.path == path then return row end
        end
    end
    function S.AddRows(list, at)
        if type(list) ~= "table" then return 0 end
        at = type(at) == "number" and math.floor(at) or #rows + 1
        if at > #rows + 1 then at = #rows + 1 elseif at < 1 then at = 1 end
        for i, row in ipairs(list) do table.insert(rows, at + i - 1, row) end
        return #list
    end
    function S.Reindex() end
end

local function resolver(d)
    return function(parts, id)
        if type(d.resolveRoot) ~= "function" then return nil end
        return d.resolveRoot(parts, id)
    end
end

-- The write seam's order without its log and tally: refuse (a listed
-- writeThrough path is not refused), validate, normalize, the missing root.
-- Answers a plan, or nil and the refusal; Set and SetMany share it.
local function preparer(S, resolve, through)
    local function refuse(path, why) return nil, BRAND .. ": invalid value for " .. path, why end
    return function(path, value, id)
        local row = S.FindRow(path) or through[path]
        if not row then return nil, BRAND .. ": no setting " .. tostring(path) end
        local w = { row = row, path = path, value = value, rid = id }
        w.stored = type(row.set) ~= "function" and not row.sessionOnly
        if w.stored then
            w.parts = stubLib.SplitPath(path)
            local r, f, got = resolve(w.parts, id)
            if type(r) == "table" then w.root, w.first = r, f end
            if got ~= nil then w.rid = got end
        end
        if type(row.validate) == "function" then
            local ok, why = row.validate(value, w.rid)
            if not ok then return refuse(path, why) end
        end
        if type(row.normalize) == "function" then
            local out, why = row.normalize(value, w.rid)
            if out == nil then return refuse(path, why) end
            w.value = out
        end
        if w.stored and not w.root then return nil, BRAND .. ": nowhere to store " .. path end
        return w
    end
end

local function store(w)
    if type(w.row.set) == "function" then
        w.row.set(w.value)
    elseif w.stored then
        stubLib.Write(w.root, w.parts, copy(w.value), w.first)
    end
end

local function react(w)
    if type(w.row.onChange) == "function" then w.row.onChange(w.value, w.rid) end
end

local function addWrites(S, d, prepare)
    function S.Set(path, value, id)
        local w, err, why = prepare(path, value, id)
        if not w then return false, err, why end
        store(w)
        react(w)
        if type(d.announce) == "function" then d.announce(w.row, path, w.value, w.rid) end
        return true
    end
    -- All or nothing, as the library's: every entry prepared, then every store,
    -- every onChange, and one announceBatch (or announce per write). `act` is
    -- not read -- there is no line to make one of.
    function S.SetMany(entries, opts)
        local id = type(opts) == "table" and opts.instanceId or nil
        local ws = {}
        for i, e in ipairs(type(entries) == "table" and entries or {}) do
            if type(e) ~= "table" then e = {} end
            local w, err, why = prepare(e.path, e.value, id)
            if not w then return false, err, why, i end
            ws[i] = w
        end
        for _, w in ipairs(ws) do store(w) end
        for _, w in ipairs(ws) do react(w) end
        if #ws == 0 then return true end
        if type(d.announceBatch) == "function" then
            d.announceBatch(ws, ws[1].rid)
        elseif type(d.announce) == "function" then
            for _, w in ipairs(ws) do d.announce(w.row, w.path, w.value, w.rid) end
        end
        return true
    end
    function S.Default(path)
        local row = S.FindRow(path)
        return row and copy(row.default)
    end
end

-- The bracket keeps its depth, because ApplyDefault's sweep veto reads it; it
-- counts nothing and logs nothing.
local function addBracket(S, d)
    local depth = 0
    function S.ApplyDefault(row, id)
        if type(row) ~= "table" or type(row.path) ~= "string" or row.default == nil then return false end
        local exempt = d.resetExempt
        if depth > 0 and type(exempt) == "table" and exempt[row.path] then return false end
        return S.Set(row.path, copy(row.default), id)
    end
    function S.BulkBegin() depth = depth + 1 end
    function S.BulkEnd() if depth > 0 then depth = depth - 1 end end
    function S.BulkRun(act, scope, fn)
        S.BulkBegin(act, scope)
        local ok, err = pcall(fn, { profileReset = false })
        S.BulkEnd(act, scope)
        if not ok then error(err, 0) end
    end
    function S.BulkAdd() end
    function S.InBulk() return depth > 0 end
    function S.CountOffDefault() return 0 end
    function S.ResetCounted(fn) fn() end
    function S.ConsumeResetCount() return nil end
    function S.Validate()
        if type(d.print) == "function" then
            d.print(BRAND .. ": LibKa0s-Schema-1.0 is missing, so the schema was not checked")
        end
        return 0, 0, 0
    end
end

-- Colon-called, like every major's constructor; the stub library is `self`.
function stubLib.New(_, d)
    local S = {}
    local through = {}
    for _, p in ipairs(type(d.writeThrough) == "table" and d.writeThrough or {}) do
        if type(p) == "string" and p ~= "" then through[p] = { path = p, writeThrough = true } end
    end
    local resolve = resolver(d)
    addRegistry(S, d)
    function S.Get(path, id)
        local row = S.FindRow(path)
        if row and type(row.get) == "function" then return row.get(id) end
        if type(path) ~= "string" or (row and row.sessionOnly) then return nil end
        local parts = stubLib.SplitPath(path)
        local root, first = resolve(parts, id)
        if type(root) ~= "table" then return nil end
        return stubLib.Read(root, parts, first)
    end
    addWrites(S, d, preparer(S, resolve, through))
    addBracket(S, d)
    return S
end

KCM.SchemaStub = stubLib
