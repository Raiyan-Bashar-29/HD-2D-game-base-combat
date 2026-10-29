# Starting a new game on this template

The strip-and-start checklist. Read [`TEMPLATE.md`](TEMPLATE.md) first — it says *why* the
boundary exists; this says *what to delete* and *what to rename*.

**[`UPGRADING.md`](UPGRADING.md) is the sibling document**, and the one to read second: this says
how to LEAVE the template, that says how to stay in touch with it and receive a later fix. Set up
its `template` remote on the day you fork, not the day you need it.

**The one-line version:** delete `data/**` and `scenes/areas/**`, prune the demo half of
`localization/strings.csv`, rename five fields in `project.godot`, and never edit `src/`.

**The test that you did it right** is at the bottom, and it is mechanical: the ladder still goes
green on an empty game, and `tools/check_boundary.gd` still exits 0.

---

## 1. Delete

| Delete | Why it is demo |
|---|---|
| `data/items/*.tres` | the rose key, the petal, the stone chip |
| `data/dialogue/*.tres` | the gardener conversation |
| `data/schedules/*.tres` | the keeper's timetable |
| `data/actions/*.tres` | barter and scrutinise |
| `data/quests/*.tres` | the keeper's errand |
| `data/areas/*.tres` | where the two demo areas sit on the world map |
| `scenes/areas/courtyard/`, `scenes/areas/lantern_hall/` | the two demo areas, and everything placed in them |

**Keep the folders themselves.** `data/items/`, `data/dialogue/`, `data/schedules/`,
`data/actions/`, `data/quests/`, `data/areas/` and `scenes/areas/` are the **content roots the
registries scan**. `ItemDb`, `DialogueDb`, `ScheduleDb`, `QuestDb` and `AreaDb` find content by
directory scan (ADR-0006) — no registration list,
no code per item — so an empty folder is the correct empty state and a missing one is not.

```bash
rm -f data/items/*.tres data/dialogue/*.tres data/schedules/*.tres data/actions/*.tres
rm -f data/quests/*.tres data/areas/*.tres
rm -rf scenes/areas/courtyard scenes/areas/lantern_hall
```

## 2. Keep, and never edit to start a game

| Keep | What it is |
|---|---|
| `src/**` | **The engine. All of it.** Editing it to start a game is the failure this template exists to prevent. |
| `scenes/objects/`, `scenes/characters/`, `scenes/boot/` | reusable prefabs — a sign, a gate, a chest, a lever, a door, the player, an NPC, the boot tree |
| `tools/**`, `tests/framework/**` | the ladder |
| `assets/placeholder/**` | procedural art. Regenerate with `tools/gen_placeholders.gd`. |
| `assets/fonts/**` | the font fallback chain: Noto Sans Bengali and a Noto Sans SC subset, each with its OFL. Latin draws in the engine's own font; these catch what it lacks. **3.3 MB.** To add a script, append to `font_chain.tres`. To bring your own type, set `default_font` in your theme and give it fallbacks. To ship without a script, see [`ART_CONTRACT.md`](ART_CONTRACT.md) § Fonts |
| `localization/strings.csv` | **partly** — see below |
| `tests/unit/**` | the ladder — since T1.3 it builds its own content and passes without yours |
| **your own code root** | `game/`, or scripts beside your areas. **The base ships none and names none** — pick one. Your Tier 2 subclasses live here, and T5.30 measured that **no checker scans it** |

**YOUR OWN PLAYER PREFAB IS THE ONE EXCEPTION, AND YOU DO NOT EDIT ANYTHING TO GET IT.** The
protagonist is the first thing most games replace, and `scenes/characters/player.tscn` is Engine —
so instead of editing it, point past it: **`[game] world/player_scene`** in `project.godot` names
the scene `GameRoot` spawns once per session. Set it to your own, keep the template's prefab where
it is, and delete the key if you want the template's back. Until T5.29 that path was a `const` in
`src/core/boot/game_root.gd`, which made swapping the player a `src/` edit — a template *rule*
wearing a template *default*'s clothes, in the exact sense
[`ADR-0007`](decisions/ADR-0007-template-default-vs-game-choice.md) defines. Your scene needs
whatever `Director` repositions and `InteractionSensor` lives on; the template's prefab is the
worked example of that shape.

