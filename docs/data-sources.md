# Data sources

## Recipe records

Recipes.lua contains 2,258 structured records from the WoW Forever Wiki recipe index, imported on 18 October 2026. Each record retains its page URL and revision. Fields describe spell and item IDs, profession, ingredients, tools and client thresholds. The import reads factual tables and item links, not article prose or images. The source client build is recorded in F.source.

Source: https://wowfwiki.com/wiki/Recipes_database

## Learning hints

LearningData.lua includes metadata from Recipe Registry at revision 51ac643dcca757208eb5a31454ea59b6ca839d10, used under its MIT license. The full notice is packaged as RecipeRegistry-LICENSE.txt. The metadata import evaluates declarative Lua tables with a parser, not by executing downloaded add-on code.

Source: https://github.com/colettamattia91-cloud/Recipe-Registry/tree/51ac643dcca757208eb5a31454ea59b6ca839d10

Additional factual checks use ForeverEra client records, Forever Talents merchant and quest records, and source links stored with individual entries. Old Classic/TBC learning-skill fallbacks were removed where unverified. Acquisition hints remain labeled with their evidence limits. Minimum character level is read from the teaching item when available, rather than from crafted equipment.

## Crates and bags

StorageData.lua records 30 crates with 96 alternative material bundles and 31 bags. It uses ForeverEra item records, Eternadex crate requirements and Zockify NPC names. Each entry preserves source URLs. Unresolved material IDs cannot produce a ready-to-turn-in result.

## Scope

These tables contain game facts and source references. They contain no ARL database records. Website pages, downloaded client files and import caches are excluded. The project's code license does not relicense third-party databases, game assets or trademarks. Retain the notices and evidence labels when reusing data.
