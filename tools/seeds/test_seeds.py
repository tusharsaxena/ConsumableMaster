"""Tests for tools/seeds/seeds.py (issue #49). No network: every case builds a tiny fixture build
(a handful of CSV rows, gzipped like a bundle's raw/) and a tiny seed file in a temp dir. The repo
cases at the end read the real defaults/ and the newest bundles, so a re-derive that leaves a key
unruled, or a seed file the reader stops understanding, fails here.

Run: python3 -m pytest -q tools/seeds   (or python3 -m unittest discover -s tools/seeds)
"""

from __future__ import annotations

import gzip
import json
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import seeds  # noqa: E402

# One build, a row per table. Items: 100 a flask, 101 its quality twin, 102 a phial (also subclass
# 3), 200 a heal potion, 201 a mana potion, 202 a 30 s combat potion, 203 a 10 min utility potion,
# 204 an absorb potion, 300 a well-fed meal, 301 a feast (places an object), 400 an oil, 401 a
# fishing lure, 500 an old-expansion flask.
TABLES = {
    "Item": ("ID,ClassID,SubclassID,CraftingQualityID\n"
             "100,0,3,14\n101,0,3,13\n102,0,3,14\n200,0,1,14\n201,0,1,14\n202,0,1,14\n203,0,1,0\n"
             "204,0,1,14\n300,0,5,0\n301,0,5,0\n400,0,8,13\n401,0,8,0\n500,0,3,0\n5512,0,8,0\n"),
    "ItemSparse": ("ID,Display_lang,ExpansionID,OverallQualityID,ItemLevel\n"
                   "100,Flask of Tests,11,1,295\n101,Flask of Tests,11,1,278\n102,Phial of Fishing,11,1,295\n"
                   "200,Test Health Potion,11,1,295\n201,Test Mana Potion,11,1,295\n"
                   "202,Potion of Testing,11,1,295\n203,Potion of Slow Fall,11,1,295\n"
                   "204,Potion of Shielding,11,1,295\n300,Test Roast,11,3,90\n301,Test Feast,11,3,90\n"
                   "400,Test Oil,11,2,295\n401,Test Lure,11,2,80\n500,Old Flask,9,1,70\n5512,Healthstone,0,1,5\n"),
    "ItemXItemEffect": ("ID,ItemEffectID,ItemID\n"
                        "1,1,100\n2,2,101\n3,3,102\n4,4,200\n5,5,201\n6,6,202\n7,7,203\n8,8,204\n"
                        "9,9,300\n10,10,301\n11,11,400\n12,12,401\n13,13,500\n"),
    "ItemEffect": ("ID,SpellID\n"
                   "1,1000\n2,1000\n3,1001\n4,2000\n5,2001\n6,2002\n7,2003\n8,2004\n9,3000\n10,3001\n"
                   "11,4000\n12,4001\n13,1000\n"),
    "SpellName": ("ID,Name_lang\n1000,Flask of Tests\n2000,Healing\n3000,Refreshment\n3002,Food\n"
                  "3003,Well Fed\n20484,Rebirth\n"),
    "Spell": ("ID,Description_lang\n"
              "1000,Increases your Haste by $s1 for $d.\n"
              "2002,Drink to increase your primary stat by $s1 for $d.\n"
              "3000,\"If you spend at least 10 seconds eating, you will become $@spellname3003 and gain Mastery.\"\n"
              "3001,Place a Test Feast for all players to enjoy!\n"
              "4000,\"Coat your weapon with Test Oil, increasing your Haste.\"\n"
              "4001,\"When applied to your fishing pole, increases Fishing.\"\n"),
    "SpellEffect": ("ID,SpellID,DifficultyID,Effect,EffectAura,EffectMiscValue_0,EffectTriggerSpell\n"
                    "1,1000,0,6,189,0,0\n2,1001,0,6,189,0,0\n3,2000,0,10,0,0,0\n4,2001,0,30,0,0,0\n"
                    "5,2002,0,6,29,0,0\n6,2003,0,6,25,0,0\n7,2004,0,6,69,127,0\n"
                    "8,3000,0,64,0,0,3002\n9,3002,0,6,20,0,0\n10,3001,0,76,0,0,0\n"
                    "11,4000,0,54,0,0,0\n12,4001,0,54,0,0,0\n13,2000,1,6,8,0,0\n"),
    "SpellMisc": ("ID,SpellID,DifficultyID,DurationIndex\n"
                  "1,1000,0,9\n2,2002,0,7\n3,2003,0,8\n4,2004,0,7\n"),
    "SpellDuration": "ID,Duration\n7,30000\n8,600000\n9,3600000\n",
    "ChrSpecialization": ("Name_lang,ID,ClassID,OrderIndex\nArms,71,1,0\nFury,72,1,1\nInitial,1446,1,4\n"
                          "Ferocity,74,0,0\n"),
    "JournalInstance": "ID,Name_lang\n1,Test Raid\n",
}

SEED_FLASK = """-- defaults/Defaults_Flask.lua
local _, NS = ...
KCM.SEED.FLASK = KCM.PerClient({
    retail = {
        100,  -- Flask of Tests      (HASTE)
        999,  -- Vanished Flask
    },
    forever = {},
})
"""

