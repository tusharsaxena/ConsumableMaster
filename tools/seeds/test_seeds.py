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

    def test_forever_proposes_nothing(self):
        self.assertEqual(seeds.candidates_for("forever", self.b, self.fx.lists("forever")), ([], []))

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


class RepoTest(unittest.TestCase):
    def test_every_real_seed_file_reads(self):
        lists = seeds.read_seed_lists()
        names = {b["name"] for b in lists["retail"]}
        for want in ("FLASK", "FOOD", "STAT_FOOD", "CMBT_POT", "HP_POT", "MP_POT", "DRINK", "AUG_RUNE", "VANTUS",
                     "WPN_ENCH", "HS", "BLOODLUST", "BATTLE_REZ", "CLASS_GATE", "STAT_PRIORITY"):
            self.assertIn(want, names)
        self.assertTrue(all(b["records"] for b in lists["retail"]), "a Retail list read as empty")
        # Forever's lists are empty by decision, the poison ranks apart (issue #47): a small, fixed set.
        seeded = {"POISON", "POISON_FAMILY"}
        self.assertTrue(all(not b["records"] for b in lists["forever"] if b["name"] not in seeded),
                        "Forever's lists are empty by decision")
        forever = {b["name"]: b["records"] for b in lists["forever"]}
        for name in seeded:
            self.assertEqual(len(forever.get(name, [])), 20, name + ": every rank of the five families")
            self.assertTrue(all(r["kind"] == "item" for r in forever[name]), name + " ships items")

    def test_the_newest_bundle_of_each_flavor_is_fully_ruled(self):
        for flavor in seeds.PRODUCTS:
            found = seeds.bundles(flavor)
            if not found:
                continue
            doc = seeds.load_candidates(found[-1])
            self.assertEqual(seeds.unruled_keys(doc, seeds.load_rulings(seeds.rulings_path(flavor))), [], flavor)


if __name__ == "__main__":
    unittest.main()
