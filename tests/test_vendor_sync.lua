-- tests/test_vendor_sync.lua — the vendored-payload gate, now one call of adoption
-- instead of ~150 hand-copied ones. The implementation lives in the payload it
-- checks, at `tests/_kit/vendor_sync.lua`, so a local patch to the kit breaks the
-- kit's own byte-identity assertion — which is the right outcome, because the fix
-- for a kit problem is upstream and re-vendor, never a local edit.
--
-- WHAT IT CHECKS: that `libs/LibKa0s/` and `tests/_kit/` in this repo are exactly
-- what the LibKa0s repo published at the tag THIS REPO'S `CLAUDE.md` says it
-- bundles.
--
-- THE PROVENANCE LINE IS AN INPUT, NOT A CONSTANT. It is read out of CLAUDE.md
-- rather than hardcoded: a provenance line and a vendored payload that disagree
-- is precisely the drift this file exists to catch, so the claim has to be the
-- thing under test. Bump the line and the bytes in the same commit.
--
-- IT USED TO READ README.md. Kit revision 9 (LibKa0s v1.8.1) moved the line to
-- `CLAUDE.md` — a maintainer's fact on a maintainer's page — as the README shed
-- its bundled-library inventory. There is deliberately no fallback: a repo that
-- re-vendors without moving its line fails here rather than sitting half-migrated
-- with two lines that can disagree.
--
-- ONE NORMALIZATION, AND ONLY ONE: `git show` hands back the stored blob, which
-- is LF, while the working tree is CRLF because `.gitattributes` pins
-- `* text=auto eol=crlf`. CR is stripped from the working-tree side so the file
-- is compared to the blob it round-trips to. Nothing else is normalized — a real
-- fork in content still fails.
--
-- A MISSING SIBLING CHECKOUT REPORTS A SKIP CARRYING ITS REASON, not a pass. The
-- copy this replaced returned early instead, which registered as PASS — "checked,
-- fine" for a comparison that never ran.
--
-- The case names come from the kit, and `docs/test-cases.md` counts them, so a
-- kit revision that renames one is a regeneration of that file in the same commit
-- — which is what revision 9 was here ("the README says" → "CLAUDE.md says").
--
-- THE ADAPTER THAT USED TO SIT HERE IS GONE. `VendorSync.register` takes the kit's
-- test table (`test`, `skip`, `assertTrue`, `assertEqual`), and the kit is this
-- repo's runner now, so `_G.KCM_TEST` already IS that table.

local h    = _G.KCM_TEST
local ROOT = _G.KCM_TEST_ROOT or "."

local VendorSync = dofile(ROOT .. "/tests/_kit/vendor_sync.lua")

VendorSync.register(h, { root = ROOT })
