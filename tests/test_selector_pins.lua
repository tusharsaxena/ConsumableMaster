-- tests/test_selector_pins.lua -- the pin merge's whole output, pinned slot by slot.
--
-- tests/test_selector.lua's "Pin merge" cases assert one property each (the pin is
-- first, nothing is lost). These pin the EXACT list Selector's mergePins answers for
-- every shape a bucket's `pins` can take, including the hand-edited ones the UI
-- never writes (MoveUp / MoveDown always store one contiguous 1..N run). They were
-- written before mergePins was split under CCN 15 (GI-CM-02, WowAddonStandards#6)
-- and are the oracle that the split changed nothing.
--
-- Its own suite because tests/test_selector.lua is in layout-section-1's 1000-1500
-- band already.

local h = _G.KCM_TEST
local test = h.test

--- The auto-ranked FOOD list (no pins), and a setter for the bucket's pins that
--- answers the merged list.
local function fixture(t)
    local KCM = h.loader.loadPure()
    local S = KCM.Selector
    S.GetBucket("FOOD").pins = nil
    local base = S.GetEffectivePriority("FOOD")
    t.truthy(#base >= 5, "FOOD ranks at least five candidates (" .. #base .. ")")
    local function merged(pins)
        S.GetBucket("FOOD").pins = pins
        return S.GetEffectivePriority("FOOD")
    end
    return base, merged
end

--- `base` with the ids in `drop` removed, order kept.
local function without(base, drop)
    local skip, out = {}, {}
    for _, id in ipairs(drop) do skip[id] = true end
    for _, id in ipairs(base) do
        if not skip[id] then out[#out + 1] = id end
    end
    return out
end

--- `list` with `id` inserted at 1-based `pos`.
local function insertAt(list, pos, id)
    local out = {}
    for i, v in ipairs(list) do out[i] = v end
    table.insert(out, pos, id)
    return out
end

local function append(list, ...)
    local out = {}
    for i, v in ipairs(list) do out[i] = v end
    for _, v in ipairs({ ... }) do out[#out + 1] = v end
    return out
end

test("Pins: no pins, or an empty array, answer the auto-ranked list", function(t)
    local base, merged = fixture(t)
    t.eqList(merged(nil), base, "nil pins")
    t.eqList(merged({}), base, "an empty pins array")
end)

test("Pins: a pin missing its item, its position or its candidate is dropped", function(t)
    local base, merged = fixture(t)
    t.eqList(merged({
        { position = 1 },
        { itemID = base[3] },
        { itemID = base[4], position = false },
        { itemID = 939999, position = 1 },
    }), base, "every pin inactive: the auto-ranked list as it was")
end)

test("Pins: one pin mid-list lands exactly there, the rest in auto order around it", function(t)
    local base, merged = fixture(t)
    local id = base[#base]
    t.eqList(merged({ { itemID = id, position = 3 } }),
        insertAt(without(base, { id }), 3, id), "slot 3")
end)

test("Pins: pins listed out of position order are placed by position", function(t)
    local base, merged = fixture(t)
    local a, b = base[#base], base[#base - 1]
    local want = insertAt(insertAt(without(base, { a, b }), 2, b), 4, a)
    t.eqList(merged({
        { itemID = a, position = 4 },
        { itemID = b, position = 2 },
    }), want, "b at 2, a at 4")
end)

test("Pins: a pin on the last slot is last", function(t)
    local base, merged = fixture(t)
    local id = base[1]
    t.eqList(merged({ { itemID = id, position = #base } }),
        append(without(base, { id }), id), "position = #list")
end)

test("Pins: overshooting pins follow the list, in position then listing order", function(t)
    local base, merged = fixture(t)
    local a, b, c = base[1], base[2], base[3]
    t.eqList(merged({
        { itemID = a, position = #base + 9 },
        { itemID = b, position = #base + 2 },
        { itemID = c, position = #base + 2 },
    }), append(without(base, { a, b, c }), b, c, a), "b and c tie at +2, a at +9")
end)

-- The collision the UI cannot write: the first listed wins the slot; the loser is
-- never placed at a later slot and lands after every unpinned item.
test("Pins: two pins on one slot -- the first wins it, the second goes to the end", function(t)
    local base, merged = fixture(t)
    local a, b = base[#base], base[#base - 1]
    local want = append(insertAt(without(base, { a, b }), 1, a), b)
    t.eqList(merged({
        { itemID = a, position = 1 },
        { itemID = b, position = 1 },
    }), want, "a first, b last")
end)

-- A position no slot ever equals (zero, negative, fractional) parks at the head of
-- the sorted pins, so every pin behind it is held off its slot too and all of them
-- follow the unpinned items.
test("Pins: a position no slot equals holds every later pin back to the end", function(t)
    local base, merged = fixture(t)
    local a, b, c = base[#base], base[#base - 1], base[#base - 2]
    t.eqList(merged({ { itemID = a, position = 0 } }),
        append(without(base, { a }), a), "position 0")
    t.eqList(merged({ { itemID = a, position = 1.5 } }),
        append(without(base, { a }), a), "position 1.5")
    t.eqList(merged({
        { itemID = b, position = 2 },
        { itemID = a, position = -1 },
        { itemID = c, position = 4 },
    }), append(without(base, { a, b, c }), a, b, c), "-1 sorts first and blocks 2 and 4")
end)

-- One item pinned twice: it is placed at both slots, so the list is one longer.
test("Pins: an item pinned at two slots appears at both", function(t)
    local base, merged = fixture(t)
    local a = base[#base]
    local rest = without(base, { a })
    local want = { a, rest[1], a }
    for i = 2, #rest do want[#want + 1] = rest[i] end
    t.eqList(merged({
        { itemID = a, position = 1 },
        { itemID = a, position = 3 },
    }), want, "slots 1 and 3, length " .. (#base + 1))
end)
