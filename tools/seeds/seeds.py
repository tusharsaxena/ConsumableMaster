#!/usr/bin/env python3
"""tools/seeds/seeds.py — validate the consumable seed lists against one wago.tools build (issue #49).

WHAT THIS IS
    defaults/Defaults_*.lua hold the item and spell ids each consumable category seeds, one list per
    client (KCM.PerClient, clients-§5), put together by hand from guides and in-game vendor walks.
    This tool re-checks every list against the client's own DB2 tables on wago.tools, for one pinned
    build, and turns what it finds into FLAGS and CANDIDATES, each of which needs a ruling recorded
    as data. A ruling is keyed by list and id, never by build, so a re-run on a later build shows
    only what is new since the last ruled one.

    Flags (key `shipped:<kind>:<LIST>:<id>`, ruled keep or remove), over every shipped id:
        unnamed    the build has no row for it (Item + ItemSparse for an item, SpellName for a
                   spell, ChrSpecialization for a stat-priority key)
        renamed    its name on the build disagrees with the comment beside it
        misfiled   its item class/subclass (or, for a stat-priority key, its class) no longer fits
                   the list
        unmatched  it sits in its list's candidate window, but the list's own rule (RULES below)
                   no longer admits it: a flask that stopped being a flask

    Candidates (key `<LIST>:<id>`, ruled accept or reject): ids the build has that a list's rule
    admits and the list does not ship. Only lists with a mechanical rule propose any; the others
    (FOOD and DRINK are a vendor's stock, HS a fixed whitelist, BLOODLUST and BATTLE_REZ class
    spells plus one item) are checked for flags alone. WoW Forever proposes none: its lists are
    empty by decision (owner ruling 2026-11-08), and every Forever candidate comes from the bag scan.

    The core/Classifier.lua whitelists (HEALTHSTONE_IDS, VANTUS_IDS, REUSABLE_AUG_IDS) are shipped
    ids too, and are checked like a list. An accepted VANTUS candidate is written to VANTUS_IDS as
    well as to the seed, because Defaults_Vantus.lua's header says the two move together.

THE STEPS
    python3 tools/seeds/seeds.py status [--flavor retail|forever]
    python3 tools/seeds/seeds.py derive --flavor F --bundle docs/seed-research/<date>-F --date <date> [--build V] [--replay]
    python3 tools/seeds/seeds.py check  --bundle docs/seed-research/<date>-F
    python3 tools/seeds/seeds.py rule   --tsv rulings.tsv --bundle docs/seed-research/<date>-F
    python3 tools/seeds/seeds.py report --bundle docs/seed-research/<date>-F --date <date>
    python3 tools/seeds/seeds.py apply  --bundle docs/seed-research/<date>-F --date <date>

    `status` prints `CURRENT <build> (<bundle>)` when the newest bundle of the flavor is of the live
    build, else `NEW <build> ...`. `derive` pins one build (`--build`, else the live one), fetches
    the flavor's tables into the git-ignored .cache/, freezes them gzipped into the bundle's raw/,
    and writes candidates.json, SOURCES.md and DIFF.md. `--replay` reads only the bundle's raw/ and
    verifies: it writes nothing, and exits non-zero when the re-derivation differs from the frozen
    candidates.json (which it does once the bundle's accepts are applied, so replay a bundle at the
    revision that froze it).
    `rule` is the only writer of the flavor's rulings file (tools/seeds/<flavor>_rulings.json).
    `check` exits 1 while anything is unruled. `report` writes the bundle's RULINGS.md. `apply`
    refuses while anything is unruled, inserts each accepted candidate into its list, removes each
    id whose flag was ruled `remove`, keeps the file's line endings, and changes nothing on a
    second run.

    The run's date is always an argument: nothing here reads the clock (clients-§10).

SHARED HELPER
    The download, cache, bundle and rulings plumbing is copied from AuraMaster's
    tools/spell-research/ (research.py, sid_seeds.py, retail.py), never imported across repos.
    Whether it becomes one shared helper, and where that would live, is LibKa0s#91.

Python 3.8+ and its standard library only.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import json
import re
import shutil
import sys
import urllib.error
import urllib.request
from collections import defaultdict
from pathlib import Path
from typing import Dict, List, Optional, Tuple

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
DEFAULTS = ROOT / "defaults"
CLASSIFIER = ROOT / "core" / "Classifier.lua"
CATEGORIES = DEFAULTS / "Categories.lua"
RESEARCH = ROOT / "docs" / "seed-research"
CACHE = HERE / ".cache"

BUILDS_URL = "https://wago.tools/api/builds"
CSV_URL = "https://wago.tools/db2/{table}/csv?build={build}"
# wago.tools answers HTTP 403 to urllib's default agent; this one identifies the tool (clients-§10).
USER_AGENT = "ConsumableMaster-seed-check/1.0 (+https://github.com/tusharsaxena/ConsumableMaster)"
DOWNLOAD_CHUNK = 1 << 20  # SpellEffect is ~57 MB on Retail and is streamed, never read whole
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")

# The flavor is the client (clients-§1) and its source is that client's own wago product.
PRODUCTS = {"retail": "wow", "forever": "wowf"}

# The tables each flavor reads, and why. Forever reads only what its flag checks need: it proposes
# no candidates, so it has no use for the effect tables.
TABLES = {
    "retail": (
        ("Item", "ClassID / SubclassID / CraftingQualityID: the category fit and the quality tier"),
        ("ItemSparse", "Display_lang / ExpansionID / OverallQualityID / ItemLevel / Flags_0: the name and the window"),
        ("ItemXItemEffect", "ItemID -> ItemEffectID, step 1 of the item -> spell join"),
        ("ItemEffect", "ItemEffectID -> SpellID, step 2: the spell the item casts"),
        ("SpellName", "Name_lang: spell-seed names, and the Well Fed buff a meal references"),
        ("Spell", "Description_lang: what the item's spell says it does (evidence, Well Fed, Augment Rune)"),
        ("SpellEffect", "Effect / EffectAura / EffectMiscValue_0 / EffectTriggerSpell: heal, mana, absorb, temporary enchant"),
        ("SpellMisc", "DurationIndex: a combat potion's buff duration"),
        ("SpellDuration", "Duration: DurationIndex -> milliseconds"),
        ("ChrSpecialization", "ID / ClassID / Name_lang / OrderIndex: the stat-priority keys"),
        ("JournalInstance", "Name_lang: whether the raid a Vantus rune names is in the journal (Retail only)"),
    ),
    "forever": (
        ("Item", "ClassID / SubclassID: the category fit"),
        ("ItemSparse", "Display_lang: the name"),
        ("SpellName", "Name_lang: spell-seed names"),
    ),
}

# The newest expansion's ExpansionID on Retail (Midnight). A list's candidate window is read
# against this; when the next expansion ships, raise it and re-derive.
CURRENT_EXPANSION = 11

# DB2 enums the rules read (SpellEffect.Effect / EffectAura).
EFFECT_HEAL = 10
EFFECT_ENERGIZE = 30
EFFECT_ENCHANT_ITEM_TEMPORARY = 54
AURA_PERIODIC_HEAL = 8
AURA_OBS_MOD_HEALTH = 20   # food: health regained while seated
AURA_OBS_MOD_POWER = 21    # drink: mana regained while seated
AURA_PERIODIC_ENERGIZE = 24
AURA_SCHOOL_ABSORB = 69
POWER_MANA = 0
CMBT_POT_MAX_DURATION_MS = 60000  # Defaults_CombatPot.lua's header and core/Classifier.lua's CMBT_POT_MAX_DURATION

CANDIDATE_RULINGS = ("accept", "reject")
FLAG_RULINGS = ("keep", "remove")
FLAG_KINDS = ("unnamed", "renamed", "misfiled", "unmatched")
KEY_RE = re.compile(r"^(?:shipped:(?P<kind>[a-z]+):)?(?P<list>[A-Z_]+):(?P<id>spell\d+|\d+_\d+|\d+)$")

# What a shipped item's class/subclass must be, per list and client: (ClassID, SubclassIDs or None
# for any subclass). Consumable is ClassID 0. Forever's potions include Draught (13) and its weapon
# enchants Item Enhancement Temporary (15), as core/Classifier.lua's per-client tables say.
FIT = {
    "retail": {
        "FLASK": (0, {3}), "CMBT_POT": (0, {1}), "HP_POT": (0, {1}), "MP_POT": (0, {1}),
        "FOOD": (0, {5}), "DRINK": (0, {5}), "STAT_FOOD": (0, {5}), "VANTUS": (0, {9}),
        "WPN_ENCH": (0, {8}), "AUG_RUNE": (0, {8}), "HS": (0, None), "BLOODLUST": (0, None),
        "BATTLE_REZ": (0, None), "CLASSIFIER_HS": (0, None), "CLASSIFIER_VANTUS": (0, {9}),
        "CLASSIFIER_REUSABLE_AUG": (0, {8}),
    },
    "forever": {
        "FLASK": (0, {3}), "CMBT_POT": (0, {1, 13}), "HP_POT": (0, {1, 13}), "MP_POT": (0, {1, 13}),
        "FOOD": (0, {5}), "DRINK": (0, {5}), "STAT_FOOD": (0, {5}), "VANTUS": (0, {9}),
        "WPN_ENCH": (0, {8, 15}), "AUG_RUNE": (0, {8}), "HS": (0, None), "BLOODLUST": (0, None),
        "BATTLE_REZ": (0, None), "CLASSIFIER_HS": (0, None),
    },
}

# The core/Classifier.lua whitelists: (Lua table name, list key, the category whose client gate
# decides whether the flavor reads it, whether its comments are names).
CLASSIFIER_LISTS = (
    ("HEALTHSTONE_IDS", "CLASSIFIER_HS", "HS", False),
    ("VANTUS_IDS", "CLASSIFIER_VANTUS", "VANTUS", True),
    ("REUSABLE_AUG_IDS", "CLASSIFIER_REUSABLE_AUG", "AUG_RUNE", True),
)
# A seed list whose accepted candidates are also written to a Classifier whitelist.
CLASSIFIER_SYNC = {"VANTUS": "VANTUS_IDS"}
# The seed list that maps a Classifier whitelist's category (CLASSIFIER_LISTS) to its seed key.
SEED_OF_CATEGORY = {"HS": "HS", "VANTUS": "VANTUS", "AUG_RUNE": "AUG_RUNE"}


# ---------------------------------------------------------------------------
# Small I/O helpers (copied from AuraMaster's tools/spell-research/, LibKa0s#91)
# ---------------------------------------------------------------------------

def log(msg: str) -> None:
    print(msg, file=sys.stderr, flush=True)


def write_text(path: Path, text: str, newline: str = "\r\n") -> None:
    """Write text with one line terminator. The repo pins `* text=auto eol=crlf`, and
    tests/_kit/test_eol.lua fails a tracked file whose working copy disagrees, so every file this
    tool writes into docs/ or defaults/ is CRLF. Bytes, not newline=, so no Python version matters."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(text.replace("\r\n", "\n").replace("\n", newline).encode("utf-8"))


