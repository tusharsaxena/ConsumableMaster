Delta: LibKa0s v1.16.0 -> v1.54.2 (span: v1.16.0 v1.18.0 v1.18.1 v1.19.0 v1.23.0 v1.24.0 v1.26.0 v1.27.0 v1.28.0 v1.29.0 v1.35.0 v1.36.0 v1.36.1 v1.36.2 v1.37.0 v1.38.0 v1.39.0 v1.42.0 v1.43.0 v1.44.0 v1.45.0 v1.46.1 v1.47.0 v1.48.0 v1.48.1 v1.50.0 v1.51.0 v1.52.0 v1.53.0 v1.54.2)

# 01 - Delta: the consolidated span bundle

Written 2026-09-24 for plan item CM-28 of the 2026-09-23 review and standards-audit remediation
(finding ConsumableMaster-A-02, audit row CM-91), on branch `feat/2026-09-23-review-audit-remediation`.
This is the record `audit-review-history` (standard v2.65.0) sanctions for a lapsed span: one folder
named for the first and last unrecorded tags, holding `01_DELTA.md` and `05_SUMMARY.md` only. Each
re-vendor recorded here was done and gated when it landed. Nothing is re-vendored now, and no code
changes. The per-tag deliberation files (02 to 04) are left out on purpose. The sweeps that carried
this span recorded no deliberation, and no per-tag back-fill folders are written.

## The true previous base

