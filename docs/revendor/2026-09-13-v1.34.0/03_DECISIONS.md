# 03 — Decisions

This run was non-interactive. The orchestrator's instruction settled it in advance: re-vendor the
whole payload, roll every live bundled-version reference, bring the harness's AceDB fake into line
with AceDB's reset signature, pin a multi-word string value if a real string row exists, and make
the Reset-all tooltip meet `options-ui-§12`'s SHOULD. No interview was held. As instructed, no issue
was filed and nothing was pushed.

| Candidate | Outcome | Basis | Record |
|---|---|---|---|
| Slash minor 10, whole-value string rows | **taken as it arrives**, and pinned | No host change: `settings/Slash.lua`'s `parse` hands string rows to the library. The affected rows are the LSM names | `tests/test_slashsetup.lua`, the multi-word font case |
| Options 18 / Compose 5, the Reset-all tooltip | **adopted**: `resetProfile` + `profilesPage = true` | The button is the composer's, so the descriptor is the only lever. `O.RestoreAllDefaults` is unreachable in this addon, so the field changes the tooltip and nothing else | The next commit; `docs/settings-panel.md`, `docs/smoke-tests.md` |
| Kit revision 19, no key on a reset | **matched in the harness's own fake** | The harness overrides the kit's AceDB. Nothing read the key | `tests/wow_mock.lua` `fire` |
| Pool | settled, unused | The premise is unchanged at Pool minor 3 | None |
