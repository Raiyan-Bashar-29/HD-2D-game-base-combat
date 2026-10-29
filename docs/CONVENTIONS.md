# Conventions

Short, and all of it enforced either by the engine or by `tools/check_budgets.gd`.

## Naming

| Thing | Style | Example |
|---|---|---|
| Files and folders | `snake_case` | `player_controller.gd`, `world_clock/` |
| Classes (`class_name`) | `PascalCase` | `HD2DCameraRig`, `DictRead` |
| Functions and variables | `snake_case` | `day_fraction()`, `walk_speed` |
| Private members | leading underscore | `_smoothed`, `_apply_frame()` |
| Constants and enum values | `SCREAMING_SNAKE_CASE` | `MINUTES_PER_DAY`, `DAY_PHASE` |
| Signals | past tense, or `_requested` for asks | `area_entered`, `area_change_requested` |
| Autoloads | `PascalCase`, one word where possible | `Clock`, `SaveSystem` |
| Booleans | read as a claim | `is_night()`, `sheltered`, `dof_enabled` |

## IDs

Lowercase, slash-separated, general part first, so sorting groups them usefully.

```
area/courtyard              an area
item/lantern_brass          an item definition
story/chapter               plot progress
met/gardener                a one-time fact
area/courtyard/gate_open    world state, namespaced via AreaRoot.flag_key()
area.courtyard.name         a localization key (dots, because Godot uses dots)
```

## Typing

Static types everywhere. This is not a style preference: `untyped_declaration`,
`unsafe_call_argument`, `unsafe_method_access`, `unsafe_property_access` and
`unsafe_void_return` are set to **error** in `project.godot`, so untyped code does not parse.

- `var count: int = 0` or `var count := 0`. Never `var count = 0`.
- Narrow a `Variant` with an `is` check and return it, or cast with `as`.
- Reading untyped data — JSON, save sections — goes through `DictRead`, never `int(value)`.
- Cast node lookups: `get_node_or_null(^"Sprite3D") as Sprite3D`.

## Indentation

Tabs, per the Godot style guide, so the editor never introduces mixed indentation. Files are
authored with spaces and converted with `unexpand -t 4 --first-only` before committing.

## File headers

Every script opens with a `##` docstring that answers three questions:

1. **What is this?** One line.
2. **Why does it exist / why is it built this way?** The reasoning a future reader needs in
   order not to undo it.
3. **OWNS** what, and **MUST NOT** know what.

The `MUST NOT` line is load-bearing. It is the boundary that stops a system accreting
responsibilities, and the budget checker warns when a `src/` file is missing one. When a
change requires breaking that line, the answer is a new system, not a wider boundary.

## Budgets

250 code lines per script, 150 for an autoload, 60 for the game root, 40 per function. Code
lines exclude blanks and comments, so documentation is never the reason to split a file.
`print()` is banned outside `tools/`, `tests/` and the logger itself.

```bash
"$GODOT" --headless --script tools/check_budgets.gd
```

## Strings

No player-facing literal, ever. Text is a localization key from the first line written. This
is not deferred polish: the previous project accumulated ~200 hard-coded strings and logged
the migration as debt it never paid.

## Committing

Commit `*.uid`, `*.import`, `*.tres` and `*.tscn`. Never commit `.godot/`. Every session
appends an entry to `DEVLOG.md`.

A branch is `claude/t<phase>-<n>-<slug>` for a phase row and `claude/wp-<nn>-<slug>` for a work
package — `claude/t5-18-save-recovery`, `claude/wp-13-presentation`.

**The branch name is not authoritative. The in-tree record is.** Nothing gates a branch name and
nothing should: a branch is cut before the work is understood, and renaming one mid-stack moves
the base of every PR above it. Two rows are already misnamed for that reason — `claude/t5-21-save-dir`
carries T5.22 and `claude/t5-20-selection-test` carries T5.21, both because a parallel session
took the number while the row was in flight. When a name and the record disagree, the ROADMAP
row, the board row, the DEVLOG heading and the `CHANGELOG.md` version are right and the branch is
wrong. Record the collision in the row rather than rewriting history to hide it.

## Content data

A content type is two things in two places, following the same split as scenes (ADR-0001):

| Thing | Lives in | Example |
|---|---|---|
| The typed `Resource` class | `src/content/<kind>/` | `src/content/items/item_definition.gd` |
| The authored instances | `data/<kind>/` | `data/items/gate_key.tres` |

`content` sits **below** `gameplay` in the layer order, because it is data that depends on
nothing. Anything may read it; it may read nothing but `core`.

**A resource's `id` field must equal its filename** (`gate_key.tres` holds `id = &"gate_key"`).
The registry errors when they disagree, which turns a copy-paste slip into a loud failure
instead of a duplicate that shadows another item.

## Two rules that exist because the engine surprised us

**Never persist an enum ordinal.** Inserting a value into the middle of an enum silently
reinterprets every existing save: what was `STORM` becomes `DRIZZLE`, and a range check cannot
detect it because the value is still in range. Persist a `StringName` id instead. This binds
`WeatherKind`, `MoveState`, `Facing`, `ItemCategory` and `InteractVerb`.

**Node-typed `@export`s in a hand-authored `.tscn` need a `node_paths` header.** This resolves
to null and stays silent without it:

```
[node name="EnvironmentDriver" type="Node" parent="Environment" node_paths=PackedStringArray("sun")]
sun = NodePath("../Sun")
```

**Resource-typed `@export`s do not** — verified 2026-08-25 by probe:
`definition = ExtResource("1_key")` resolves correctly with no extra header, and the typed cast
succeeds. So object prefabs can reference their item definitions directly.
