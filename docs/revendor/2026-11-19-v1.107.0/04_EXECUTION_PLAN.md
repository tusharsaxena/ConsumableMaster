# 04 Execution plan

1. AF-RV-CM: copy both payloads from the tag, roll the provenance line, prune, gate, and refresh the standards
   reference to v2.115.0 (the vendored quirks block). One commit.
2. AF-STRIP-CM: test first (`tests/test_macrobar_chrome.lua`: the gear opens the `macrobar` page, the X's tooltip
   names every way back), then `modules/MacroBar.lua` (`settings` as a function) and `settings/OptionsShim.lua`
   (`O.Open(pageKey)`), the doc ripple and new smoke checks. Its own commit.