## 3. Prune the localization CSV

`localization/strings.csv` is the one mixed file. **Delete every row whose key starts with:**

```
area.        talk.        action.        object.       quest.
item.        — EXCEPT every item.category.* row, which is engine
```

Everything else is engine and stays: `ui.*`, `verb.*`, `refusal.*`, `notify.*`, `weather.*`,
`time.*` and `item.category.*`. (There are no `keys.*` rows — the rebinding labels are `ui.action.*`.)

```bash
awk '!/^(area|talk|action|object|quest)\./ && (!/^item\./ || /^item\.category\./)' \
  localization/strings.csv > /tmp/pruned.csv   # keeps 168 of 219 rows; review, then move it back
```

**Three traps in this file:**

1. **A value containing a comma MUST be quoted**, or the CSV parser silently truncates it at the
   comma and `tr()` still returns a plausible-looking string. This shipped a half-sentence for
   three packages. `tools/check_content.gd` fails any row that parses to more than two columns.
2. **`ui.menu.title` holds the game's NAME**, not a UI label. It is an engine key with a
   game-specific value — change the value, keep the key.
3. **A GATE CHECKS THIS FILE NOW, AND IT DID NOT UNTIL T5.4.** `check_boundary.gd` fails on an
   ORPHAN row — one translating content that is not in `data/` or `scenes/areas/` — so if you
   delete the demo and miss a prefix above, **rung 7 goes red and names the row**. That is what
   the paragraph here used to say was impossible. It came from a real failure: `quest.` was
   missing from this list from WP-08 until T4.3, and a fork that followed this document shipped
   the demo's `quest.keepers_errand.*` rows — "The Keeper's Errand", "three rose petals" —
   inside its own game, with all four checkers and the whole suite green.

   **Two namespaces are still yours to check by eye.** `object.` and `action.` keys are authored
   freely and match no id, so nothing can derive whether they are orphaned. The gate reports
   them in its count and cannot fail on them. So after pruning, still grep the result for the
   demo's vocabulary and expect nothing back:

```bash
grep -niE 'keeper|gardener|courtyard|lantern|rose|petal|dais' localization/strings.csv
```

Regenerate `strings.en.translation` by running `--headless --import` after editing.

## 4. Rename

Every place the template says which game this is. There are five, and there are no others —
`tools/check_boundary.gd` is what guarantees the sixth does not exist inside `src/`.

| File | Field | Note |
|---|---|---|
| `project.godot` | `application/config/name` | the boot banner and the log file name are derived from this, through `GameConfig` |
| `project.godot` | `application/config/description` | |
| `project.godot` | `application/config/version` | reset to `0.0.1` |
| `project.godot` | `application/config/icon` | and replace `icon.svg` |
| `project.godot` | **`[game] world/first_area`** | **the one that matters.** The area a new game begins in. `world/first_spawn` defaults to `default`. |
| `README.md`, `CLAUDE.md` | title lines | project-facing prose, not code |

**One field in `project.godot` is NOT yours and must be left exactly as it is:**
`[template] base/version`. It records which version of the BASE you forked from, it is what the
boot banner prints as `base <version>`, and [`UPGRADING.md`](UPGRADING.md) § 1 is the reason it
exists. Editing it makes the one question an upgrade has to answer unanswerable.

**Do not** grep-and-replace the game name across `docs/`. The DEVLOG is a history of this
template's construction and should stay readable as one.

### What `[game] first_area` is, and why it is a project setting

Nothing under `src/` may name an area, so `Director` cannot hold
`const FIRST_AREA := &"courtyard"` — it did until T1.2, and that is the leak this whole boundary
was written for. It is read through `GameConfig.first_area()`
([`src/core/util/game_config.gd`](../src/core/util/game_config.gd)).

