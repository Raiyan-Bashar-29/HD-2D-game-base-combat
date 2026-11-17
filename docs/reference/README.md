# Reference lists from the owner

Planning material, not game content. Nothing here is loaded by the game, and no name in these
files may appear under `src/` or `tests/`.

| File | What it is |
|---|---|
| `originals/Fictional_Powers_Execution_Logic_Claude_Pack.zip` | The owner's whole powers pack (2026-11-10), unchanged. 4.9 MB zipped, 45 MB unpacked |
| `originals/fictional_weapons_multiverse_with_image_links.csv` | The owner's whole weapons list (2026-11-10), unchanged, with image links |
| `weapon_ideas.csv` | The weapons list without the image columns. Read with [`../GEAR.md`](../GEAR.md) § The mechanism catalogue |
| `power_atlas.csv` | One row per power (3,306), cut from the pack |
| `power_handlers.csv` | One row per handler family (116), cut from the pack |
| `originals/RPG_Gacha_Mechanics_Encyclopedia_v1.zip` | The owner's mechanics encyclopedia (2026-11-13), unchanged |
| `originals/last_cloudia_verified_starter_records.csv` | The owner's Last Cloudia names list (2026-11-13): names only, no effects |
| `mechanics_encyclopedia/` | The encyclopedia unpacked, without its spreadsheet and web page (they repeat the CSVs). A curated snapshot, not a full database. Read with [`../PASSIVES.md`](../PASSIVES.md) |
| `power_pack/` | The pack's three guide pages and all its character profiles |

[`../POWER_ATLAS.md`](../POWER_ATLAS.md) sorts every family onto the mechanism that runs it.

## Unpacking the pack

```bash
mkdir -p /tmp/power_pack && unzip -q docs/reference/originals/Fictional_Powers_Execution_Logic_Claude_Pack.zip -d /tmp/power_pack
```

Inside: `fictional_powers_claude_code_ready.json` (every power with its full coding logic and
pseudocode, 20 MB), `fictional_character_profiles.json`, the same data as CSV, XLSX, HTML and
Markdown, and `characters/`. Unpack it outside the repository; the big files are not committed
on their own because they repeat the same data five times.

`*.zip` is in `.gitignore`, so the pack was added with `git add -f`. It stays tracked.
