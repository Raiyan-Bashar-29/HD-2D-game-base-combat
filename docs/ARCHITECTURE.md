# Architecture

How Project Gulistan is put together, and why. This document is the reason the code looks the
way it does; if code and this document disagree, one of them is a bug.

## The problem this architecture exists to solve

The previous project, Veilbound Chronicles, recorded its own cause of death in
`ARCHITECTURE_DEBT_V1.md`:

- 14,557 lines of GDScript across only 26 files. `main.gd` reached **3,983 lines**,
  `world.gd` 3,598, `battle.gd` 2,372.
- 409 of 409 static checks passing, while "real parser/import run", "rendered collision
  validation" and "multi-resolution HD-2D presentation" all sat unresolved on the debt
  list. **The build had never been run in a real editor or a real frame.**
- ~200 hard-coded player-facing strings with no localization IDs.
- Eleven regions of content breadth with no single proven vertical slice.

Nothing here is about elegance for its own sake. Every rule below exists to make one of
those four outcomes structurally difficult.

---

## Layers

Dependencies point downward only. A layer may use anything below it and must never know
anything above it.

```
  ui/          screens, HUD, prompts             may read everything below it
  gameplay/    things that exist in the world     player, camera, areas, interactables
  systems/     game-agnostic services            director, clock, weather, audio, input
  content/     typed resource definitions        data shapes only, depends on nothing
  core/        no game knowledge at all          log, events, save, flags, settings, util
```

The test for a violation is simple: **could you delete the layer above and still compile?**
If `core` imports something from `gameplay`, that is a defect, not a shortcut.

**Since T5.4 that test is a command, not a question.** `tools/check_layers.gd` runs it on every
push: it derives each file's layer from its path, each `class_name` from the file that declares
it and each autoload from `project.godot`, then fails on a `class_name` or a `res://src/<layer>/`
path literal pointing upward. **It found a real violation the first time it ran** — the
interaction sensor sat in `systems/` while typed on `Interactable`, which is `gameplay`, and was
simply in the wrong layer: it is a component of the player, and `gameplay/` is where things that
exist in the world live. It is now `src/gameplay/interaction/`. Two exemptions, both counted and
printed: the composition root, which assembles the tree and must know what it assembles, and
`src/systems/debug/`, the development harness, which `check_boundary.gd` already exempts on the
same precondition. The five autoloads under `src/systems/` are NOT an exemption — they are
layer 2, so a `gameplay` or `ui` file calling them is already downward.

**Why `content` sits below `gameplay`, not above it.** It was above until 2026-08-25. That was
wrong: `pickup.gd` in `gameplay` must reference `ItemDefinition` in `content`, which under the
old order was an **upward** dependency and failed the very test above. Content is *data*, not a
consumer - a pile of typed `Resource` shapes that depend on nothing and that anything may read.
The error was harmless only because `src/content/` was empty; it would have become real on the
day the first Resource landed. See ADR-0001.

`core` in particular must stay knowledge-free. `Log` does not read `Flags`. `SaveSystem` does
not know what a "clock" is. That is what lets both be trusted from anywhere.

## Autoload policy

Ten autoloads, in initialisation order. Each owns exactly one concern and each is small.

| Autoload | Owns | Must not |
|---|---|---|
| `Log` | Severity, categories, the log file, rotation | Read any game state |
| `Events` | Every cross-system signal declaration | Hold state or logic — permanently |
| `Actions` | Input action names and default bindings | Interpret what an action means |
| `Settings` | Machine preferences on disk, window and vsync | Apply audio or gameplay settings itself |
| `SaveSystem` | Slot files, format, version, atomic writes | Know what any section contains |
| `Flags` | Plot and world state | Interpret any flag |
| `Clock` | Day, hour, minute, phase | Know what time means to anything |
| `Weather` | Kind, blend, intensity, scheduling | Spawn a particle or touch a light |
| `Audio` | Bus layout, music and ambience | Own positional world sound |
| `Director` | Which area is loaded, transitions, player reference | Know what is inside an area |

**Order matters.** `Log` and `Events` come first because everything reports through them.
`SaveSystem` precedes every system that registers as a save participant, because registration
happens in `_ready()` and autoloads initialise top to bottom.

