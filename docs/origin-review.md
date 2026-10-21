# Origin review

Reviewed on 21 October 2026 for the first standalone beta.

The starting workspace contained an ARL 9.2.0 package and a separate Forever implementation loaded by a replacement TOC. This repository includes only that active implementation and its independently sourced data, with a new add-on identity. The original ARL package remains outside this repository.

## Review performed

The five active implementation files were compared against every Lua file in an unmodified ARL 9.2.0 extraction. The check searched consecutive tokens with comments removed, then repeated the search with identifiers and literals normalized. Generated data was reviewed separately through its import sources.

No exact 20-token matches were found against ARL's own code, excluding bundled libraries. At 40 exact tokens, the only candidates were a standard native dialog backdrop configuration shared with bundled AceGUI. No 80-token normalized matches were found. Manual review found no ARL-specific implementation in the active files. The shared dialog settings were replaced with a plain background and native tooltip border.

The published package excludes ARL's Core, Interface, Database, Objects, Locales, libraries, textures, metadata and original TOC. It does not use ARL as a dependency. It registers /frf and /recipefinder, uses ForeverRecipeFinderDB, and does not read or modify ARL saved data.

Token comparisons help find copied sections. They cannot establish independent authorship or rule out every similarity. This review is an engineering provenance check, not a legal certification. If a contribution introduces a provenance concern, remove or independently replace it before distribution.

## Credit

Ackis Recipe List inspired the recipe collection idea. Credit belongs to Ackis, Torhal, Ressy and the ARL contributors. Inspiration credit is not a grant of permission to distribute ARL. No permission for the earlier adapted full package is assumed by this release.

https://github.com/Ackis/AckisRecipeList