SEED_POTS = """local _, NS = ...
KCM.SEED.HP_POT = KCM.PerClient({
    retail = {
        200,  -- Test Health Potion (Midnight)
        202,  -- Potion of Testing
                 -- a continuation comment under it
    },
    forever = {},
})
KCM.SEED.MP_POT = KCM.PerClient({
    retail = {
        201,  -- Old Mana Name
    },
    forever = {},
})
KCM.SEED.CMBT_POT = KCM.PerClient({
    retail = {
        202,  -- Potion of Testing
    },
    forever = {},
})
"""

SEED_MISC = """local _, NS = ...
KCM.SEED.STAT_FOOD = KCM.PerClient({
    retail = {
        -- Group header
        300,  -- Test Roast
    },
    forever = {},
})
KCM.SEED.WPN_ENCH = KCM.PerClient({
    retail = {
        400,  -- Test Oil
    },
    forever = {},
})
KCM.SEED.BATTLE_REZ = KCM.PerClient({
    retail = {
        KCM.ID.AsSpell(20484),   -- Rebirth       (Druid)
        KCM.ID.AsSpell(55555),   -- Gone Spell
    },
    forever = {},
})
KCM.SEED.STAT_PRIORITY = KCM.PerClient({
    retail = {
        ["1_71"] = { primary = "STR", secondary = { "CRIT" } },   -- Arms
        ["2_72"] = { primary = "STR", secondary = { "CRIT" } },   -- Fury
    },
    forever = {},
})
"""

CATEGORIES = """KCM.Categories.LIST = {
    {
        key         = "FLASK",
        displayName = "Flask",
    },
    {
        key         = "VANTUS",
        clients     = { "retail" },
    },
    {
        key         = "HS",
    },
}
"""

CLASSIFIER = """local HEALTHSTONE_IDS = {
    [5512]   = true,  -- Classic healthstone (legacy fallback)
}

local VANTUS_IDS = {
    [245880] = true,  -- Vantus Rune: Radiant
}
"""


def crlf(text: str) -> bytes:
    return text.replace("\n", "\r\n").encode("utf-8")


class Fixture:
    """A temp repo: defaults/, core/Classifier.lua and a bundle whose raw/ holds TABLES."""

    def __init__(self, tables=None):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.defaults = root / "defaults"
        self.defaults.mkdir()
        (self.defaults / "Defaults_Flask.lua").write_bytes(crlf(SEED_FLASK))
        (self.defaults / "Defaults_Pots.lua").write_bytes(crlf(SEED_POTS))
        (self.defaults / "Defaults_Misc.lua").write_bytes(crlf(SEED_MISC))
        self.categories = self.defaults / "Categories.lua"
        self.categories.write_bytes(crlf(CATEGORIES))
        (root / "core").mkdir()
        self.classifier = root / "core" / "Classifier.lua"
        self.classifier.write_bytes(crlf(CLASSIFIER))
        self.bundle = root / "docs" / "seed-research" / "2026-11-15-retail"
        raw = self.bundle / "raw"
        raw.mkdir(parents=True)
        for name, body in (tables or TABLES).items():
            with gzip.open(raw / ("%s.csv.gz" % name), "wt", encoding="utf-8", newline="") as fh:
                fh.write(body)
        self.tables = {name: raw / ("%s.csv.gz" % name) for name in (tables or TABLES)}

    def lists(self, flavor="retail"):
        return seeds.checked_lists(flavor, self.defaults, self.classifier, self.categories)

    def build(self):
        return seeds.Build(self.tables)

    def cleanup(self):
        self.tmp.cleanup()


class SeedReaderTest(unittest.TestCase):
    def test_reads_items_spells_priorities_and_comments_through_crlf(self):
        blocks = seeds.parse_seed_text(SEED_MISC.replace("\n", "\r\n"))
        by = {(b["name"], b["client"]): b for b in blocks}
        self.assertEqual([r["id"] for r in by[("STAT_FOOD", "retail")]["records"]], [300])
        rez = by[("BATTLE_REZ", "retail")]["records"]
        self.assertEqual([(r["id"], r["kind"]) for r in rez], [(20484, "spell"), (55555, "spell")])
        self.assertEqual([r["id"] for r in by[("STAT_PRIORITY", "retail")]["records"]], ["1_71", "2_72"])
        self.assertEqual(by[("STAT_FOOD", "forever")]["records"], [])

    def test_comment_name_stops_at_the_aside(self):
        for comment, name in (("Flask of Tests      (HASTE)", "Flask of Tests"),
                              ("Conjured Mana Bun (mage conjured food) — top by default", "Conjured Mana Bun"),
                              ("Soulstone     (Warlock; pre-cast on a living ally)", "Soulstone"),
                              ("Light's Potential", "Light's Potential")):
            self.assertEqual(seeds.comment_name(comment), name)

    def test_classifier_lists_follow_the_category_client_gate(self):
        fx = Fixture()
        try:
            names = {lst["list"] for lst in fx.lists("forever")}
            self.assertIn("CLASSIFIER_HS", names)
            self.assertNotIn("CLASSIFIER_VANTUS", names)
            self.assertIn("CLASSIFIER_VANTUS", {lst["list"] for lst in fx.lists("retail")})
        finally:
            fx.cleanup()