**Rules.**
1. An autoload must stay under **200 lines**. Past that, it is doing two jobs.
2. Adding one requires a decision record in `docs/decisions/`.
3. There is no `GameManager`, and there never will be. That name is how a codebase asks for
   a god object. If something does not fit the ten above, it is not global.

## How things talk to each other

Apply this in five seconds:

| Situation | Use | Why |
|---|---|---|
| You own the thing and it is right there | Direct call | Traceable, typed, cheapest |
| A parent needs to hear from its own child | Node signal | Local and obvious |
| A fact about the world changed and you must not know who cares | `Events` bus | Decoupled by design |
| You need a value back, or to know the receiver acted | **Never the bus** | Signals are announcements, not calls |

The bus has a real cost: emit and listen sites sit far apart, so flow is harder to trace.
Three rules keep that survivable, and they are enforced by convention in `src/core/events/events.gd`:

1. Every signal is **declared there**, with typed parameters. Never emitted ad hoc.
2. Past tense for things that happened; the `_requested` suffix for asks.
3. **Exactly one system emits any given signal,** and the comment names it. Two emitters
   means the signal is modelled wrong.

`events.gd` is therefore also the connection map: reading that one file tells you how the
game is wired.

## Composition, not inheritance

A character is not a subclass. It is a body with parts:

```
Player (CharacterBody3D)          movement, gait, state          player_controller.gd
|- Collision (CollisionShape3D)
|- Visual (Node3D)                billboard, facing, animation   character_visual.gd
|  |- Sprite3D
|- InteractOrigin (Marker3D)      where interaction rays start
```

`CharacterVisual` knows nothing about input and is reused unchanged by every NPC. The
controller knows nothing about how the sprite is drawn. Either can be replaced alone.

The same applies to areas. Every area scene has the identical shape, so `Director` never needs
a per-area special case, and area fifty needs no code at all:

```
AreaRoot (Node3D)                 area_root.gd
|- Environment/                   WorldEnvironment, Sun, EnvironmentDriver, WeatherVisuals
|- Terrain/                       geometry and static collision, in group navmesh_source
|- Props/                         scenery, lights
|- Interactables/                 anything the player can act on
|- Actors/                        NPCs
|- Spawns/                        one Marker3D per entry point
|- Triggers/                      Area3D volumes
|- Camera/                        the area's camera rig
|- Navigation/                    Region, a NavigationRegion3D baked at load
|- Waypoints/                     one Marker3D per named place an NPC can be sent to
```

All ten are required and are asserted for every authored area by
`tests/unit/transitions_test.gd`. [`AUTHORING.md`](AUTHORING.md) has the authoring form.

## The extension surface

**Which classes a consuming game is expected to subclass, call or replace — and which are the
engine's own business.** This is the distinction most likely to be got wrong by someone moving
fast, because nothing in the tree marks it.

The one-line version: **a game adds content and resources; it does not add code under `src/`.**
Anything that needs a new `src/` file is a change to the *template*, and belongs upstream.

### Tier 1 — authored data. No code at all, and this is where nearly everything goes.

Items, conversations, schedules, quests, path actions, areas, sprite sheet layouts, the UI theme,
instances of the object and character prefabs. Adding the fiftieth of any of them touches no
script. [`AUTHORING.md`](AUTHORING.md) is the whole of this tier;
[`ART_CONTRACT.md`](ART_CONTRACT.md) is the two resources that carry the look.

### Tier 2 — the extension points. Subclass or replace these, deliberately.

**Every row names its file, because T5.30 performed this table and the first thing it cost was a
grep.** Three rows named a class and no path while the `Events` row named one, so a consumer
looking for `UiScreen` searched `src/ui/root/` — where `UiRoot` lives and `UiScreen` does not.