Line 1 names the first and last **unrecorded** tags. It does not name a delta base. The last tag
this store recorded before the span is **v1.15.0** (`docs/revendor/2026-08-25/`, the store's first
bundle and the audit horizon), vendored at `295def5` ("chore(libs): re-vendor LibKa0s v1.15.0, and
the test kit it is bound to"). `CLAUDE.md` at `0dd978e^`, the parent of the span's first vendoring
commit, names v1.15.0 on its provenance line. As a delta, the span therefore runs
**v1.15.0 -> v1.54.2**. The next recorded bundle, `docs/revendor/2026-09-23-v1.55.0/`, correctly
names v1.54.2 as its base (the kit-only re-vendor at `1f86d4e`), so that frozen bundle stays as it is.

Seven tags in that range already have their own bundles, so they are **not** in the span list:
v1.25.0 (`2026-09-03/`), v1.30.0 (`2026-09-12/`), v1.31.0, v1.32.0 and v1.33.0
(`2026-09-12-v1.3x.0/`), and v1.34.0 (`2026-09-13-v1.34.0/`). The bare-dated `2026-09-03/` also names
v1.24.0 on its line 1, as its base. The audit reads only the last tag from a bare-dated line 1, so
v1.24.0 counts as unrecorded and is listed here. A tag recorded twice costs nothing.

Library tags in the range that this addon never vendored are not in the span, because this addon
never carried them: v1.17.0, v1.20.0, v1.21.0, v1.22.0, v1.40.0, v1.41.0, v1.46.0, v1.49.0,
v1.49.1, v1.54.0 and v1.54.1.

## How the list was derived

The `AUDIT.md` re-vendor comparison (WowAddonStandards v2.65.0), run before this bundle existed:

```sh
horizon=$(ls -1 docs/revendor | sort | head -1 | cut -c1-10)          # -> 2026-08-25
git log --since="$horizon 00:00" --format=%H -- libs/LibKa0s tests/_kit | while read -r c; do
  git show "$c:CLAUDE.md" 2>/dev/null |
    grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9]+\.[0-9]+\.[0-9]+' |
    grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1
done | sort -uV > vendored.txt                                        # 39 tags
# recorded.txt: the recorded-side loop over docs/revendor/*/           # 9 tags
grep -vxF -f recorded.txt vendored.txt                                 # 30 tags, the span above
```

The `revendor-libka0s` 3h variant, which also walks `CLAUDE.md` commits that roll the provenance
line, gives the same 39 vendored tags, so no tag arrived as a provenance roll alone. Every in-scope
commit resolved a tag from its `CLAUDE.md` provenance line. After this bundle, the same comparison
prints nothing. The v1.56.0 bundle's 3h (`2026-09-23-v1.56.0/01_DELTA.md`) listed the same 30 tags
and handed them to this item.

**Correction to the item text.** CM-28 and the audit (CM-91) named 27 tags, v1.18.0 to v1.53.0,
with a base of "v1.17.x". That count used a bare-date `--since`, which drops the horizon day's own
commits (v1.16.0 on 2026-08-25), and it walked `libs/LibKa0s` alone, which misses the kit-only
v1.43.0 and v1.54.2 re-vendors. This addon never vendored v1.17.0, so the true base is v1.15.0. The
v2.65.0 comparison finds 30 tags in 37 commits. The folder is named for the span it actually
covers, `2026-09-24-v1.16.0-v1.54.2`, not the item's `v1.18.0-v1.53.0`.

## The 37 vendoring commits

"Carried by" names the branch whose merge brought the commit to `master` (the first commit on
`master`'s first-parent chain that contains it), or "on master" when the commit was made on
`master` itself. "Folded" means the copy rode inside a feature commit rather than standing alone.
`versioning-git` makes the standalone commit a SHOULD, not a MUST. A tag that appears on several
rows was carried by more than one commit: the v1.19.0 line went up with a pre-release `Widgets.lua`
before the released copy, and the v1.35.0 tag was re-cut four times.

| Tag | Commit | Date | Subject | Carried by |
|---|---|---|---|---|
| v1.16.0 | `0dd978e` | 2026-08-25 | Re-vendor LibKa0s v1.16.0 | on master |
| v1.18.0 | `f8cdd15` | 2026-08-26 | Adopt options-ui-§12: the reset is a profile reset, and wire the profile callbacks it needs | on master; folded |
| v1.18.1 | `ad086c9` | 2026-08-26 | Re-vendor LibKa0s v1.18.1: the landing logo stops pooling its texture | on master |
| v1.19.0 | `65e5a87` | 2026-08-27 | Drag a priority row where you want it, instead of clicking it there | reorder-list-widget (merged `9b450da`); folded, pre-release `Widgets.lua` |
| v1.19.0 | `2013d96` | 2026-08-27 | Put the drag handle at the head of a priority row | same branch; pre-release `Widgets.lua` |
| v1.19.0 | `0925734` | 2026-08-27 | Cancel the drag before clearing the page, not after | same branch; pre-release `Widgets.lua` |
| v1.19.0 | `c2f369a` | 2026-08-27 | Carry LibKa0s v1.19.0 | same branch; the released copy |
| v1.23.0 | `988139d` | 2026-09-01 | Re-vendor LibKa0s v1.23.0: the tabbed page and the page banner arrive | on master |
| v1.24.0 | `ab4c564` | 2026-09-02 | feat(settings): tabbed General, drag-reorder on the AIO tabs, stat priority by drag | feat/settings-revamp-v2 (merged `69a4d56`); folded |
| v1.26.0 | `ac37b2a` | 2026-09-08 | M3-04: ConsumableMaster takes LibKa0s v1.26.0, and the media workaround comes out | feat/2026-09-07-audit-review-remediation (merged `5b01450`) |
| v1.27.0 | `44f8757` | 2026-09-08 | M4-01: adopt LibKa0s v1.27.0, and wire the gate that came with it | same branch |
| v1.28.0 | `869dd43` | 2026-09-09 | re-vendor LibKa0s v1.28.0 - the perf usage block renders correctly | on master |
| v1.29.0 | `e496a9e` | 2026-09-09 | re-vendor LibKa0s v1.29.0 - the JSON dump folds into the report step | on master |
| v1.35.0 | `193f4b9` | 2026-09-13 | Re-vendor LibKa0s v1.35.0 (Options 18.16.5.3, kit 20) | feat/2026-09-13-idlist (merged `898be87`) |
| v1.35.0 | `d375596` | 2026-09-13 | Re-vendor LibKa0s v1.35.0 (re-cut: IdList quality color, load batching, clear before onAdd) | same branch; tag re-cut |
| v1.35.0 | `f962fad` | 2026-09-13 | Re-vendor LibKa0s v1.35.0 (re-cut: autocomplete #31, name lookup beyond the bags) | same branch; tag re-cut |
| v1.35.0 | `dcab736` | 2026-09-14 | Re-vendor LibKa0s v1.35.0 (re-cut at 80b8d15: a shared name the bags carry) | same branch; tag re-cut |
| v1.35.0 | `5ecff5a` | 2026-09-14 | Re-vendor LibKa0s v1.35.0 (re-cut: host kinds inherit a base kind's decorations) | same branch; tag re-cut |
| v1.36.0 | `926d26d` | 2026-09-15 | Re-vendor LibKa0s v1.36.0 | chore/2026-09-14-revendor-v1.36.0 (merged `004ffd7`) |
| v1.36.1 | `7256d0f` | 2026-09-15 | Re-vendor LibKa0s v1.36.1: fix pooled CheckBox gold-fill leak | same branch |
| v1.36.2 | `66fb9d8` | 2026-09-15 | Re-vendor LibKa0s v1.36.2: drop grid-cell yellow fill, ASCII-only strings | same branch |
| v1.37.0 | `e91a3e3` | 2026-09-16 | Re-vendor LibKa0s v1.37.0 | on master |
| v1.38.0 | `c4e832d` | 2026-09-16 | Re-vendor LibKa0s v1.38.0: a bare /cm opens the settings panel | on master |
| v1.39.0 | `48e3fcf` | 2026-09-16 | Re-vendor LibKa0s v1.39.0: the Launcher major and the peeled Options tabs | on master |
| v1.42.0 | `a6e592e` | 2026-09-17 | Disabling the addon stands it down, and a perf run takes the same latch | on master; folded (the stand-down feature) |
| v1.43.0 | `c567d59` | 2026-09-17 | Re-vendor LibKa0s v1.43.0: kit revision 23 bounds every run and stops holding built instances | on master; kit only |
| v1.44.0 | `6c4e0a0` | 2026-09-19 | Re-vendor LibKa0s v1.44.0 | chore/libka0s-v1.44.0 (merged `a3158a3`) |
| v1.45.0 | `390fb40` | 2026-09-19 | Re-vendor LibKa0s v1.45.0 | chore/libka0s-v1.45.0 (merged `48d447d`) |
| v1.46.1 | `ff0832d` | 2026-09-19 | Re-vendor LibKa0s v1.46.1 | chore/libka0s-v1.46.1 (merged `dd78f2b`) |
| v1.47.0 | `db60c5d` | 2026-09-20 | Re-vendor LibKa0s v1.47.0 | chore/revendor-libka0s-v1.47.0 (merged `c6c345e`) |
| v1.48.0 | `82e0dc0` | 2026-09-21 | Re-vendor LibKa0s v1.48.0 and hand the drag handle to the library | chore/revendor-libka0s-v1.47.0 (merged `c6c345e`); adoption in the same commit |
| v1.48.1 | `2794e3f` | 2026-09-21 | Re-vendor LibKa0s v1.48.1, and cover the tooltips the adoption was for | same branch |
| v1.50.0 | `b039f27` | 2026-09-21 | Re-vendor LibKa0s v1.50.0 | on master |
| v1.51.0 | `62d95a8` | 2026-09-22 | Re-vendor LibKa0s v1.51.0 | on master |
| v1.52.0 | `fb73652` | 2026-09-22 | Re-vendor LibKa0s v1.52.0 | on master |
| v1.53.0 | `b1c9d5c` | 2026-09-22 | Re-vendor LibKa0s v1.53.0 | on master |
| v1.54.2 | `1f86d4e` | 2026-09-22 | Adopt the kit's US-English gate, and delete the copy this repo was keeping | on master; kit only (revision 24, library bytes identical to v1.53.0) |

Each commit rolled the `CLAUDE.md` provenance line with the payload, which
`tests/test_vendor_sync.lua` enforces by diffing both payloads against the tag the line names. Each
was green on lint and the headless suite when it landed, and the commit bodies record the counts.