class BuildTest(unittest.TestCase):
    def setUp(self):
        self.fx = Fixture()
        self.b = self.fx.build()

    def tearDown(self):
        self.fx.cleanup()

    def test_potions_are_placed_the_way_the_classifier_sorts_them(self):
        self.assertEqual(seeds.potion_lists(self.b, 200), ["HP_POT"])
        self.assertEqual(seeds.potion_lists(self.b, 201), ["MP_POT"])
        self.assertEqual(seeds.potion_lists(self.b, 202), ["CMBT_POT"])
        self.assertEqual(seeds.potion_lists(self.b, 203), [], "a 10 min utility buff is no combat potion")
        self.assertEqual(seeds.potion_lists(self.b, 204), [], "an absorb fits no Retail potion list")

    def test_a_meal_is_eaten_and_well_fed_and_a_feast_is_neither(self):
        self.assertTrue(self.b.eaten(300) and self.b.well_fed(300))
        self.assertFalse(self.b.eaten(301))

    def test_only_base_difficulty_effects_are_read(self):
        self.assertEqual([e[1] for e in self.b.effects[2000]], [0])


class FlagTest(unittest.TestCase):
    def setUp(self):
        self.fx = Fixture()
        self.flags = seeds.flags_for("retail", self.fx.build(), self.fx.lists())

    def tearDown(self):
        self.fx.cleanup()

    def test_each_kind_lands_on_its_slot(self):
        keys = {f["key"] for f in self.flags}
        self.assertEqual(keys, {
            "shipped:unnamed:FLASK:999",
            "shipped:renamed:MP_POT:201",
            "shipped:misfiled:STAT_PRIORITY:2_72",
            "shipped:unnamed:BATTLE_REZ:spell55555",
            "shipped:unmatched:HP_POT:202",
            "shipped:unnamed:CLASSIFIER_VANTUS:245880",
        })

    def test_forever_raises_no_rule_flag(self):
        fx = self.fx
        flags = seeds.flags_for("forever", fx.build(), fx.lists("forever"))
        self.assertFalse([f for f in flags if f["kind"] == "unmatched"])

    def test_a_forever_poison_must_be_a_subclass_8_consumable(self):
        # Issue #47: Forever ships its poison ranks, so FIT holds them to the class they report.
        from types import SimpleNamespace
        b = SimpleNamespace(specs={}, spell_names={}, items={
            6947: {"name": "Instant Poison", "class": 0, "sub": 8},
            3775: {"name": "Crippling Poison", "class": 0, "sub": 1},
        })
        recs = [{"id": 6947, "kind": "item", "comment": "Instant Poison", "line": 1},
                {"id": 3775, "kind": "item", "comment": "Crippling Poison", "line": 2}]
        lists = [{"list": "POISON", "file": Path("/repo/defaults/Defaults_Poison.lua"), "records": recs,
                  "named": True}]
        keys = {f["key"] for f in seeds.flags_for("forever", b, lists)}
        self.assertEqual(keys, {"shipped:misfiled:POISON:3775"})


class CandidateTest(unittest.TestCase):
    def setUp(self):
        self.fx = Fixture()
        self.b = self.fx.build()
        self.cands, self.unplaced = seeds.candidates_for("retail", self.b, self.fx.lists())

    def tearDown(self):
        self.fx.cleanup()

    def test_each_rule_proposes_only_what_it_admits_in_its_window(self):
        keys = [c["key"] for c in self.cands]
        self.assertIn("FLASK:101", keys)
        self.assertIn("FLASK:102", keys, "a phial shares the subclass; the ruling rejects it")
        self.assertNotIn("FLASK:500", keys, "outside the current-expansion window")
        self.assertNotIn("STAT_FOOD:301", keys, "a feast is not eaten from the bag")
        self.assertNotIn("WPN_ENCH:401", keys, "a fishing lure is not a weapon enhancement")
        self.assertIn("STAT_PRIORITY:1_72", keys)
        self.assertNotIn("STAT_PRIORITY:1_1446", keys, "an Initial pre-spec is no candidate")
        self.assertEqual(sorted(u["id"] for u in self.unplaced), [203, 204])

    def test_a_quality_twin_names_the_shipped_id(self):
        twin = next(c for c in self.cands if c["key"] == "FLASK:101")
        self.assertIn("same name as shipped 100", twin["notes"])

    def test_forever_reads_its_own_rules_not_retails(self):
        cands, _unplaced = seeds.candidates_for("forever", self.b, self.fx.lists("forever"))
        keys = [c["key"] for c in cands]
        self.assertIn("FLASK:500", keys, "Forever's window is not Retail's current expansion")
        self.assertFalse([k for k in keys if k.startswith("STAT_PRIORITY:")], "no spec candidates on Forever")
        self.assertTrue(all(c.get("group") for c in cands if c["list"] == "FLASK"), "each carries its band group")

    def test_the_coverage_gate_fails_loudly_when_a_rule_finds_none_of_its_own(self):
        tables = dict(TABLES)
        tables["SpellEffect"] = "ID,SpellID,DifficultyID,Effect,EffectAura,EffectMiscValue_0,EffectTriggerSpell\n"
        fx = Fixture(tables)
        try:
            problems = seeds.coverage_gate("retail", fx.build(), fx.lists())
            self.assertTrue(any(p.startswith("HP_POT") for p in problems), problems)
            with self.assertRaises(SystemExit):
                seeds.derive_doc("retail", fx.build(), fx.lists(), "1.2.3", "2026-11-15")
        finally:
            fx.cleanup()