| Point | File | How | Why it is open |
|---|---|---|---|
| `Interactable` | `src/gameplay/interactables/interactable.gd` | `extends Interactable`, override `perform(who)` and optionally `refusal(who)` | The documented way to add a kind of object. Detection, ranking, the prompt, refusal messaging, one-shot and hold-to-confirm are all already handled. Subclasses stay thin: behaviour and state go into children |
| `UiScreen` | `src/ui/screens/ui_screen.gd` — **not `src/ui/root/`** | `extends UiScreen`, declare `pauses_world` / `closes_on_cancel` **in `_init`, never in `_build`**. The three overrides are **`_build()`** (construct, once, from `_ready`), **`_opened()`** (each time it reaches the top of the stack) and **`_closed()`** (about to be freed — last chance to write back) | A new screen is a game's business. `_build` runs from `_ready`, after a caller could have overridden a flag, so setting one there silently discards the caller's request. **Open your own with `UiRoot.find(self).open(MyScreen.new())`** — `open()` takes an instance, so no registration is needed and `ScreenKeys.menu_for()` is not involved: that is a debug convenience for `--open-menu=`, and its only caller is boundary-exempt |
| `ConfirmScreen` | `src/ui/screens/confirm_screen.gd` | **call, do not subclass**: `UiRoot.find(node).open(ConfirmScreen.asking(question_key, detail, on_yes))`, or `push(...)` from a `MenuScreen`. `question_key` is a localization key; `detail` is already translated | Any action a player cannot take back asks the same way. Cancel and pause cannot answer it, focus lands on No, and `on_yes` runs only on Yes. The save screen's overwrite is the first caller (T6.3) |
| `SpriteSheetLayout`, `ui_theme.tres` | `src/content/art/sprite_sheet_layout.gd`, `assets/theme/ui_theme.tres` | **replace the resource, not the class** | The art contract. See `ART_CONTRACT.md` |
| Inventory capacity | `src/gameplay/character/inventory.gd` | `extends Inventory` (it is a `Node`), override `can_accept(item_id, count)` and **call `super()` first** — it enforces `max_stack`, and reimplementing stacking is the mistake | Capacity is unlimited behind that one method. Slots or weight go there and nowhere else |
| A bespoke area behaviour | — | a child node with its own script, under the area | **Do not subclass `AreaRoot`.** Areas differ in content, not in shape; the root stays generic so `Director` never grows a per-area case |
| `Events` signals | `src/core/events/events.gd` | connect to anything declared there | It is the connection map and it is meant to be read and listened to |

**AND ONE THING THIS TIER DOES NOT GIVE YOU, MEASURED RATHER THAN INFERRED.** A game may declare
its own input action with Godot's own `InputMap.add_action()` and bind it in its own code — but it
**cannot make that action player-rebindable**. `KeyBindings.rebind()` refuses any action absent
from the `Actions.REBINDABLE` const, and `rebind_screen.gd` builds its rows by iterating that same
const. That gate is deliberate and has a bug behind it: until T5.5 it asked only
`InputMap.has_action`, so `debug_console` could be overridden into `input.cfg` and
`reset_bindings()` would not put the default back. So the closed list is the fix, not an oversight —
and the consequence for a game is real and stated here rather than discovered. A game's own action
works; it is just not offered on the rebinding screen.

### Tier 3 — internals. Read them; do not edit or subclass them.

The ten autoloads (`Log`, `Events`, `Actions`, `Settings`, `SaveSystem`, `Flags`, `Clock`,
`Weather`, `Audio`, `Director`), `Director`'s transition sequence, `InteractionSensor`, `UiRoot`,
`PlayerController`, `PersistentState`, `EnvironmentDriver`, `WeatherVisuals`, `QuestTracker`, and
the content registries. Each owns exactly one concern, and the seams above exist so none of them
has to be touched.

Three that look editable and are not:

- **`GameEnums` is append-only.** `InteractVerb`, `RefusalReason`, `ItemCategory` and the rest are
  stored in authored scenes as **ordinals**, so reordering one silently repoints every `.tscn` in
  the project at a different value. Appending is a template change, not a game change.
- **Adding an autoload requires an ADR.** There is no `GameManager` and there will not be one.
- **There is no combat, at the template level.** No battles, enemies, damage or encounters. If a
  design seems to need one, that effort redirects into traversal, interaction or world state.

### When you genuinely need `src/` to change

Say so rather than forking a screen. The seam is either missing or in the wrong place, and both
are template bugs. `tools/check_boundary.gd` exists to make the *other* direction impossible — no
file under `src/` may name your content — and a game editing `src/` is the failure this whole
boundary was written to prevent.

**How a game already forked from the template receives a later fix to the base is
[`UPGRADING.md`](UPGRADING.md)**, and it was performed against a real fork rather than written
from intent. This paragraph said that answer did not exist yet and named Phase T4 as the open
work; T4 is complete and the document has been there since T4.1.

## Data, not code

| Belongs in | What |
|---|---|
| A typed `Resource` | Item definitions, area config, weather profiles, surface tables |
| A scene | Anything with a node structure: objects, characters, areas, UI |
| Script | Behaviour only |