An empty setting is a legal state — a template with no game in it yet. `Director.start_new_game()`
then logs `No first area — set game/world/first_area in project.godot` and changes nothing, rather
than clearing the flags and going quiet.

## 5. The one thing that will not be clean, stated honestly

**The test suite comes with you, and it tells you what it stopped covering.** As of T1.3 the
cases build the content they need from `tests/framework/fixtures.gd`, so doing everything above
leaves rung 4 intact. Measured on a fork that had just followed sections 1 to 4 of this document
at template 1.0.1, with `[game] world/first_area` still empty:

```
=== 1539 passed, 0 failed, 20 skipped ===
```

Those twenty are the assertions that genuinely ask something about authored content — that the
catalogue matches the disk, that every item name has a CSV row, that every waypoint a schedule
names exists in some area. They are reported as fifteen named cases, and they come back one at a
time as you author your own content; until then the run PRINTS each one rather than quietly
passing. (The template's own CI runs a harsher variant that deletes the `data/` folders outright
instead of emptying them, and reports `1534 passed, 0 failed, 25 skipped`. Both are green; the
counts differ because you kept the content roots, which is what section 1 tells you to do.)

**The order you author in does not matter, and it took a real fork to make that true.** The
first-area block used to gate on "does this checkout have any content at all", which
flips true on your first `.tres` of any kind — so authoring one item before your first area
armed an assertion about AREAS and turned rung 4 red, in the exact window this document walks you
through. It now gates on whether any area exists. See [`UPGRADING.md`](UPGRADING.md) § 7, which is
where it was found.

**AND AN EMPTY `[game] world/first_area` IS GREEN, which took a second fork to make true.**
`core_test.gd` asserted `first_area != ""` unconditionally until T4.3 — contradicting its own
name, its own neighbouring comment and section 4 of this document, all of which call the empty
setting legal. It passed in the full template and in the stripped one, because neither ever
empties that field, and failed only here: in a fork that had done exactly what this document
says and had not yet authored its first area. The claim now lives only in `smoke_test.gd`, gated
on whether any area exists and strengthened to require that the named area resolves — so a game
WITH areas and an unset first area still turns rung 4 red, which was checked by planting it.

**`src/systems/debug/` names demo content on purpose.** `dev_probes.gd` and `dev_stage.gd` are the
development harness — `--give=item/rose_key` stages a photograph, `--goto=` drives a real
transition — and a probe that travelled to an abstract area would verify nothing. They are the one
directory `tools/check_boundary.gd` exempts, they are behind `OS.is_debug_build()` so they cannot
be driven in a shipped build, and the exempted names are **counted and printed** by the gate so a
new game can see how much rewriting the harness needs. Rewrite their scenario arguments for your
own content; do not delete the files, because the capture and measurement machinery around them is
engine.

## 6. Verify

```bash
G=/c/Rai/softwares/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe
"$G" --headless --import                                   # FIRST, always — class_name cache
"$G" --headless --quit-after 30                            # must end "0 warnings, 0 errors"
"$G" --headless --script tools/check_content.gd            # must exit 0
"$G" --headless --script tools/check_boundary.gd           # must exit 0
"$G" --headless --script tools/check_budgets.gd            # must exit 0
"$G" --headless --script tools/check_strings.gd            # must exit 0
"$G" --headless res://tests/test_runner.tscn --quit-after 400
```

**On a stripped template with no content yet, the first four must still pass.** This was RUN, not
assumed — the whole strip above was performed against a fresh clone, and these are that run's
own lines, at template 1.0.1:

```
  item definitions: 0
  conversations: 0
  schedules: 0
  quests: 0
  path actions: 0
  scenes scanned: 14
PASS
  demo names derived: 0 — []
  engine scripts scanned: 129, over src/ and ["res://tests/framework", "res://tests/unit"] (res://src/systems/debug/ is exempt)
  demo names inside the exempt debug surface: 0
PASS
```