class RulingTest(unittest.TestCase):
    def test_candidates_and_flags_take_their_own_rulings(self):
        rulings = {}
        seeds.set_ruling(rulings, "FLASK:101", "reject", "a quality twin")
        seeds.set_ruling(rulings, "shipped:renamed:HS:224464", "keep", "comment fixed")
        seeds.set_ruling(rulings, "STAT_PRIORITY:1_72", "reject", "r")
        seeds.set_ruling(rulings, "shipped:unnamed:BATTLE_REZ:spell55555", "remove", "gone")
        for key, ruling in (("FLASK:1", "keep"), ("shipped:renamed:HS:1", "accept"),
                            ("shipped:bogus:HS:1", "keep"), ("flask:1", "accept")):
            with self.assertRaises(SystemExit):
                seeds.set_ruling(rulings, key, ruling, "why")
        with self.assertRaises(SystemExit):
            seeds.set_ruling(rulings, "FLASK:1", "accept", "two\nlines")


class ApplyTest(unittest.TestCase):
    def setUp(self):
        self.fx = Fixture()
        b = self.fx.build()
        self.doc = seeds.derive_doc("retail", b, self.fx.lists(), "1.2.3", "2026-11-15")
        self.doc["candidates"].append({"key": "VANTUS:777", "list": "VANTUS", "id": "777", "name": "Vantus Rune: New",
                                       "notes": []})
        (self.fx.defaults / "Defaults_Vantus.lua").write_bytes(crlf(
            "KCM.SEED.VANTUS = KCM.PerClient({\n    retail = {\n        245880,  -- Vantus Rune: Radiant\n"
            "    },\n    forever = {},\n})\n"))

    def tearDown(self):
        self.fx.cleanup()

    def rulings(self):
        out = {k: {"ruling": "reject", "reason": "r"} for k in seeds.all_keys(self.doc) if ":" in k}
        for f in self.doc["flags"]:
            out[f["key"]] = {"ruling": "keep", "reason": "r"}
        out["FLASK:101"] = {"ruling": "accept", "reason": "r"}
        out["VANTUS:777"] = {"ruling": "accept", "reason": "r"}
        out["shipped:unmatched:HP_POT:202"] = {"ruling": "remove", "reason": "r"}
        return out

    def apply(self, rulings):
        return seeds.apply_bundle(self.doc, rulings, "2026-11-15", self.fx.defaults, self.fx.classifier)

    def test_refuses_while_anything_is_unruled(self):
        rulings = self.rulings()
        del rulings["FLASK:102"]
        before = (self.fx.defaults / "Defaults_Flask.lua").read_bytes()
        with self.assertRaises(SystemExit):
            self.apply(rulings)
        self.assertEqual((self.fx.defaults / "Defaults_Flask.lua").read_bytes(), before)

    def test_inserts_removes_syncs_the_classifier_keeps_crlf_and_is_idempotent(self):
        changes = self.apply(self.rulings())
        self.assertEqual(sorted(changes), sorted(["FLASK retail: +101", "HP_POT retail: -202",
                                                  "VANTUS retail: +777", "VANTUS_IDS: +777"]))
        flask = (self.fx.defaults / "Defaults_Flask.lua").read_bytes().decode("utf-8")
        self.assertIn("        101,  -- Flask of Tests; added from the 2026-11-15 wago.tools validation (1.2.3)\r\n"
                      "    },\r\n", flask)
        pots = (self.fx.defaults / "Defaults_Pots.lua").read_bytes().decode("utf-8")
        self.assertNotIn("202,  -- Potion of Testing\r\n                 -- a continuation", pots)
        self.assertNotIn("continuation", pots)
        self.assertIn("202,  -- Potion of Testing", pots, "CMBT_POT still ships 202")
        classifier = self.fx.classifier.read_bytes().decode("utf-8")
        self.assertIn("    [777] = true,  -- Vantus Rune: New; added from the 2026-11-15", classifier)
        for path in (self.fx.defaults / "Defaults_Flask.lua", self.fx.defaults / "Defaults_Pots.lua", self.fx.classifier):
            text = path.read_bytes().decode("utf-8")
            self.assertEqual(text.count("\r\n"), text.count("\n"), "%s keeps CRLF" % path.name)
        self.assertEqual(self.apply(self.rulings()), [])

    def test_refuses_an_accept_with_no_writer(self):
        rulings = self.rulings()
        rulings["STAT_PRIORITY:1_72"] = {"ruling": "accept", "reason": "r"}
        with self.assertRaises(SystemExit):
            self.apply(rulings)


class ReportTest(unittest.TestCase):
    def test_unruled_keys_come_first_and_cells_are_escaped(self):
        doc = {"flavor": "retail", "build": "1.2.3", "date": "2026-11-15", "flags": [],
               "candidates": [{"key": "FLASK:1", "list": "FLASK", "id": "1", "name": "A | B", "notes": []}]}
        md = seeds.format_rulings_md(doc, {}, "2026-11-15")
        self.assertIn("## Unruled — 1\n\n- `FLASK:1`", md)
        self.assertIn("A \\| B", md)


