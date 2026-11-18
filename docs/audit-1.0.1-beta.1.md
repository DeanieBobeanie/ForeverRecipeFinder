# Update audit for 1.0.1-beta.1

Reviewed on 18 November 2026 against the first public beta, commit `592e15e`. The review covered runtime behavior, catalog structure, build dependencies and release packaging. Separate reviewers checked runtime and UI changes after implementation.

## Fixed findings

| Finding | Change | Verification |
| --- | --- | --- |
| A closed profession could leave ready recipe and skill data in the API cache. Delayed updates could scan that cache. | Remember explicit closure and cancel queued scans across close and reopen events. Preserve API-only scanning before a close event. | Runtime tests cover closed caches, delayed callbacks and reopening. |
| Legacy and Craft scans could finish before all rows or localized spell names arrived. | Retry incomplete rows and rebuild the profession's name lookup. | Tests cover partial lists and late localized names. |
| Imported requirements could contradict a current affordable trainer offer. | Give the live offer precedence in eligibility. | A conflicting skill and level fixture still reports the live offer. |
| Merchant updates after closing could record a different NPC as a source. | Scan merchant updates only during an open merchant interaction. | A late update leaves the recorded merchant unchanged. |
| Storage tooltips could hide or reclaim a tooltip belonging to another control. | Check ownership on mouse-leave, native updates and item-data events. | Tests keep another control's tooltip visible and owned by that control. |
| Smoked Desert Dumplings had an unsupported skill-285 fallback. | Remove that requirement and retain the quest route as an unverified hint. | Catalog checks require specific evidence for every numeric learning-skill requirement. |
| Package metadata could disagree with the TOC, and tag checks depended on the working directory. | Share configuration validation between packaging and tag checks. Reject inconsistent versions and unsafe archive paths. | Nine isolated packaging tests pass. |

## Player improvement

The Materials tab shows carried ingredients, missing amounts and the number of crafts those materials cover. It combines repeated reagent IDs, preserves unknown quantities and counts, and refreshes when bag contents change. The estimate excludes bank and alt items. It does not establish that the character knows the recipe or has the required tools.

## Data audit

The catalog contains 2,258 recipes and 2,232 learning records. The review found no duplicate recipe or storage IDs, orphaned learning records, invalid ingredient quantities or out-of-range recorded coordinates. There are 30 crates with 96 alternative bundles and 31 bags.

After the correction, 1,694 recipes have a recorded learning-skill requirement with specific evidence. There are 26 recipes without a learning entry, 599 learning records with an unknown source and 111 recipes reported unavailable. Those limits remain visible. The unresolved Dark Iron Ore material ID remains unknown and cannot make its crate appear ready.

The [wiki recipe index](https://wowfwiki.com/wiki/Recipes_database) still lists 2,258 records. [ForeverEra's Cooking table](https://theforeverera.com/en/guides/professions/cooking/#r-24801) leaves the learning skill for Smoked Desert Dumplings unknown. This review did not revalidate every acquisition source or replace the catalog with a new import.

## Validation

- `npm ci --ignore-scripts` installed the declared test dependencies.
- `npm test` passed Lua 5.1 parsing, the existing behavior checks, catalog integrity checks and the new runtime and UI regressions.
- `python tools/test_package.py` passed all nine packaging tests.
- `python tools/package.py` built and verified the 13-file installable ZIP against the explicit manifest and source bytes.
- `npm audit` reported zero known vulnerabilities. GitHub [withdrew the earlier sprintf-js advisory](https://github.com/advisories/GHSA-hp3w-g68c-fv3c).
- `git diff --check` passed.

No actionable defects remain from the reviewed changes. These results cover mocked game APIs and package construction. The candidate has not been tested inside WoW. It still targets Forever 1.60.1, interface 16001, and no compatibility with a newer build is claimed.

An unmatched legacy recipe name still receives the general loading message after bounded retries. The API does not distinguish delayed localized names from recipes outside this catalog.

The package retains its third-party notices and excludes the earlier ARL runtime, database, libraries and artwork. The [original provenance review](origin-review.md) remains a record of the first beta and was not rerun as an authorship certification.

## In-game checks before release

1. Open and close a profession during loading. Reopen it and confirm scanning resumes.
2. Open a recipe's Materials tab, change a carried ingredient quantity and confirm its count and shortfall update.
3. Check trainer offers and inspect crate and bag tooltips alongside another add-on's tooltips.
4. Confirm the existing recipe, crate and bag browsers still work on the intended Forever client.