def write_json(path: Path, doc) -> None:
    write_text(path, json.dumps(doc, indent=1, sort_keys=True, ensure_ascii=False) + "\n")


def http_get(url: str, accept: str = "*/*"):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": accept})
    try:
        return urllib.request.urlopen(req, timeout=300)
    except urllib.error.HTTPError as err:
        raise SystemExit("HTTP %s fetching %s: %s" % (err.code, url, err.reason))
    except urllib.error.URLError as err:
        raise SystemExit("Could not reach %s: %s (a new run needs network access)" % (url, err.reason))


def live_build(product: str) -> Tuple[str, str]:
    """`(version, created_at)` of the product's newest build on the builds API."""
    data = json.load(http_get(BUILDS_URL, accept="application/json"))
    builds = data.get(product) or []
    if not builds:
        raise SystemExit("The builds API returned no '%s' builds; pass --build." % product)
    return builds[0]["version"], builds[0].get("created_at", "")


def build_created(product: str, version: str) -> str:
    """The builds API's `created_at` for a pinned build, or "" when it lists no such build."""
    data = json.load(http_get(BUILDS_URL, accept="application/json"))
    return next((b.get("created_at", "") for b in data.get(product) or () if b.get("version") == version), "")


def fetch_table(table: str, build: str, cache_dir: Path) -> Path:
    """Stream one table's CSV for `build` into the cache (a `.part` renamed on completion, so an
    interrupted download is fetched again rather than read half). Always names the build: a URL
    without `?build=` serves the PTR."""
    cache_dir.mkdir(parents=True, exist_ok=True)
    dest = cache_dir / ("%s-%s.csv" % (table, build))
    if dest.exists():
        log("  %-18s cached (%.1f MB)" % (table, dest.stat().st_size / 1e6))
        return dest
    url = CSV_URL.format(table=table, build=build)
    tmp = dest.with_suffix(".csv.part")
    log("  %-18s fetching %s" % (table, url))
    with http_get(url, accept="text/csv") as response, tmp.open("wb") as handle:
        shutil.copyfileobj(response, handle, DOWNLOAD_CHUNK)
    tmp.replace(dest)
    return dest


def freeze(source: Path, member: Path) -> None:
    """Gzip a cached CSV into the bundle with a zero mtime, so a re-freeze is byte-identical."""
    member.parent.mkdir(parents=True, exist_ok=True)
    with source.open("rb") as src, member.open("wb") as raw:
        with gzip.GzipFile(filename="", mode="wb", fileobj=raw, compresslevel=9, mtime=0) as dst:
            shutil.copyfileobj(src, dst, DOWNLOAD_CHUNK)


