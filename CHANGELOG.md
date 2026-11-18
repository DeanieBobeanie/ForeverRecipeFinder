# Changes

## 1.0.1-beta.1, unreleased

- The Materials tab now shows carried ingredients, missing quantities and the number of crafts those materials cover. It refreshes when bag contents change. Unknown counts stay unknown.
- Closing a profession stops delayed updates from treating its cached recipe list or skill rank as current. Reopening it permits scanning again.
- Legacy profession and Craft scans retry incomplete rows and delayed localized spell names.
- Current affordable trainer offers take precedence over conflicting imported skill and level requirements. Late merchant updates after the merchant closes no longer record sources against another NPC.
- Crate and bag tooltips respect other controls' tooltip ownership.
- Smoked Desert Dumplings no longer shows an unverified skill-285 requirement.
- Catalog integrity checks and packaging regression checks now accompany the runtime tests.

The target remains WoW Forever 1.60.1, interface 16001. The catalog still contains 2,258 recipes, 30 crates and 31 bags. Automated checks use mocked game APIs. This candidate has not been tested in the game.