Zero items is not an error; an item that is present and does not load is, and `ItemDb` reports
that per file. (It WAS an error until T1.2, and the first command in this document made the gate
fail.) `check_boundary.gd` derives zero demo names and passes trivially, which is exactly right:
the rule it enforces is about `src/`, and `src/` did not change.

The boot run is clean, prints your name and the base's version, and lands on the main menu:

```
[INFO ] [boot     ] Tideglass 0.0.1 | base 1.0.1 | Godot 4.7.2-stable (official) | headless | debug=true
```

Starting a game before you have set `[game] world/first_area` logs, and changes nothing:

```bash
"$G" --headless --quit-after 180 -- --new-game
```
```
[ERROR] [world    ] No first area — set game/world/first_area in project.godot
```

That is the template telling you the one thing it still needs.

**THE `--` IS LOAD-BEARING AND ITS ABSENCE IS SILENT.** Everything after it is the GAME's
argument list; without it Godot swallows `--new-game`, the run stops at the main menu having
started nothing, and it reports `0 warnings, 0 errors` — a green run that verified nothing.
`--quit-after` counts FRAMES, not seconds, so a value below about 120 also ends at the menu
before the flag has fired, which looks identical. Both mistakes read as success.

The test suite passes, with skips reported. Section 5 says what the skips are.

## 7. Export

**`export_filter="all_resources"` in `export_presets.cfg`. If you change one thing in this
document, do not change that one.** `ItemDb`, `DialogueDb` and `ScheduleDb` find content by
SCANNING a directory (ADR-0006), so nothing in any scene references most of `data/**`. Those
resources are nobody's dependency, and Godot's exporter walks dependencies. Narrow that filter and
your items, conversations and NPC schedules do not ship — while every editor run, both CI jobs,
`check_content` and every assertion in the suite stay perfectly green, because there the files are
plainly on disk. `tests/unit/export_test.gd` now asserts the field, so a change fails rung 4 rather than a
release.

The preset is committed (only `override.cfg` is gitignored), so a new game inherits a working one.
Rename `export_path` and the `application/*` fields; leave `export_filter` alone.

```bash
G=/c/Rai/softwares/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe
"$G" --headless --export-debug "Windows Desktop" "$(pwd -W)/build/windows/game.exe"
cd build/windows && ./game.console.exe --headless --quit-after 30
```

**Use `--export-debug`, and read the `[content]` lines.** `src/systems/debug/catalogue_report.gd`
reports every catalogue's count and resolved paths at boot, and WARNS on an empty one in an
exported build. It is behind `OS.is_debug_build()`, so a release export prints nothing — which is
correct for players and useless for verifying, hence the debug export. Compare against the same
lines from a source run; equal is the only acceptable answer. A PARTIAL ship is worse than an empty
one, because three of four items is a plausible number.

**An export template must be installed first** — Godot will refuse otherwise. That is expected
setup, not a problem to route around. `--export-pack` does not need one and is enough to check
*which files* ship; only a real template can prove they are *found* at runtime.

**Two things that go wrong here, both silent from source:**

1. **A hand-authored `.tscn` that overrides a node inside an instanced scene needs
   `[editable path="<the instance>"]`.** Without it the text loader applies the override and the
   exporter's binary conversion DROPS it, so your prefab reverts to its defaults in the shipped
   build only. This bit the demo: the keeper lost its `object_id`, its prompt and its
   conversation in an export and nowhere else. `tools/check_content.gd` now fails on it.
2. **A narrowed `export_filter` does not just cost you content.** It also strips the `class_name`
   scripts that are nobody's dependency — `GameConfig`, `GameEnums`, `DictRead` — and the build
   dies at boot on parse errors. Loud, and worth knowing so the symptom is not misread.

## Read next

[`TEMPLATE.md`](TEMPLATE.md) · [`ARCHITECTURE.md`](ARCHITECTURE.md) ·
[`SYSTEMS_INVENTORY.md`](SYSTEMS_INVENTORY.md) · [`decisions/`](decisions/)