def iter_csv(path: Path):
    """One row at a time, from a cached `.csv` or a bundle's `.csv.gz`; columns by header name."""
    if path.suffix == ".gz":
        with gzip.open(path, "rt", encoding="utf-8", newline="") as handle:
            for row in csv.DictReader(handle):
                yield row
        return
    with path.open("r", encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            yield row


def as_int(value: Optional[str]) -> int:
    if not value:
        return 0
    try:
        return int(value)
    except ValueError:
        try:
            return int(float(value))
        except ValueError:
            return 0


def norm(name: str) -> str:
    return " ".join((name or "").replace("\u2019", "'").lower().split())


# ---------------------------------------------------------------------------
# The seed files
# ---------------------------------------------------------------------------

SEED_OPEN = re.compile(r"^KCM\.SEED\.(?P<name>[A-Z_]+)\s*=\s*KCM\.PerClient\(\{\s*$")
BLOCK_OPEN = re.compile(r"^(?P<indent>[ \t]+)(?P<client>retail|forever)\s*=\s*\{(?P<rest>.*)$")
RECORD = re.compile(r"^(?P<indent>[ \t]*)(?:\[\s*)?(?:KCM\.ID\.AsSpell\((?P<spell>\d+)\)|(?P<item>\d+))"
                    r"(?:\s*\]\s*=\s*\"[A-Z]+\")?\s*,\s*(?:--\s*(?P<comment>.*))?$")
PRIORITY = re.compile(r'^[ \t]*\["(?P<key>\d+_\d+)"\]\s*=\s*\{.*\}\s*,\s*(?:--\s*(?P<comment>.*))?$')
COMMENT_ONLY = re.compile(r"^(?P<indent>[ \t]*)--")
CLASSIFIER_ROW = re.compile(r"^(?P<indent>[ \t]*)\[(?P<id>\d+)\]\s*=\s*true\s*,\s*(?:--\s*(?P<comment>.*))?$")


def comment_name(comment: Optional[str]) -> str:
    """The name a seed comment opens with: up to a run of two spaces, ` (`, ` —`, `;` or ` - `."""
    text = (comment or "").strip()
    cut = re.split(r"\s{2,}| \(| \u2014|;| - ", text, maxsplit=1)
    return cut[0].strip()


def split_lines(text: str) -> Tuple[List[str], str]:
    newline = "\r\n" if "\r\n" in text else "\n"
    return text.replace("\r\n", "\n").split("\n"), newline


def parse_seed_text(text: str) -> List[dict]:
    """Every `KCM.SEED.X = KCM.PerClient({ retail = {...}, forever = {...} })` list in one file:
    `[{name, client, records: [{id, kind, comment, line}]}]`. kind is item, spell or priority."""
    lines, _nl = split_lines(text)
    out: List[dict] = []
    seed = None
    i = 0
    while i < len(lines):
        line = lines[i]
        m = SEED_OPEN.match(line)
        if m:
            seed = m.group("name")
            i += 1
            continue
        b = BLOCK_OPEN.match(line) if seed else None
        if b:
            block = {"name": seed, "client": b.group("client"), "records": [], "open": i, "close": i}
            out.append(block)
            if b.group("rest").strip().startswith("}"):
                i += 1
                continue
            indent = b.group("indent")
            i += 1
            while i < len(lines) and not re.match(r"^%s\}\s*,?\s*$" % re.escape(indent), lines[i]):
                rec = record_of(lines[i], i, seed)
                if rec:
                    block["records"].append(rec)
                i += 1
            block["close"] = i
        if line.startswith("})"):
            seed = None
        i += 1
    return out


def record_of(line: str, index: int, seed: str) -> Optional[dict]:
    if seed == "STAT_PRIORITY":
        p = PRIORITY.match(line)
        if p:
            return {"id": p.group("key"), "kind": "priority", "comment": (p.group("comment") or "").strip(),
                    "line": index}
        return None
    m = RECORD.match(line)
    if not m:
        return None
    if m.group("spell"):
        return {"id": int(m.group("spell")), "kind": "spell", "comment": (m.group("comment") or "").strip(),
                "line": index}
    return {"id": int(m.group("item")), "kind": "item", "comment": (m.group("comment") or "").strip(),
            "line": index}


def read_seed_lists(defaults: Path = DEFAULTS) -> Dict[str, List[dict]]:
    """`{client: [list]}` over every defaults/Defaults_*.lua; each list carries its file."""
    out: Dict[str, List[dict]] = {"retail": [], "forever": []}
    for path in sorted(defaults.glob("Defaults_*.lua")):
        for block in parse_seed_text(path.read_bytes().decode("utf-8")):
            block["file"] = path
            out[block["client"]].append(block)
    return out


def classifier_tables(text: str) -> Dict[str, dict]:
    """`{table: {records, open, close}}` for every `local NAME = {` table of `[id] = true` rows."""
    lines, _nl = split_lines(text)
    out: Dict[str, dict] = {}
    for table, _key, _cat, _named in CLASSIFIER_LISTS:
        opener = re.compile(r"^local %s\s*=\s*\{\s*$" % table)
        for i, line in enumerate(lines):
            if opener.match(line):
                records, j = [], i + 1
                while j < len(lines) and not lines[j].startswith("}"):
                    m = CLASSIFIER_ROW.match(lines[j])
                    if m:
                        records.append({"id": int(m.group("id")), "kind": "item",
                                        "comment": (m.group("comment") or "").strip(), "line": j})
                    j += 1
                out[table] = {"records": records, "open": i, "close": j}
                break
    return out


def category_clients(path: Path = CATEGORIES) -> Dict[str, set]:
    """`{category key: clients}` from defaults/Categories.lua; a row with no `clients` serves both."""
    text = path.read_bytes().decode("utf-8").replace("\r\n", "\n")
    out: Dict[str, set] = {}
    for row in re.finditer(r'key\s*=\s*"(?P<key>[A-Z_]+)"(?P<body>.*?)(?=\n\s*key\s*=|\Z)', text, re.S):
        found = re.search(r"clients\s*=\s*\{(?P<list>[^}]*)\}", row.group("body"))
        clients = set(re.findall(r'"(\w+)"', found.group("list"))) if found else {"retail", "forever"}
        out[row.group("key")] = clients
    return out


def checked_lists(flavor: str, defaults: Path = DEFAULTS, classifier: Path = CLASSIFIER,
                  categories: Path = CATEGORIES) -> List[dict]:
    """Every list the flavor ships: its seed blocks, plus the Classifier whitelists whose category
    the client has. Each is `{list, file, records, named}`."""
    out = []
    for block in read_seed_lists(defaults)[flavor]:
        out.append({"list": block["name"], "file": block["file"], "records": block["records"], "named": True})
    clients = category_clients(categories)
    tables = classifier_tables(classifier.read_bytes().decode("utf-8"))
    for table, key, category, named in CLASSIFIER_LISTS:
        if flavor in clients.get(category, {"retail", "forever"}) and table in tables:
            out.append({"list": key, "file": classifier, "records": tables[table]["records"], "named": named})
    return out


# ---------------------------------------------------------------------------
# The build's facts
# ---------------------------------------------------------------------------

class Build:
    """What the rules read from one build's tables, loaded once. A table the flavor does not read
    leaves its part empty."""

    def __init__(self, tables: Dict[str, Path]):
        self.items: Dict[int, dict] = {}
        self.spell_names: Dict[int, str] = {}
        self.desc: Dict[int, str] = {}
        self.item_spells: Dict[int, List[int]] = defaultdict(list)
        self.effects: Dict[int, List[tuple]] = defaultdict(list)
        self.duration_ms: Dict[int, int] = {}
        self.specs: Dict[int, dict] = {}
        self.journal: set = set()
        self._read(tables)

    def _read(self, t: Dict[str, Path]) -> None:
        classes = {}
        for row in iter_csv(t["Item"]):
            classes[as_int(row["ID"])] = (as_int(row["ClassID"]), as_int(row["SubclassID"]),
                                          as_int(row.get("CraftingQualityID")))
        for row in iter_csv(t["ItemSparse"]):
            iid = as_int(row["ID"])
            if iid not in classes:
                continue
            klass, sub, cq = classes[iid]
            self.items[iid] = {"name": row.get("Display_lang", ""), "class": klass, "sub": sub, "cq": cq,
                               "exp": as_int(row.get("ExpansionID")), "quality": as_int(row.get("OverallQualityID")),
                               "ilvl": as_int(row.get("ItemLevel"))}
        for row in iter_csv(t["SpellName"]):
            self.spell_names[as_int(row["ID"])] = row.get("Name_lang", "")
        if "ItemEffect" in t and "ItemXItemEffect" in t:
            spell_of = {as_int(r["ID"]): as_int(r["SpellID"]) for r in iter_csv(t["ItemEffect"])}
            for row in iter_csv(t["ItemXItemEffect"]):
                spell = spell_of.get(as_int(row["ItemEffectID"]))
                if spell:
                    self.item_spells[as_int(row["ItemID"])].append(spell)
        if "Spell" in t:
            for row in iter_csv(t["Spell"]):
                if row.get("Description_lang"):
                    self.desc[as_int(row["ID"])] = row["Description_lang"]
        if "SpellEffect" in t:
            self._read_effects(t["SpellEffect"])
        if "SpellMisc" in t and "SpellDuration" in t:
            ms = {as_int(r["ID"]): as_int(r["Duration"]) for r in iter_csv(t["SpellDuration"])}
            wanted = {s for spells in self.item_spells.values() for s in spells}
            for row in iter_csv(t["SpellMisc"]):
                spell = as_int(row["SpellID"])
                if spell in wanted and as_int(row.get("DifficultyID")) == 0:
                    self.duration_ms[spell] = ms.get(as_int(row.get("DurationIndex")), 0)
        if "ChrSpecialization" in t:
            for row in iter_csv(t["ChrSpecialization"]):
                self.specs[as_int(row["ID"])] = {"class": as_int(row["ClassID"]), "name": row.get("Name_lang", ""),
                                                 "order": as_int(row.get("OrderIndex"))}
        if "JournalInstance" in t:
            self.journal = {norm(r.get("Name_lang", "")) for r in iter_csv(t["JournalInstance"])}

    def _read_effects(self, path: Path) -> None:
        """Base-difficulty effects of every item spell, then of the spells those trigger (one hop:
        a meal's Refreshment triggers the Food spell that carries the regen aura). Two streamed
        passes rather than holding a 57 MB table's every row."""
        wanted = {s for spells in self.item_spells.values() for s in spells}
        for hop in range(2):
            for row in iter_csv(path):
                spell = as_int(row["SpellID"])
                if spell in wanted and as_int(row.get("DifficultyID")) == 0:
                    self.effects[spell].append((as_int(row["Effect"]), as_int(row["EffectAura"]),
                                                as_int(row.get("EffectMiscValue_0")),
                                                as_int(row.get("EffectTriggerSpell"))))
            if hop == 0:
                wanted = {e[3] for spell in list(self.effects) for e in self.effects[spell] if e[3]} - set(self.effects)

    # -- per-item questions ---------------------------------------------------

    def spells_of(self, item: int) -> List[int]:
        return list(self.item_spells.get(item, ()))

    def effects_of(self, item: int) -> List[tuple]:
        """The item's spells' effects plus one hop of EffectTriggerSpell."""
        out = []
        for spell in self.spells_of(item):
            for eff in self.effects.get(spell, ()):
                out.append(eff)
                if eff[3]:
                    out.extend(self.effects.get(eff[3], ()))
        return out

    def text_of(self, item: int) -> str:
        """The item's spells' descriptions, with `$@spelldesc<id>` resolved two levels deep."""
        def resolve(spell: int, depth: int) -> str:
            text = self.desc.get(spell, "")
            if depth < 2:
                text = re.sub(r"\$@spelldesc(\d+)", lambda m: resolve(int(m.group(1)), depth + 1), text)
            return text
        return " ".join(resolve(s, 0) for s in self.spells_of(item)).replace("\r", " ").replace("\n", " ")

    def heals(self, item: int) -> bool:
        return any(e[0] == EFFECT_HEAL or (e[0] == 6 and e[1] in (AURA_PERIODIC_HEAL, AURA_OBS_MOD_HEALTH))
                   for e in self.effects_of(item))

    def restores_mana(self, item: int) -> bool:
        return any((e[0] == EFFECT_ENERGIZE and e[2] == POWER_MANA)
                   or (e[0] == 6 and e[1] in (AURA_PERIODIC_ENERGIZE, AURA_OBS_MOD_POWER) and e[2] == POWER_MANA)
                   for e in self.effects_of(item))

    def absorbs(self, item: int) -> bool:
        return any(e[0] == 6 and e[1] == AURA_SCHOOL_ABSORB for e in self.effects_of(item))

    def eaten(self, item: int) -> bool:
        """Eaten or drunk from the bag: a seated health or mana regen aura (a feast places an object
        instead, and so is never eaten from the bag)."""
        return any(e[0] == 6 and e[1] in (AURA_OBS_MOD_HEALTH, AURA_OBS_MOD_POWER) for e in self.effects_of(item))

    def well_fed(self, item: int) -> bool:
        text = self.text_of(item)
        refs = re.findall(r"\$@spell(?:name|desc|icon)(\d+)", " ".join(self.desc.get(s, "") for s in self.spells_of(item)))
        return "well fed" in text.lower() or any(norm(self.spell_names.get(int(r), "")).endswith("well fed") for r in refs)

    def temp_enchant(self, item: int) -> bool:
        return any(e[0] == EFFECT_ENCHANT_ITEM_TEMPORARY for e in self.effects_of(item))

    def duration(self, item: int) -> int:
        """The longest base duration (ms) of the item's own spells; 0 when none is known."""
        return max([self.duration_ms.get(s, 0) for s in self.spells_of(item)] or [0])


# ---------------------------------------------------------------------------
# The rules: what each list admits, and the window its candidates come from
# ---------------------------------------------------------------------------

WEAPON_PHRASE = re.compile(r"\byour\b(?:\s+\w+){0,2}\s+weapons?\b", re.I)
STAT_WORDS = ("critical strike", "haste", "mastery", "versatility", "highest secondary stat", "primary stat")


def stat_note(text: str) -> Optional[str]:
    low = text.lower()
    found = [w for w in STAT_WORDS if w in low]
    return "stat: " + " + ".join(found) if found else None


def potion_lists(b: Build, item: int) -> List[str]:
    """Where a potion goes, the way core/Classifier.lua sorts one: heal -> HP_POT, mana -> MP_POT
    (both, for a potion that restores both), else a short buff with no absorb -> CMBT_POT."""
    out = []
    if b.heals(item):
        out.append("HP_POT")
    if b.restores_mana(item):
        out.append("MP_POT")
    if out:
        return out
    if b.absorbs(item):
        return []
    if 0 < b.duration(item) <= CMBT_POT_MAX_DURATION_MS:
        return ["CMBT_POT"]
    return []


def _consumable(b: Build, item: int, subs) -> bool:
    it = b.items.get(item)
    return bool(it) and it["class"] == 0 and (subs is None or it["sub"] in subs)


def _in_window(b: Build, item: int, expansions) -> bool:
    it = b.items.get(item)
    return bool(it) and (expansions is None or it["exp"] in expansions)


# Each rule: (window, admits). `window(b, item)` is the set a list draws candidates from, and
# `admits(b, item)` whether the list's own definition takes the item. A shipped id inside the window
# that the rule does not admit is an `unmatched` flag. Retail only; Forever has no rules (above).
RULES = {
    "FLASK": (lambda b, i: _consumable(b, i, {3}) and _in_window(b, i, {CURRENT_EXPANSION}),
              lambda b, i: _consumable(b, i, {3})),
    "HP_POT": (lambda b, i: _consumable(b, i, {1}) and _in_window(b, i, {CURRENT_EXPANSION}),
               lambda b, i: "HP_POT" in potion_lists(b, i)),
    "MP_POT": (lambda b, i: _consumable(b, i, {1}) and _in_window(b, i, {CURRENT_EXPANSION}),
               lambda b, i: "MP_POT" in potion_lists(b, i)),
    "CMBT_POT": (lambda b, i: _consumable(b, i, {1}) and _in_window(b, i, {CURRENT_EXPANSION}),
                 lambda b, i: "CMBT_POT" in potion_lists(b, i)),
    "STAT_FOOD": (lambda b, i: _consumable(b, i, {5}) and _in_window(b, i, {CURRENT_EXPANSION}),
                  lambda b, i: b.eaten(i) and b.well_fed(i)),
    "VANTUS": (lambda b, i: _consumable(b, i, {9}) and _in_window(b, i, {CURRENT_EXPANSION}),
               lambda b, i: "vantus rune" in norm(b.items[i]["name"])),
    # Defaults_WpnEnch.lua: the last two expansions (The War Within 10, Midnight 11).
    # The "your ... weapon" phrase is core/Classifier.lua's own key (tt.isWeaponEnhance); a temporary
    # enchant on a fishing pole or a profession tool is not a weapon enhancement.
    "WPN_ENCH": (lambda b, i: _consumable(b, i, {8}) and _in_window(b, i, {CURRENT_EXPANSION - 1, CURRENT_EXPANSION}),
                 lambda b, i: b.temp_enchant(i) and WEAPON_PHRASE.search(b.text_of(i)) is not None),
    # Defaults_AugRune.lua: any expansion (Legion on); the tooltip's "Augment Rune" marker is what
    # core/Classifier.lua keys on, so the spell's description is the window.
    "AUG_RUNE": (lambda b, i: _consumable(b, i, {8}) and "augment rune" in b.text_of(i).lower(),
                 lambda b, i: True),
}
# The lists with no mechanical rule, and why (the contract repeats this).
NO_RULE = {
    "FOOD": "the Silvermoon innkeeper's stock; vendor stock is not in DB2",
    "DRINK": "the Silvermoon innkeeper's stock; vendor stock is not in DB2",
    "HS": "a fixed two-entry whitelist (defaults/README.md, Procedure step 1)",
    "BLOODLUST": "class spells plus the drums, seed-plus-user-added only; ids pending in-game confirmation",
    "BATTLE_REZ": "class spells plus one item, seed-plus-user-added only; ids pending in-game confirmation",
    "CLASS_GATE": "keyed by a BLOODLUST spell; follows that list",
}


def item_notes(b: Build, item: int, shipped_names: Dict[str, int]) -> List[str]:
    it = b.items[item]
    notes = ["expansion %d, quality %d, item level %d" % (it["exp"], it["quality"], it["ilvl"])]
    if it["cq"]:
        notes.append("crafting quality %d" % it["cq"])
    twin = shipped_names.get(norm(it["name"]))
    if twin:
        notes.append("same name as shipped %d" % twin)
    for prefix in ("Fleeting ", "Hearty "):
        base = shipped_names.get(norm(it["name"][len(prefix):])) if it["name"].startswith(prefix) else None
        if base:
            notes.append("%s copy of shipped %d" % (prefix.strip(), base))
    effects = [w for w, f in (("heal", b.heals), ("mana", b.restores_mana), ("absorb", b.absorbs)) if f(item)]
    if effects:
        notes.append("effects: " + ", ".join(effects))
    if b.duration(item):
        notes.append("duration %ds" % (b.duration(item) // 1000))
    stat = stat_note(b.text_of(item))
    if stat:
        notes.append(stat)
    spells = b.spells_of(item)
    if spells:
        notes.append("use: %d %s: %s" % (spells[0], b.spell_names.get(spells[0], ""), b.text_of(item)[:160].strip()))
    return notes


def vantus_notes(b: Build, item: int) -> List[str]:
    text = b.text_of(item)
    found = re.search(r"targeted (?P<raids>.+?) raid boss", text)
    if not found:
        return []
    raids = [r.strip() for r in re.split(r",\s*(?:and\s+)?|\s+and\s+", found.group("raids")) if r.strip()]
    live = [r for r in raids if norm(r) in b.journal]
    missing = [r for r in raids if norm(r) not in b.journal]
    out = []
    if live:
        out.append("raid in the journal: " + ", ".join(live))
    if missing:
        out.append("raid not in the journal: " + ", ".join(missing))
    return out


# ---------------------------------------------------------------------------
# Flags and candidates
# ---------------------------------------------------------------------------

def id_text(rec: dict) -> str:
    return ("spell%d" % rec["id"]) if rec["kind"] == "spell" else str(rec["id"])


def flags_for(flavor: str, b: Build, lists: List[dict]) -> List[dict]:
    out = []
    for lst in lists:
        for rec in lst["records"]:
            kinds, name = [], ""
            if rec["kind"] == "priority":
                cls, spec = (int(x) for x in rec["id"].split("_"))
                row = b.specs.get(spec)
                if not row:
                    kinds.append("unnamed")
                else:
                    name = row["name"]
                    if row["class"] != cls:
                        kinds.append("misfiled")
                    if rec["comment"] and norm(comment_name(rec["comment"])) != norm(name):
                        kinds.append("renamed")
            elif rec["kind"] == "spell":
                name = b.spell_names.get(rec["id"], "")
                if not name:
                    kinds.append("unnamed")
                elif lst["named"] and rec["comment"] and norm(comment_name(rec["comment"])) != norm(name):
                    kinds.append("renamed")
            else:
                it = b.items.get(rec["id"])
                if not it:
                    kinds.append("unnamed")
                else:
                    name = it["name"]
                    if lst["named"] and rec["comment"] and norm(comment_name(rec["comment"])) != norm(name):
                        kinds.append("renamed")
                    fit = FIT[flavor].get(lst["list"])
                    if fit and (it["class"] != fit[0] or (fit[1] is not None and it["sub"] not in fit[1])):
                        kinds.append("misfiled")
                    rule = RULES.get(lst["list"]) if flavor == "retail" else None
                    if rule and rule[0](b, rec["id"]) and not rule[1](b, rec["id"]):
                        kinds.append("unmatched")
            for kind in kinds:
                out.append({"key": "shipped:%s:%s:%s" % (kind, lst["list"], id_text(rec)), "kind": kind,
                            "list": lst["list"], "id": id_text(rec), "name": name, "comment": rec["comment"],
                            "file": lst["file"].relative_to(lst["file"].parents[1]).as_posix()})
    return out


def candidates_for(flavor: str, b: Build, lists: List[dict]) -> Tuple[List[dict], List[dict]]:
    """`(candidates, unplaced)`. unplaced: current-expansion potions no rule places (an absorb, a
    long utility buff), reported for the analysis and never ruled."""
    if flavor != "retail":
        return [], []
    shipped: Dict[str, set] = defaultdict(set)
    shipped_names: Dict[str, int] = {}
    for lst in lists:
        for rec in lst["records"]:
            if rec["kind"] == "item":
                shipped[lst["list"]].add(rec["id"])
                if rec["id"] in b.items:
                    shipped_names.setdefault(norm(b.items[rec["id"]]["name"]), rec["id"])
    out, unplaced = spec_candidates(b, lists), []
    potion_ids = shipped["HP_POT"] | shipped["MP_POT"] | shipped["CMBT_POT"]
    for item in sorted(b.items):
        for key, (window, admits) in RULES.items():
            if key not in shipped or item in shipped[key] or not window(b, item) or not admits(b, item):
                continue
            notes = item_notes(b, item, shipped_names)
            if key == "VANTUS":
                notes += vantus_notes(b, item)
            out.append({"key": "%s:%d" % (key, item), "list": key, "id": str(item), "name": b.items[item]["name"],
                        "notes": notes})
        if (item not in potion_ids and RULES["HP_POT"][0](b, item) and not potion_lists(b, item)):
            unplaced.append({"id": item, "name": b.items[item]["name"], "notes": item_notes(b, item, shipped_names)})
    return out, unplaced


def spec_candidates(b: Build, lists: List[dict]) -> List[dict]:
    """A player spec (ClassID 1 on, OrderIndex 0-3, so neither a pet spec nor a class's "Initial"
    pre-spec) that STAT_PRIORITY has no `<classID>_<specID>` row for."""
    keys = {r["id"] for lst in lists if lst["list"] == "STAT_PRIORITY" for r in lst["records"]}
    if not keys:
        return []
    out = []
    for spec, row in sorted(b.specs.items()):
        key = "%d_%d" % (row["class"], spec)
        if row["class"] >= 1 and 0 <= row["order"] <= 3 and norm(row["name"]) != "initial" and key not in keys:
            out.append({"key": "STAT_PRIORITY:" + key, "list": "STAT_PRIORITY", "id": key, "name": row["name"],
                        "notes": ["class %d, order %d" % (row["class"], row["order"])]})
    return out


def coverage_gate(flavor: str, b: Build, lists: List[dict]) -> List[str]:
    """A rule that admits none of its own list's shipped in-window ids is a broken pipeline (a
    table shape changed, a join came up empty), not a list to rule on."""
    if flavor != "retail":
        return []
    problems = []
    for lst in lists:
        rule = RULES.get(lst["list"])
        ids = [r["id"] for r in lst["records"] if r["kind"] == "item"]
        if not rule or not ids:
            continue
        inside = [i for i in ids if i in b.items and rule[0](b, i)]
        if inside and not any(rule[1](b, i) for i in inside):
            problems.append("%s: the rule admits none of %s" % (lst["list"], ", ".join(map(str, inside))))
    return problems


# ---------------------------------------------------------------------------
# Bundles
# ---------------------------------------------------------------------------

def bundles(flavor: str, root: Path = RESEARCH) -> List[Path]:
    """Every finished bundle of the flavor (`<date>-<flavor>` holding a candidates.json), oldest first."""
    return sorted(p for p in root.glob("*-" + flavor) if (p / "candidates.json").exists())


def bundle_build(bundle: Path) -> str:
    return json.loads((bundle / "candidates.json").read_text(encoding="utf-8"))["build"]


def status_line(live: str, found: List[Path]) -> str:
    """`CURRENT <build> (<bundle>)` or `NEW <build> ...`: the first word is what
    /dev-copilot:validate-seeds reads."""
    if not found:
        return "NEW %s (no bundle yet)" % live
    last = found[-1]
    built = bundle_build(last)
    if built == live:
        return "CURRENT %s (%s)" % (live, last.name)
    return "NEW %s (last ruled %s, %s)" % (live, built, last.name)


def bundle_tables(flavor: str, bundle: Path, build: str, replay: bool, cache_dir: Path) -> Dict[str, Path]:
    out = {}
    for table, _why in TABLES[flavor]:
        member = bundle / "raw" / ("%s.csv.gz" % table)
        if replay:
            if not member.exists():
                raise SystemExit("--replay: %s is missing raw/%s.csv.gz." % (bundle, table))
        else:
            freeze(fetch_table(table, build, cache_dir), member)
        out[table] = member
    return out


def format_sources(flavor: str, build: str, created: str, date: str) -> str:
    lines = ["# Sources — seed validation, %s (%s)" % (date, flavor), "",
             "Written by `tools/seeds/seeds.py derive`. Frozen: never edited after the run.", "",
             "| Field | Value |", "| --- | --- |",
             "| Client | `%s` (wago.tools product `%s`) |" % (flavor, PRODUCTS[flavor]),
             "| Build | `%s` |" % build,
             "| Build created | %s |" % (created or "not recorded (pinned with `--build`, or replayed)"),
             "| Run date | %s (the `--date` argument; the tool never reads the clock) |" % date,
             "| Builds API | <%s> |" % BUILDS_URL, "", "## Tables", "",
             "| Table | Why | URL |", "| --- | --- | --- |"]
    for table, why in TABLES[flavor]:
        lines.append("| `%s` | %s | <%s> |" % (table, why, CSV_URL.format(table=table, build=build)))
    lines += ["", "The gzipped exports are in `raw/`. `seeds.py derive --replay` re-derives this bundle",
              "from them with no network and no cache.", ""]
    return "\n".join(lines)


def format_diff(doc: dict) -> str:
    lines = ["# Diff — %s, build %s" % (doc["flavor"], doc["build"]), "",
             "Written by `tools/seeds/seeds.py derive`: what the build proposes against what the addon ships.", "",
             "| List | Shipped ids | Flags | Candidates | Rule |", "| --- | --- | --- | --- | --- |"]
    for row in doc["lists"]:
        lines.append("| `%s` | %d | %d | %d | %s |" % (row["list"], row["shipped"], row["flags"], row["candidates"],
                                                       row["rule"]))
    lines.append("")
    if doc["unplaced"]:
        lines += ["## Current-expansion potions no rule places — %d" % len(doc["unplaced"]), "",
                  "Reported, never ruled: an absorb, a utility buff longer than 60 s, or no use spell.", ""]
        lines += ["- `%d` %s — %s" % (u["id"], _cell(u["name"]), _cell("; ".join(u["notes"][:3])))
                  for u in doc["unplaced"]]
        lines.append("")
    return "\n".join(lines)


def derive_doc(flavor: str, b: Build, lists: List[dict], build: str, date: str) -> dict:
    problems = coverage_gate(flavor, b, lists)
    if problems:
        raise SystemExit("Coverage gate FAILED: %s. Fix the pipeline before ruling anything." % "; ".join(problems))
    flags = flags_for(flavor, b, lists)
    cands, unplaced = candidates_for(flavor, b, lists)
    rows = []
    for lst in lists:
        rule = ("window + rule" if (flavor == "retail" and (lst["list"] in RULES or lst["list"] == "STAT_PRIORITY"))
                else NO_RULE.get(lst["list"], "flags only") if flavor == "retail"
                else "flags only: empty by decision (owner ruling 2026-11-08)")
        rows.append({"list": lst["list"], "shipped": len(lst["records"]),
                     "flags": sum(1 for f in flags if f["list"] == lst["list"]),
                     "candidates": sum(1 for c in cands if c["list"] == lst["list"]), "rule": rule})
    return {"flavor": flavor, "product": PRODUCTS[flavor], "build": build, "date": date,
            "tool": "tools/seeds/seeds.py derive", "lists": rows, "candidates": cands, "flags": flags,
            "unplaced": unplaced}


def load_candidates(bundle: Path) -> dict:
    path = bundle / "candidates.json"
    if not path.exists():
        raise SystemExit("%s has no candidates.json: run seeds.py derive first." % bundle)
    return json.loads(path.read_text(encoding="utf-8"))


def all_keys(doc: dict) -> List[str]:
    return [c["key"] for c in doc["candidates"]] + [f["key"] for f in doc["flags"]]


def unruled_keys(doc: dict, rulings: dict) -> List[str]:
    return [k for k in all_keys(doc) if k not in rulings]


# ---------------------------------------------------------------------------
# Rulings
# ---------------------------------------------------------------------------

def rulings_path(flavor: str) -> Path:
    return HERE / ("%s_rulings.json" % flavor)


def load_rulings(path: Path) -> dict:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def save_rulings(path: Path, rulings: dict) -> None:
    write_text(path, json.dumps(rulings, indent=2, sort_keys=True, ensure_ascii=False) + "\n")


def read_tsv(path: Path) -> List[Tuple[str, str, str]]:
    out = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) != 3:
            raise SystemExit("%s: a ruling line is key<TAB>ruling<TAB>reason; got %r" % (path, line))
        out.append((parts[0].strip(), parts[1].strip(), parts[2].strip()))
    return out


def set_ruling(rulings: dict, key: str, ruling: str, reason: str) -> None:
    match = KEY_RE.match(key)
    if not match:
        raise SystemExit("%r is not <LIST>:<id> or shipped:<kind>:<LIST>:<id>." % key)
    kind = match.group("kind")
    if kind and kind not in FLAG_KINDS:
        raise SystemExit("%r: unknown flag kind %r." % (key, kind))
    allowed = FLAG_RULINGS if kind else CANDIDATE_RULINGS
    if ruling not in allowed:
        raise SystemExit("the ruling for %s must be %s; got %r." % (key, " or ".join(allowed), ruling))
    reason = (reason or "").strip()
    if not reason or "\n" in reason:
        raise SystemExit("the reason for %s must be one non-empty line." % key)
    rulings[key] = {"ruling": ruling, "reason": reason}


# ---------------------------------------------------------------------------
# Apply
# ---------------------------------------------------------------------------

def plan_apply(doc: dict, rulings: dict) -> Tuple[List[dict], List[dict]]:
    """`(inserts, removals)`. Refuses while anything is unruled, and on an accept no writer
    exists for (a stat-priority key needs its secondary order, which no DB2 table holds)."""
    unruled = unruled_keys(doc, rulings)
    if unruled:
        raise SystemExit("apply refused: %d key(s) unruled (seeds.py check lists them)." % len(unruled))
    inserts = [c for c in doc["candidates"] if rulings[c["key"]]["ruling"] == "accept"]
    for c in inserts:
        if not c["id"].isdigit():
            raise SystemExit("apply refused: %s is accepted but has no writer; edit it by hand." % c["key"])
    removals = [f for f in doc["flags"] if rulings[f["key"]]["ruling"] == "remove"]
    return inserts, removals


def _record_id(rec: dict) -> str:
    return id_text(rec) if rec["kind"] != "priority" else rec["id"]


def edit_seed_file(path: Path, client: str, seed: str, adds: List[dict], drops: List[str], note: str) -> List[str]:
    """Insert `adds` at the end of `KCM.SEED.<seed>`'s `<client>` block and delete the `drops`
    (with any comment-only continuation lines under them). Keeps the file's line endings."""
    text = path.read_bytes().decode("utf-8")
    lines, nl = split_lines(text)
    block = next((b for b in parse_seed_text(text) if b["name"] == seed and b["client"] == client), None)
    if block is None:
        raise SystemExit("%s has no KCM.SEED.%s %s block." % (path, seed, client))
    if adds and block["open"] == block["close"]:
        raise SystemExit("%s: KCM.SEED.%s's %s block is written inline; open it by hand first." % (path, seed, client))
    have = {_record_id(r): r for r in block["records"]}
    changes, kill = [], set()
    for want in drops:
        rec = have.get(want)
        if not rec:
            continue
        kill.add(rec["line"])
        indent = len(re.match(r"^[ \t]*", lines[rec["line"]]).group(0))
        j = rec["line"] + 1
        while j < block["close"] and COMMENT_ONLY.match(lines[j]) and len(COMMENT_ONLY.match(lines[j]).group("indent")) > indent:
            kill.add(j)
            j += 1
        changes.append("%s %s: -%s" % (seed, client, want))
    indent = "        "
    if block["records"]:
        indent = re.match(r"^[ \t]*", lines[block["records"][0]["line"]]).group(0)
    new = []
    for c in adds:
        if c["id"] in have:
            continue
        new.append("%s%s,  -- %s; %s" % (indent, c["id"], c["name"], note))
        changes.append("%s %s: +%s" % (seed, client, c["id"]))
    if changes:
        out = [line for i, line in enumerate(lines[:block["close"]]) if i not in kill] + new + lines[block["close"]:]
        path.write_bytes(nl.join(out).encode("utf-8"))
    return changes


def edit_classifier(path: Path, table: str, adds: List[dict], drops: List[str], note: str) -> List[str]:
    text = path.read_bytes().decode("utf-8")
    lines, nl = split_lines(text)
    found = classifier_tables(text).get(table)
    if found is None:
        raise SystemExit("%s has no local %s table." % (path, table))
    have = {str(r["id"]): r for r in found["records"]}
    kill = {have[d]["line"] for d in drops if d in have}
    changes = ["%s: -%s" % (table, d) for d in drops if d in have]
    new = []
    for c in adds:
        if c["id"] not in have:
            new.append("    [%s] = true,  -- %s; %s" % (c["id"], c["name"], note))
            changes.append("%s: +%s" % (table, c["id"]))
    if changes:
        out = [line for i, line in enumerate(lines[:found["close"]]) if i not in kill] + new + lines[found["close"]:]
        path.write_bytes(nl.join(out).encode("utf-8"))
    return changes


def apply_bundle(doc: dict, rulings: dict, date: str, defaults: Path = DEFAULTS,
                 classifier: Path = CLASSIFIER) -> List[str]:
    inserts, removals = plan_apply(doc, rulings)
    flavor = doc["flavor"]
    note = "added from the %s wago.tools validation (%s)" % (date, doc["build"])
    files = {b["name"]: b["file"] for b in read_seed_lists(defaults)[flavor]}
    tables = {key: table for table, key, _cat, _named in CLASSIFIER_LISTS}
    changes: List[str] = []
    by_list: Dict[str, Tuple[list, list]] = defaultdict(lambda: ([], []))
    for c in inserts:
        by_list[c["list"]][0].append(c)
    for f in removals:
        by_list[f["list"]][1].append(f["id"])
    for key, (adds, drops) in sorted(by_list.items()):
        if key in tables:
            changes += edit_classifier(classifier, tables[key], adds, drops, note)
            continue
        if key not in files:
            raise SystemExit("apply: no seed file declares KCM.SEED.%s." % key)
        changes += edit_seed_file(files[key], flavor, key, adds, drops, note)
        if adds and key in CLASSIFIER_SYNC:
            changes += edit_classifier(classifier, CLASSIFIER_SYNC[key], adds, [], note)
    return changes


# ---------------------------------------------------------------------------
# RULINGS.md
# ---------------------------------------------------------------------------

def _cell(text: str) -> str:
    return (text or "").replace("|", "\\|").replace("\r", " ").replace("\n", " ")


def format_rulings_md(doc: dict, rulings: dict, date: str) -> str:
    cands, flags = doc["candidates"], doc["flags"]
    unruled = unruled_keys(doc, rulings)
    tally: Dict[str, int] = defaultdict(int)
    for key in all_keys(doc):
        tally[rulings.get(key, {}).get("ruling", "unruled")] += 1
    lines = ["# Rulings — seed validation, %s (%s, build %s)" % (doc["date"], doc["flavor"], doc["build"]), "",
             "Written by `tools/seeds/seeds.py report` on %s from this bundle's `candidates.json` and "
             "`tools/seeds/%s_rulings.json`. Do not edit by hand." % (date, doc["flavor"]), "",
             "%d candidates, %d flags: %s." % (len(cands), len(flags), ", ".join(
                 "%d %s" % (n, r) for r, n in sorted(tally.items())) or "none"), ""]
    if unruled:
        lines += ["## Unruled — %d" % len(unruled), ""] + ["- `%s`" % k for k in unruled] + [""]
    lines += ["## Shipped-id flags — %d" % len(flags), ""]
    if flags:
        lines += ["| Kind | List | Id | Build name | File comment | Ruling | Reason |",
                  "| --- | --- | --- | --- | --- | --- | --- |"]
        for f in flags:
            r = rulings.get(f["key"], {})
            lines.append("| %s | %s | `%s` | %s | %s | %s | %s |" % (
                f["kind"], f["list"], f["id"], _cell(f["name"]), _cell(f["comment"]),
                r.get("ruling", "**unruled**"), _cell(r.get("reason", ""))))
    else:
        lines.append("None.")
    lines += ["", "## Candidates — %d" % len(cands), ""]
    if not cands:
        lines += ["None.", ""]
    for key in sorted({c["list"] for c in cands}):
        rows = [c for c in cands if c["list"] == key]
        lines += ["### %s — %d" % (key, len(rows)), "",
                  "| Id | Name | Notes | Ruling | Reason |", "| --- | --- | --- | --- | --- |"]
        for c in rows:
            r = rulings.get(c["key"], {})
            lines.append("| `%s` | %s | %s | %s | %s |" % (c["id"], _cell(c["name"]), _cell("; ".join(c["notes"])),
                                                          r.get("ruling", "**unruled**"), _cell(r.get("reason", ""))))
        lines.append("")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def _date(value: str) -> str:
    if not DATE_RE.match(value):
        raise argparse.ArgumentTypeError("a date is YYYY-MM-DD; got %r" % value)
    return value


def _flavor_of(bundle: Path) -> str:
    for flavor in PRODUCTS:
        if bundle.name.endswith("-" + flavor):
            return flavor
    raise SystemExit("%s: a bundle is named <date>-<flavor> (retail or forever)." % bundle)


def cmd_status(args) -> int:
    for flavor in ([args.flavor] if args.flavor else list(PRODUCTS)):
        live, _created = live_build(PRODUCTS[flavor])
        line = status_line(live, bundles(flavor, args.root))
        print(line if args.flavor else "%s: %s" % (flavor, line))
    return 0


def cmd_derive(args) -> int:
    flavor = args.flavor
    if _flavor_of(args.bundle) != flavor:
        raise SystemExit("%s is not a %s bundle (name it <date>-%s)." % (args.bundle, flavor, flavor))
    created = ""
    if args.replay:
        build = args.build or (bundle_build(args.bundle) if (args.bundle / "candidates.json").exists() else None)
        if not build:
            raise SystemExit("--replay needs the bundle's candidates.json or --build.")
    elif args.build:
        build, created = args.build, build_created(PRODUCTS[flavor], args.build)
    else:
        build, created = live_build(PRODUCTS[flavor])
    log("Deriving %s against build %s" % (flavor, build))
    tables = bundle_tables(flavor, args.bundle, build, args.replay, args.cache_dir)
    b = Build(tables)
    doc = derive_doc(flavor, b, checked_lists(flavor), build, args.date)
    if args.replay and (args.bundle / "candidates.json").exists():
        if load_candidates(args.bundle) != json.loads(json.dumps(doc)):
            raise SystemExit("--replay: the re-derivation differs from %s/candidates.json, so the seeds have moved "
                             "since it was frozen (an apply, a hand edit). Replay a bundle at its own revision; "
                             "nothing was written." % args.bundle)
        log("--replay reproduces %s/candidates.json exactly." % args.bundle)
        return 0
    write_json(args.bundle / "candidates.json", doc)
    if not args.replay:
        write_text(args.bundle / "SOURCES.md", format_sources(flavor, build, created, args.date))
    write_text(args.bundle / "DIFF.md", format_diff(doc))
    unruled = unruled_keys(doc, load_rulings(args.rulings or rulings_path(flavor)))
    for row in doc["lists"]:
        log("  %-24s %3d shipped, %d flags, %d candidates" % (row["list"], row["shipped"], row["flags"], row["candidates"]))
    log("%d candidates, %d flags, %d unruled" % (len(doc["candidates"]), len(doc["flags"]), len(unruled)))
    return 0


def cmd_rule(args) -> int:
    todo = [(k, args.ruling, args.reason) for k in (args.key or ())]
    if args.tsv:
        todo += read_tsv(args.tsv)
    if not todo:
        raise SystemExit("rule needs --key (with --ruling and --reason) or --tsv.")
    doc = load_candidates(args.bundle)
    known = set(all_keys(doc))
    path = args.rulings or rulings_path(doc["flavor"])
    rulings = load_rulings(path)
    for key, ruling, reason in todo:
        if key not in known:
            raise SystemExit("%s is not a candidate or flag in %s/candidates.json." % (key, args.bundle))
        set_ruling(rulings, key, ruling, reason)
    save_rulings(path, rulings)
    log("Recorded %d ruling(s) in %s" % (len(todo), path))
    return 0


def cmd_check(args) -> int:
    doc = load_candidates(args.bundle)
    unruled = unruled_keys(doc, load_rulings(args.rulings or rulings_path(doc["flavor"])))
    if not unruled:
        print("OK: every candidate and flag in %s is ruled." % args.bundle.name)
        return 0
    rows = {c["key"]: c for c in doc["candidates"]}
    rows.update({f["key"]: f for f in doc["flags"]})
    print("%d unruled:" % len(unruled))
    for key in unruled:
        print("  %s  %s" % (key, rows[key]["name"]))
    return 1


def cmd_report(args) -> int:
    doc = load_candidates(args.bundle)
    rulings = load_rulings(args.rulings or rulings_path(doc["flavor"]))
    write_text(args.bundle / "RULINGS.md", format_rulings_md(doc, rulings, args.date))
    log("Wrote %s" % (args.bundle / "RULINGS.md"))
    return 0


def cmd_apply(args) -> int:
    doc = load_candidates(args.bundle)
    changes = apply_bundle(doc, load_rulings(args.rulings or rulings_path(doc["flavor"])), args.date)
    for line in changes:
        log("  " + line)
    log("%d change(s)" % len(changes))
    return 0


def parse_args(argv: Optional[List[str]]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate the consumable seed lists against a wago.tools build.",
                                     epilog="Contract: docs/validate-seeds.md.")
    parser.add_argument("--rulings", type=Path, default=None, help="the rulings file (default: <flavor>_rulings.json)")
    parser.add_argument("--cache-dir", type=Path, default=CACHE, help="the per-build download cache")
    sub = parser.add_subparsers(dest="command")
    sub.required = True
    status = sub.add_parser("status", help="is the newest bundle of each flavor of the live build?")
    status.add_argument("--flavor", choices=sorted(PRODUCTS))
    status.add_argument("--root", type=Path, default=RESEARCH)
    derive = sub.add_parser("derive", help="freeze the tables and write candidates.json, SOURCES.md, DIFF.md")
    derive.add_argument("--flavor", choices=sorted(PRODUCTS), required=True)
    derive.add_argument("--bundle", type=Path, required=True)
    derive.add_argument("--date", type=_date, required=True)
    derive.add_argument("--build", help="pin this build instead of the live one")
    derive.add_argument("--replay", action="store_true", help="read only the bundle's raw/, no network")
    rule = sub.add_parser("rule", help="record rulings (the only writer of the rulings file)")
    rule.add_argument("--bundle", type=Path, required=True)
    rule.add_argument("--key", action="append")
    rule.add_argument("--ruling")
    rule.add_argument("--reason")
    rule.add_argument("--tsv", type=Path)
    for name, helptext in (("check", "exit 1 while anything is unruled"),
                           ("report", "write the bundle's RULINGS.md"),
                           ("apply", "write accepted ids and ruled removals into the seed files")):
        cmd = sub.add_parser(name, help=helptext)
        cmd.add_argument("--bundle", type=Path, required=True)
        if name != "check":
            cmd.add_argument("--date", type=_date, required=True)
    return parser.parse_args(argv)


def main(argv: Optional[List[str]] = None) -> int:
    args = parse_args(argv)
    return {"status": cmd_status, "derive": cmd_derive, "rule": cmd_rule, "check": cmd_check,
            "report": cmd_report, "apply": cmd_apply}[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
