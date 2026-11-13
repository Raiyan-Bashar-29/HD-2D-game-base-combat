# Cross-Game RPG / Gacha Mechanics Encyclopedia — v1

**Snapshot date:** 2026-11-11

## What is included (actual measured coverage)

- 21 games
- 248 curated game-system and select named-skill entries
- 60 boss-mechanic entries (including some clearly marked generic encounter patterns)
- 20 unified analysis taxonomy families
- 16 cross-game comparison rows
- 20 original, simplified coding templates
- 59 links to source pages
- 80 prior **Last Cloudia name-only index** rows (36 ark names and 44 skill names)

**Scope warning**: This is a curated mechanics research snapshot, NOT every unit, skill, boss, item, passive, or update from any of the games. The previous Last Cloudia Goldmine extraction contained mostly names, NOT descriptions. Do not train or build as if it is a verified dump of the Goldmine database. Detailed game mechanics can change; consult linked sources when exact values matter. All logic snippets are ORIGINAL explanatory pseudocode, not copied implementation source.

## Start here

1. Open `encyclopedia.html` in any browser, even offline. Search for `break`, `Grand Summoners`, `Hod`, `Guts`, `Aventurine`, `Arknights`, etc.
2. Use `csv/01_all_abilities_mechanics.csv` for all mechanistic entries; filter by `game`, `family`, `layer_group`, or `ability_layer`.
3. Use `csv/02_boss_encounters.csv` to read a boss's phase, trigger, telegraph, behavior, counterplay, and simplified implementation.
4. Use `csv/03_mechanic_taxonomy.csv` for the shared category dictionary.
5. Use `csv/04_cross_game_comparisons.csv` to avoid conflating similar mechanics between games.
6. Use `csv/05_coding_templates.csv` if translating behaviors into software systems.
7. Game-specific files are under `by_game/`, and boss-specific game files are under `bosses_by_game/`.
8. Open `MECHANICS_STUDY_GUIDE.md` for detailed, beginner-friendly explanation.

## Data model

Each ability/mechanic row contains: game, owner/context, mechanic name, native ability layer, **unified family**, broad layer group, trigger, effect, counterplay, original implementation idea, source URL and verification caveat.

Boss rows contain: game, boss name, phase, precise triggering event (when available), telegraph, action, counter and code state-machine sketch.

## Important preservation and provenance rules

- Provenance lives in the `source_url` fields. They point to human-readable reference pages and may not point to an exact in-page anchor. This is a *research index*, not a website mirror.
- Named entries are partial examples. System entries must not be mistaken for a character-specific move.
- Numeric formulas are omitted where uncertain; a missing number is not zero.
- Names/rarity in the previous Last Cloudia starter are preserved as previously exported; their full game effects were **not** harvested.
- Do not automate frequent server requests without respecting the site's rate limits and terms.
- Normalize implementation into **events, conditions, resources, targets, effects, stacking, duration and phase changes**.