The test: **adding the fiftieth item must not touch a single line of code.** If it does, the
item system is wrong.

## Anti-monolith measures, concretely

Good intentions did not work last time. These are mechanical:

1. **Warnings as errors.** `project.godot` sets `untyped_declaration`, `unsafe_call_argument`,
   `unsafe_method_access`, `unsafe_property_access` and `unsafe_void_return` to **error**.
   GDScript now behaves like a statically typed language: `var x = 5` will not parse, and
   calling a method on an untyped value is a build failure. This alone eliminates the largest
   category of runtime surprise.
2. **Line budgets,** counted in CODE lines so documentation is never penalised: 250 per
   script, 150 for an autoload, 40 per function, 60 for the game root. Enforced by
   `tools/check_budgets.gd`, which exits 1 on violation. It also bans `print()` outside the
   logger and the tools.

   **A per-file override may be RAISED, and WP-14 raised one — the first time, so the reasoning
   is recorded here rather than left in a diff.** `director.gd` went from 180 to 190 when it
   gained the shutdown drain for its own threaded loader. The checker offers two remedies,
   "split the file, or justify a new budget", and the split was the wrong one: the drain has to
   sit with the code that owns the loader thread, and `Director`'s whole header is an argument
   for *one owner, one guarded path* — carving up the project's single transition path to save
   seven lines would trade real safety for a number. The distinction that makes this legitimate
   rather than a slippery slope is that **190 is not above the 250 default; it is a
   self-imposed tightening being relaxed 60 lines short of it.** Going over 250 still means
   split.
3. **A stated `MUST NOT` in every file header.** Every script says what it is forbidden to
   know. When a change requires violating it, that is the signal to add a new system instead.
4. **The verification ladder,** below. Nothing is "done" until the engine has run it.

## The verification ladder

Every rung is proven working on this machine. Nothing here is aspirational.

| Rung | Command | Catches |
|---|---|---|
| 1. Parse and type gate | `--headless --check-only --script <file>` | Type errors, unknown functions, with file and line |
| 2. Import gate | `--headless --import` | Broken scenes, resources, asset references |
| 3. Headless run | `--headless --quit-after 30` | Boot order, null references, real `_process` frames |
| 4. Tests | `--headless res://tests/test_runner.tscn --quit-after 400` | Logic, save round-trips. 2,669 assertions, exit 1 on failure |
| 5. check_budgets | `--headless --script tools/check_budgets.gd` | File and function line budgets, stray `print()` |
| 6. check_content | `--headless --script tools/check_content.gd` | Broken items, duplicate object ids, missing CSV keys, a missing `[editable]` |
| 7. check_boundary | `--headless --script tools/check_boundary.gd` | Any demo name in a code line under `src/` or `tests/`; a CSV row translating content that is not there |
| 8. check_strings | `--headless --script tools/check_strings.gd` | A literal reaching a text sink, a `*_KEY` const with no CSV row |
| 9. check_layers | `--headless --script tools/check_layers.gd` | A dependency pointing UP the layer list — the rule below, enforced since T5.4 |
| 10. check_signals | `--headless --script tools/check_signals.gd` | A signal declared in the registry that nothing ever emits |
| 11. check_methods | `--headless --script tools/check_methods.gd` | A public method under src/ whose name is written nowhere else in the repository |
| 12. Visual capture | `--quit-after 90 -- --new-game --shot=<path> --shot-frame=70 --time=HH:MM` | The actual look, at any hour, on demand |

**Rung 1 gotcha:** autoload identifiers such as `Log` do not resolve under `--check-only`,
because a standalone script check does not create them. Filter
`Identifier not found: <Autoload>` out of that gate; rungs 2 and 3 are the real compile check.

**Rung 4 gotcha:** it is a SCENE, entered positionally, not a `--script` tool. Under
`--headless --script` the autoload *nodes* are created but the autoload *identifiers* fail to
compile (`Compile Error: Identifier not found: Log`), so no test touching a system can run
that way. Also: anything created with `.new()` and not freed prints a wall of
`RID allocations were leaked at exit`, which drowns real errors.