class StatusTest(unittest.TestCase):
    def test_current_new_and_no_bundle(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.assertEqual(seeds.status_line("1.2.3", seeds.bundles("retail", root)), "NEW 1.2.3 (no bundle yet)")
            for name, build in (("2026-01-01-retail", "1.2.2"), ("2026-02-01-retail", "1.2.3"),
                                ("2026-03-01-forever", "9.9.9"), ("2026-04-01-retail", "")):
                (root / name).mkdir()
                if build:
                    (root / name / "candidates.json").write_text(json.dumps({"build": build}), encoding="utf-8")
            found = seeds.bundles("retail", root)
            self.assertEqual([b.name for b in found], ["2026-01-01-retail", "2026-02-01-retail"])
            self.assertEqual(seeds.status_line("1.2.3", found), "CURRENT 1.2.3 (2026-02-01-retail)")
            self.assertEqual(seeds.status_line("1.2.4", found), "NEW 1.2.4 (last ruled 1.2.3, 2026-02-01-retail)")


# ---------------------------------------------------------------------------
# WoW Forever (issue #46): its own rules, evidence, and the top tier per band
# ---------------------------------------------------------------------------

# Items: 10/11 two band-1-9 heal potions (11 the higher tier), 12 a band-10-19 one, 13 a heal potion no
# evidence records (a DB2 ghost), 20/21 fire and frost protection potions, 30/31 agility and strength
# elixirs, 40 a sharpening stone, 41 a poison (another category's), 50 a conjured healthstone, 60 a
# bandage, 70 a meal whose Well Fed buff names Stamina, 999 a sword the evidence also names.
FOREVER_TABLES = {
    "Item": ("ID,ClassID,SubclassID,CraftingQualityID\n"
             "10,0,1,0\n11,0,1,0\n12,0,1,0\n13,0,1,0\n14,0,1,0\n15,0,1,0\n20,0,1,0\n21,0,1,0\n30,0,2,0\n31,0,2,0\n40,0,8,0\n"
             "41,0,8,0\n50,0,8,0\n60,0,7,0\n70,0,5,0\n999,2,7,0\n"),
    "ItemSparse": ("ID,Display_lang,ExpansionID,OverallQualityID,ItemLevel,RequiredLevel\n"
                   "10,Minor Healing Potion,0,1,5,1\n11,Lesser Healing Potion,0,1,13,3\n"
                   "12,Healing Potion,0,1,22,12\n13,Ghost Healing Potion,0,1,30,15\n"
                   "14,Drop-Only Healing Potion,0,1,30,1\n15,Battleground Healing Draught,0,1,30,5\n"
                   "20,Fire Protection Potion,0,1,38,0\n21,Frost Protection Potion,0,1,38,0\n"
                   "30,Elixir of Lesser Agility,0,1,15,5\n31,Elixir of Ogre's Strength,0,1,20,5\n"
                   "40,Rough Sharpening Stone,0,1,5,1\n41,Instant Poison,0,1,20,20\n"
                   "50,Minor Healthstone,0,1,1,1\n60,Linen Bandage,0,1,5,0\n70,Roasted Boar Meat,0,1,15,5\n"
                   "999,Worn Shortsword,0,1,2,1\n"),
    "ItemXItemEffect": ("ID,ItemEffectID,ItemID\n"
                        "1,1,10\n2,2,11\n3,3,12\n4,4,13\n14,14,14\n15,15,15\n5,5,20\n6,6,21\n7,7,30\n8,8,31\n9,9,40\n10,10,41\n"
                        "11,11,50\n12,12,60\n13,13,70\n"),
    "ItemEffect": ("ID,SpellID\n"
                   "1,100\n2,101\n3,102\n4,103\n14,104\n15,105\n5,200\n6,201\n7,300\n8,301\n9,400\n10,401\n11,500\n12,600\n"
                   "13,700\n"),
    "SpellName": "ID,Name_lang\n100,Healing\n700,Food\n6201,Create Healthstone (Minor)\n",
    "Spell": ("ID,Description_lang\n"
              "105,Restores $s1 health. This item may only be used in PvP Battlegrounds.\n"
              "300,Increases your Agility by $s1 for $d.\n301,Increases your Strength by $s1 for $d.\n"
              "400,Increase sharp weapon damage by $s1 for 30 minutes.\n401,Coats a weapon with poison.\n"
              "700,\"Restores $s1 health over $d. If you spend at least 10 seconds eating you will become well fed "
              "and gain $s2 Stamina and Spirit for 15 min.\"\n"),
    "SpellEffect": ("ID,SpellID,DifficultyID,Effect,EffectAura,EffectMiscValue_0,EffectTriggerSpell,"
                    "EffectBasePointsF,EffectItemType\n"
                    "1,100,0,10,0,0,0,70,0\n15,104,0,10,0,0,0,500,0\n16,105,0,10,0,0,0,500,0\n2,101,0,10,0,0,0,140,0\n3,102,0,10,0,0,0,280,0\n4,103,0,10,0,0,0,999,0\n"
                    "5,200,0,6,69,4,0,1950,0\n6,201,0,6,69,16,0,1950,0\n7,300,0,6,29,1,0,15,0\n"
                    "8,301,0,6,29,0,0,8,0\n9,400,0,54,0,0,0,2,0\n10,401,0,54,0,0,0,0,0\n11,500,0,10,0,0,0,100,0\n"
                    "12,600,0,6,8,0,0,66,0\n13,700,0,6,20,0,0,61,0\n14,6201,0,24,0,0,0,0,50\n"),
    "SpellMisc": "ID,SpellID,DifficultyID,DurationIndex\n1,300,0,9\n",
    "SpellDuration": "ID,Duration\n9,3600000\n",
}

FOREVER_SEEDS = """local _, NS = ...
KCM.SEED.HP_POT = KCM.PerClient({
    retail = {},
    forever = {
    },
})
KCM.SEED.PROT_POT = KCM.PerClient({
    retail = {},
    forever = {
    },
})
KCM.SEED.ELIXIR = KCM.PerClient({
    retail = {},
    forever = {
    },
})
KCM.SEED.WPN_ENCH = KCM.PerClient({
    retail = {},
    forever = {
    },
})
KCM.SEED.HS = KCM.PerClient({
    retail = {
        5512,  -- Healthstone
    },
    forever = {
    },
})
KCM.SEED.BANDAGE = KCM.PerClient({
    retail = {},
    forever = {
    },
})
KCM.SEED.STAT_FOOD = KCM.PerClient({
    retail = {},
    forever = {
    },
})
"""

FOREVER_CLASSIFIER = """local HEALTHSTONE_IDS = KCM.PerClient({
    retail = {
        [5512]   = true,  -- Classic healthstone (legacy fallback)
        [224464] = true,  -- Modern healthstone
    },
    forever = {
    },
})
"""

FOREVER_EVIDENCE = ("#source\tfdb\tForeverDB test fixture\n#source\tah\tAuctionator test fixture\n"
                    "#source\tprobe\tprobe test fixture\n"
                    "10\tfdb\tvendor\n11\tah\tseen\n14\tfdb\tdrop\n15\tfdb\tvendor\n12\tfdb\tdrop\n12\tfdb\tquest\n20\tfdb\tvendor\n21\tprobe\tseen\n"
                    "30\tfdb\tvendor\n31\tah\tseen\n40\tfdb\tvendor\n41\tfdb\tvendor\n60\tfdb\tvendor\n70\tfdb\tvendor\n"
                    "999\tfdb\tvendor\n")


class ForeverFixture:
    def __init__(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.defaults = root / "defaults"
        self.defaults.mkdir()
        (self.defaults / "Defaults_Forever.lua").write_bytes(crlf(FOREVER_SEEDS))
        self.categories = self.defaults / "Categories.lua"
        self.categories.write_bytes(crlf('KCM.Categories.LIST = {\n    {\n        key = "HS",\n    },\n}\n'))
        (root / "core").mkdir()
        self.classifier = root / "core" / "Classifier.lua"
        self.classifier.write_bytes(crlf(FOREVER_CLASSIFIER))
        raw = root / "raw"
        raw.mkdir()
        for name, body in FOREVER_TABLES.items():
            with gzip.open(raw / ("%s.csv.gz" % name), "wt", encoding="utf-8", newline="") as fh:
                fh.write(body)
        self.tables = {name: raw / ("%s.csv.gz" % name) for name in FOREVER_TABLES}
        self.evidence_tsv = root / "evidence.tsv"
        self.evidence_tsv.write_text(FOREVER_EVIDENCE, encoding="utf-8")
        self.b = seeds.Build(self.tables)
        self.evidence = seeds.build_evidence([self.evidence_tsv], self.b)
        seeds.attach_evidence(self.b, self.evidence)
        self.lists = seeds.checked_lists("forever", self.defaults, self.classifier, self.categories)

    def cleanup(self):
        self.tmp.cleanup()


class ForeverEvidenceTest(unittest.TestCase):
    def setUp(self):
        self.fx = ForeverFixture()

    def tearDown(self):
        self.fx.cleanup()

    def test_evidence_keeps_only_the_builds_consumables(self):
        items = self.fx.evidence["items"]
        self.assertEqual(items["12"], ["fdb:drop", "fdb:quest"])
        self.assertNotIn("999", items, "a sword is not frozen into a consumable bundle")
        self.assertEqual(set(self.fx.evidence["sources"]), {"fdb", "ah", "probe"})

    def test_a_tsv_row_needs_a_declared_source_and_a_known_kind(self):
        bad = Path(self.fx.tmp.name) / "bad.tsv"
        for body in ("10\tfdb\tvendor\n", "#source\tfdb\tx\n10\tfdb\tstolen\n", "#source\tfdb\tx\nten\tfdb\tvendor\n"):
            bad.write_text(body, encoding="utf-8")
            with self.assertRaises(SystemExit):
                seeds.read_evidence_tsv(bad)

    def test_the_label_names_each_source_once(self):
        self.assertEqual(seeds.evidence_label(["ah:seen", "fdb:drop", "fdb:vendor", "probe:seen"]),
                         "ForeverDB (drop, vendor), AH, probe")
        self.assertEqual(seeds.evidence_label(["db2:crafted"]), "DB2 (crafted)")


class ForeverRuleTest(unittest.TestCase):
    def setUp(self):
        self.fx = ForeverFixture()
        self.cands, self.unplaced = seeds.candidates_for("forever", self.fx.b, self.fx.lists)
        self.by = {c["key"]: c for c in self.cands}

    def tearDown(self):
        self.fx.cleanup()

    def test_each_list_takes_its_own_subclass_and_a_sourced_item(self):
        self.assertEqual(sorted(self.by), sorted([
            "HP_POT:10", "HP_POT:11", "HP_POT:12", "HP_POT:14", "PROT_POT:20", "PROT_POT:21", "ELIXIR:30", "ELIXIR:31",
            "WPN_ENCH:40", "HS:50", "BANDAGE:60", "STAT_FOOD:70"]))
        ghosts = seeds.ghosts_for("forever", self.fx.b, self.fx.lists)
        self.assertEqual([(g["list"], g["id"], g["why"]) for g in ghosts],
                         [("HP_POT", 13, "no source"), ("HP_POT", 15, "restricted")],
                         "a DB2 ghost and a battleground-only draught are reported, not proposed")

    def test_a_poison_is_no_weapon_enchant_and_a_conjured_stone_is_a_healthstone(self):
        self.assertNotIn("WPN_ENCH:41", self.by, "the Rogue poison category owns poisons")
        self.assertIn("db2:crafted", self.by["HS:50"]["evidence"])
        self.assertIn("every rank: the whitelist is HS's only matcher", self.by["HS:50"]["notes"])

    def test_the_top_tier_of_each_band_and_group_is_marked(self):
        self.assertIn("top of band 1-9 (3)", self.by["HP_POT:11"]["notes"])
        self.assertIn("2 of 3 in band 1-9, behind 11", self.by["HP_POT:10"]["notes"])
        self.assertIn("3 of 3 in band 1-9, behind 11", self.by["HP_POT:14"]["notes"],
                      "a drop-only item ranks after one a vendor or the AH has, whatever its item level")
        self.assertIn("top of band 10-19 (1)", self.by["HP_POT:12"]["notes"])
        self.assertEqual(self.by["PROT_POT:20"]["group"], "band 20-29, school FIRE", "level 0: ten under its item level")
        self.assertEqual(self.by["PROT_POT:21"]["group"], "band 20-29, school FROST")
        self.assertEqual(self.by["ELIXIR:30"]["group"], "band 1-9, stat AGI")
        self.assertEqual(self.by["ELIXIR:31"]["group"], "band 1-9, stat STR")
        self.assertEqual(self.by["WPN_ENCH:40"]["group"], "band 1-9, kind SHARP")
        self.assertEqual(self.by["STAT_FOOD:70"]["group"], "band 1-9, stat STA", "the stat after 'well fed'")

    def test_a_level_0_item_bands_by_its_skill_or_item_level(self):
        self.assertEqual(seeds.effective_level({"req": 0, "skill": 225, "ilvl": 1}), 45, "Heavy Runecloth Bandage")
        self.assertEqual(seeds.effective_level({"req": 0, "skill": 0, "ilvl": 35}), 25)
        self.assertEqual(seeds.effective_level({"req": 12, "skill": 0, "ilvl": 22}), 12)

    def test_levels_band_by_ten_and_the_last_band_runs_to_sixty(self):
        self.assertEqual([seeds.level_band(n) for n in (0, 9, 10, 19, 49, 50, 60)],
                         ["1-9", "1-9", "10-19", "10-19", "40-49", "50-60", "50-60"])

    def test_the_stat_reader_takes_the_school_before_plain_spell_damage(self):
        self.assertEqual(seeds.forever_stat("Increases fire spell damage by up to 40 for 30 min."), "SP_FIRE")
        self.assertEqual(seeds.forever_stat("Increases spell damage by up to 35 for 30 min."), "SP")
        self.assertEqual(seeds.forever_stat("Increases ranged attack power by 60."), "RAP")
        self.assertEqual(seeds.forever_stat("Allows the imbiber to see invisible."), None)
        self.assertEqual(seeds.forever_stat("Increases damage done by magical spells and effects by up to $s1."), "SP",
                         "Flask of Supreme Power is spell power, not a flat damage bonus")
        self.assertEqual(seeds.forever_stat("Increases damage done by $s1% for $d."), "DMG")
        self.assertEqual(seeds.forever_stat("Increases the player's maximum Mana by $s1 for $d."), "MANA")

    def test_a_school_reads_as_spell_power_only_when_the_item_increases_it(self):
        # Vanilla's and Forever's two wordings of a school elixir.
        self.assertEqual(seeds.forever_stat("Increases spell fire damage by up to $s1 for $d."), "SP_FIRE")
        self.assertEqual(seeds.forever_stat("Drink to increase nature spell damage by up to $s1."), "SP_NATURE")
        self.assertEqual(seeds.forever_stat("Increases spell Holy damage by up to $s1 for $d."), "SP_HOLY")
        # A potion that deals a school's damage buffs no stat (Dragonfire Potion, Potion of Venomous
        # Blood): it is no school's spell-power potion.
        self.assertIsNone(seeds.forever_stat("Unleash a belch of dragonfire, dealing $s1 Fire damage instantly "
                                             "in a narrow cone in front of you."))
        self.assertIsNone(seeds.forever_stat("Gain $U doses of Venomous Blood. Whenever you suffer Bleed damage, "
                                             "one dose is spread to a nearby enemy. Venomous Blood deals $s1 "
                                             "Nature damage."))


class ForeverClassifierTest(unittest.TestCase):
    def setUp(self):
        self.fx = ForeverFixture()

    def tearDown(self):
        self.fx.cleanup()

    def test_a_per_client_whitelist_answers_each_client_its_own_block(self):
        tables = seeds.classifier_tables(FOREVER_CLASSIFIER)
        self.assertEqual([r["id"] for r in tables["HEALTHSTONE_IDS"]["retail"]["records"]], [5512, 224464])
        self.assertEqual(tables["HEALTHSTONE_IDS"]["forever"]["records"], [])
        hs = next(lst for lst in self.fx.lists if lst["list"] == "CLASSIFIER_HS")
        self.assertEqual(hs["records"], [], "Forever reads its own block, not Retail's")

    def test_apply_writes_the_seed_the_whitelist_and_the_evidence(self):
        doc = seeds.derive_doc("forever", self.fx.b, self.fx.lists, "1.60.1", "2026-11-27")
        rulings = {k: {"ruling": "reject", "reason": "r"} for k in seeds.all_keys(doc)}
        for key in ("HS:50", "HP_POT:12"):
            rulings[key] = {"ruling": "accept", "reason": "r"}
        changes = seeds.apply_bundle(doc, rulings, "2026-11-27", self.fx.defaults, self.fx.classifier)
        self.assertEqual(sorted(changes), ["HEALTHSTONE_IDS: +50", "HP_POT forever: +12", "HS forever: +50"])
        seed = (self.fx.defaults / "Defaults_Forever.lua").read_bytes().decode("utf-8")
        self.assertIn("        12,  -- Healing Potion; added from the 2026-11-27 wago.tools validation (1.60.1); "
                      "Evidence: ForeverDB (drop, quest)\r\n", seed)
        classifier = self.fx.classifier.read_bytes().decode("utf-8")
        self.assertIn("    forever = {\r\n        [50] = true,  -- Minor Healthstone; added from the 2026-11-27", classifier)
        self.assertIn("[224464] = true", classifier, "Retail's block is untouched")
        self.assertEqual(classifier.count("\r\n"), classifier.count("\n"))
        self.assertEqual(seeds.apply_bundle(doc, rulings, "2026-11-27", self.fx.defaults, self.fx.classifier), [])

    def test_the_diff_reports_the_ghosts(self):
        doc = seeds.derive_doc("forever", self.fx.b, self.fx.lists, "1.60.1", "2026-11-27")
        self.assertIn("## DB2-only items left out of the window — 1", seeds.format_diff(doc))
        self.assertIn("- HP_POT `13` Ghost Healing Potion (required level 15)", seeds.format_diff(doc))


class RepoTest(unittest.TestCase):
    def test_every_real_seed_file_reads(self):
        lists = seeds.read_seed_lists()
        names = {b["name"] for b in lists["retail"]}
        for want in ("FLASK", "FOOD", "STAT_FOOD", "CMBT_POT", "HP_POT", "MP_POT", "DRINK", "AUG_RUNE", "VANTUS",
                     "WPN_ENCH", "HS", "BLOODLUST", "BATTLE_REZ", "CLASS_GATE", "STAT_PRIORITY"):
            self.assertIn(want, names)
        clients = seeds.category_clients()
        served = [b for b in lists["retail"] if "retail" in clients.get(b["name"], {"retail"})]
        self.assertTrue(all(b["records"] for b in served), "a Retail list read as empty")
        # Issue #46 lifted the 2026-11-08 "empty by decision" ruling: every Forever item category seeds.
        forever = {b["name"]: b for b in lists["forever"]}
        for want in ("FOOD", "DRINK", "HP_POT", "MP_POT", "HS", "BANDAGE", "FLASK", "ELIXIR", "CMBT_POT",
                     "PROT_POT", "STAT_FOOD", "SCROLL", "WPN_ENCH"):
            self.assertTrue(forever.get(want) and forever[want]["records"], "Forever's %s seeds nothing" % want)
        # Forever also ships its own stat priorities (issue #48) and every poison rank (issue #47).
        self.assertTrue(forever.get("STAT_PRIORITY") and forever["STAT_PRIORITY"]["records"],
                        "Forever ships its stat priorities")
        for name in ("POISON", "POISON_FAMILY"):
            self.assertEqual(len(forever.get(name, {}).get("records", [])), 20,
                             name + ": every rank of the five families")
            self.assertTrue(all(r["kind"] == "item" for r in forever[name]["records"]), name + " ships items")

    def test_the_newest_bundle_of_each_flavor_is_fully_ruled(self):
        for flavor in seeds.PRODUCTS:
            found = seeds.bundles(flavor)
            if not found:
                continue
            doc = seeds.load_candidates(found[-1])
            self.assertEqual(seeds.unruled_keys(doc, seeds.load_rulings(seeds.rulings_path(flavor))), [], flavor)


if __name__ == "__main__":
    unittest.main()