**Rung 12 is the important one.** `--headless` uses a dummy rasteriser and shades nothing, so
visual work needs a real window. `DevCapture` makes that repeatable: it forces the clock and
the weather from the command line and writes the viewport to a PNG. This is what closes the
"multi-resolution HD-2D presentation cannot be verified" item that the previous project could
never resolve.

## The HD-2D look, and where it lives

| Ingredient | Where | Note |
|---|---|---|
| Long lens diorama | `hd2d_camera_rig.gd` | 27 degrees at 14 m, pitch -32. Matters more than any post effect |
| Tilt-shift depth of field | `hd2d_camera_rig.gd` | Both near **and** far blur. Far only just looks like fog |
| Billboarded sprites | `character_visual.gd` | `BILLBOARD_FIXED_Y`, so characters stay upright |
| Sprites that sort and cast shadows | `character_visual.gd` | `ALPHA_CUT_DISCARD`. Alpha blending writes no depth, so it cannot sort or cast shadows |
| Crisp pixels | `character_visual.gd` | `TEXTURE_FILTER_NEAREST` |
| Sprites lit in real time | `character_visual.gd` | `shaded = true`, which is why a lantern lights the character at night |
| Filmic highlights | `environment_driver.gd` | AgX tonemapping |
| Bloom | `environment_driver.gd` | Threshold 0.92, screen blend |
| Depth between scenery layers | `environment_driver.gd` | Depth fog beyond 30 m plus light volumetric fog |
| Day and night | `environment_driver.gd` | An eight-key colour table, interpolated every frame |
| No TAA | `project.godot` | TAA smears billboards and makes pixel art crawl. MSAA 4x instead |

## Known limitations, stated honestly

- **Input actions are invisible in the editor.** They are built in code, so Project Settings
  shows an empty Input Map. Accepted; see `docs/decisions/ADR-0003`.
- **No hard-coded-string audit.** Computed keys (`verb.*`, `refusal.*`, `item.category.*`,
  `time.phase.*`) are each covered by an enum loop in the suite, and `tools/check_content.gd`
  fails a CSV row with an unquoted comma — but literal player-facing text in code is still
  caught only by review.
- **Audio has no assets,** so every audio path is written but unexercised. It accepts `null`
  everywhere by design, which means it is untested rather than broken.
- **The UI theme set no `Button` styleboxes until 4.2.0** — closed by T5.15, and the shape is
  worth knowing because it is the general answer whenever a look has to survive a palette the
  base does not ship. The five states are not authored in `ui_theme.tres`; they are DERIVED from
  the palette by `UiRowStyles` at boot, and the derivation is directional — `hover` is `surface`
  moved toward `text`, which lightens a dark row and darkens a light one from one expression.
  What remains is that the base still has no LOOK: `surface` is a placeholder colour like every
  other entry in that palette, and a game picks its own by editing one line.
- **`Director` drains its threaded load on shutdown as of WP-14**, so a run killed mid-load no
  longer prints `Parse Error` for files that parse perfectly. There is no `load_threaded_cancel` in
  4.7, so the fix is a blocking `load_threaded_get()` in `_exit_tree()` — measured at 118-197ms,
  paid once. The boot rung's frame count was never really about this (gotcha 31: a plain boot loads
  no area); the gate it was really costing was CI's rung 3, which now greps its whole log.
- **A quest step CAN read an item count, and a completed quest still hands nothing over.** Closed
  by T3.3, and the shape is worth knowing because it is the general answer whenever a lower layer
  holds something an upper one needs to observe: rather than a `systems` tracker reading a
  `gameplay` inventory — which points the wrong way and is what WP-08 refused over `reward_item` —
  `Inventory` PUBLISHES each count as the flag `bag/<carrier_id>/<item id>`, and a step tests it
  with the comparison set it already had. The dependency points DOWN, `QuestStep` gained no field
  and `QuestTracker` gained no knowledge. The mirror is declared DERIVED in `Flags`, so it is
  readable and announced but never saved — the count is saved once, by the bag that owns it.
  What remains deferred is a step that *takes* the items, for the layer reason that has not
  changed: a completed quest emits `quest_completed` and stops.
- **The four content registries are four copies of the same thirty lines.** `ScheduleDb`'s header
  said "three is a pattern, four is a problem"; WP-08 made it four, reconsidered it, and kept the
  copy because GDScript has no generics and a shared base could only hand back untyped
  `Resource`s. The refactor that pays — a base holding the cache plus a thin typed façade each —
  has a board row.
