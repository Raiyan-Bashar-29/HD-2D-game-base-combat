# Authoring content on this template

**Task-first.** Every section starts from something you want to add and ends with a command that
tells you whether you got it right. If you are looking for how a *system* works, read the file
header — this document is the other direction.

Read [`TEMPLATE.md`](TEMPLATE.md) once before this: it says which parts of the tree are yours
(`data/**`, `scenes/areas/**`, half of `localization/strings.csv`) and which are the engine's.
[`NEW_GAME.md`](NEW_GAME.md) is what to delete before you start. This is what to write afterwards.

**What you never do:** edit anything under `src/`. If a task below seems to need it, that is a
missing seam and it is worth reporting as one. Which classes you *may* extend, and which are the
engine's own business, is [`ARCHITECTURE.md` § The extension surface](ARCHITECTURE.md#the-extension-surface).

---

## Before anything

```bash
G=/c/Rai/softwares/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe
"$G" --headless --import
```

**On a fresh clone this comes first, always.** `class_name` globals (`GameEnums`, `DictRead`,
`AreaRoot`) live in the gitignored `.godot/` cache. Without the import every script referencing
one fails to parse, the autoloads never load, and the tools look broken rather than un-imported.

Run it again after editing `localization/strings.csv` — the `.translation` file is generated.

## Six rules that catch most of it

1. **No player-facing text in a file you author.** Every visible string is a localization key
   with a row in `localization/strings.csv`. A property whose name ends in `_key` holds a key,
   never a sentence.
2. **A CSV value containing a comma must be quoted.** Unquoted, the parser truncates the value at
   the comma and `tr()` still returns a plausible-looking string. This shipped a half-sentence for
   three packages. `check_content` fails any row that parses to more than two columns.
3. **A content id equals its file name.** `data/items/rose_key.tres` declares
   `id = &"item/rose_key"`; `data/dialogue/gardener.tres` declares `id = &"talk/gardener"`;
   `scenes/areas/courtyard/courtyard.tscn` declares `area_id = &"courtyard"`. The registries
   refuse a mismatch by name, so a copy-paste slip is loud.
4. **An `object_id` is unique and permanent.** It is the key an object's state is saved under.
   Renaming one orphans every existing save's memory of it.
5. **A hand-authored `.tscn` that overrides a node *inside* an instanced scene needs
   `[editable path="<the instance>"]`** at the foot of the file. See § The editable trap.
6. **Nothing is authored until the engine has run it.** The gates at the bottom of this document
   are the answer, not a reading of your own file.

---

## Add an area

An area is one folder and one scene: `scenes/areas/<id>/<id>.tscn`, with the folder name, the file
name and the `area_id` all equal. `Director` resolves an id to a path with that template and
nothing else, which is why there is no registration step and no list to add yourself to.

### The ten required children

`AreaRoot`'s contract, asserted in `tests/unit/transitions_test.gd` for **every** area a game has
authored. All ten must exist, spelled exactly like this, even when empty:

| Child | Type | Holds |
|---|---|---|
| `Environment` | `Node3D` | `WorldEnvironment`, `Sun`, an `EnvironmentDriver`, a `WeatherVisuals` |
| `Terrain` | `Node3D`, in group `navmesh_source` | ground and walls: `StaticBody3D` with mesh and collision |
| `Props` | `Node3D` | scenery nothing can interact with — lights, decoration |
| `Interactables` | `Node3D` | every instanced object the player can act on |
| `Actors` | `Node3D` | NPCs |
| `Spawns` | `Node3D` | one `Marker3D` per arrival point; **at least one is required** |
| `Triggers` | `Node3D` | `TriggerVolume` instances |
| `Camera` | `Node3D` | the camera rig and its `Camera3D` |
| `Navigation` | `Node3D` | a `NavigationRegion3D` **named `Region`**, carrying a `NavigationMesh` |
| `Waypoints` | `Node3D` | one `Marker3D` per named place an NPC can be sent to |

Two names are load-bearing beyond the list: `Navigation/Region` is the exact path `AreaRoot`
bakes, and a spawn marker's **node name** is the `target_spawn` a door asks for. A spawn called
`default` is what `[game] world/first_spawn` looks for on a new game.

### The root's own fields

```
[node name="MyArea" type="Node3D"]
script = ExtResource("1_area")
area_id = &"my_area"                        ; must equal the folder and file name
display_name_key = "area.my_area.name"      ; a CSV row, not a name
sheltered = true                            ; an interior: weather runs but is not seen or felt
flag_prefix = "area/my_area"                ; namespace for this area's flags
```

Also available: `allowed_weather`, `force_weather_on_entry` / `forced_weather`, `music`,
`ambience`. Leaving `allowed_weather` empty means anything may occur.

### The navmesh, and the one number that will strand an NPC

The mesh is **baked at load from the geometry that is actually there**, never committed — a
checked-in navmesh goes stale the moment a wall moves, and a stale navmesh fails silently.
Two settings are not optional:

```
[sub_resource type="NavigationMesh" id="navmesh"]
agent_radius = 0.4
agent_height = 1.7
agent_max_climb = 0.2
cell_size = 0.2
cell_height = 0.1
geometry_parsed_geometry_type = 1
geometry_source_geometry_mode = 1                   ; GROUPS_WITH_CHILDREN
geometry_source_group_name = &"navmesh_source"
filter_walkable_low_height_spans = true
```

- **`geometry_source_geometry_mode = 1`** with the group name. Godot's default parses the
  children of the `NavigationRegion3D`, which in this layout has none — the terrain is a sibling.
  A bake that finds nothing takes 0ms and reports success, and then every NPC concludes it has
  already arrived, everywhere. Put `groups=["navmesh_source"]` on your `Terrain` node.
- **Keep `agent_max_climb` below any step your geometry has.** The bake will happily bridge a
  knee-high riser; `CharacterBody3D.move_and_slide()` has **no step-up at all**, so the body walks
  into it and stops while the agent insists it has not arrived. Vertical movement in this template
  is authored — a `ClimbPoint` — not jumped.

The log tells you which happened, on a run that actually enters the area:

```
[INFO] [area] Navmesh for 'my_area' baked: 2 polygons in 5ms
[ERROR] [area] Navmesh for 'my_area' baked EMPTY; nothing can path here
```

**Any non-zero count is a success** — a single flat floor is two triangles. Zero is the failure,
and it is the one the log had to be taught to report, because an empty bake also takes no time.

### An interior does not follow the sun

Set `sheltered = true` on the root **and** `follow_clock = false` on the `EnvironmentDriver`, and
then author that area's own ambient light — an interior with `follow_clock = false` and no light
of its own is pitch black. `transitions_test.gd` asserts the two agree, because a stray edit that
flips one and not the other only shows up in a capture at midnight.

### A complete minimal area

Written out in full, because ten children plus a working navmesh is more than a snippet:

```
[gd_scene load_steps=9 format=3]

[ext_resource type="Script" path="res://src/gameplay/world/area_root.gd" id="1_area"]
[ext_resource type="Script" path="res://src/gameplay/world/environment_driver.gd" id="2_env"]
[ext_resource type="Script" path="res://src/gameplay/world/weather_visuals.gd" id="3_weather"]
[ext_resource type="Script" path="res://src/gameplay/camera/hd2d_camera_rig.gd" id="4_cam"]
[ext_resource type="Texture2D" path="res://assets/placeholder/stone.png" id="5_stone"]

[sub_resource type="StandardMaterial3D" id="m_floor"]
albedo_texture = ExtResource("5_stone")
texture_filter = 0
uv1_scale = Vector3(8, 8, 1)

[sub_resource type="BoxMesh" id="mesh_floor"]
size = Vector3(20, 1, 20)

[sub_resource type="BoxShape3D" id="shape_floor"]
size = Vector3(20, 1, 20)

[sub_resource type="NavigationMesh" id="navmesh"]
agent_radius = 0.4
agent_height = 1.7
agent_max_climb = 0.2
cell_size = 0.2
cell_height = 0.1
geometry_parsed_geometry_type = 1
geometry_source_geometry_mode = 1
geometry_source_group_name = &"navmesh_source"
filter_walkable_low_height_spans = true

[node name="MyArea" type="Node3D"]
script = ExtResource("1_area")
area_id = &"my_area"
display_name_key = "area.my_area.name"

[node name="Environment" type="Node3D" parent="."]

[node name="WorldEnvironment" type="WorldEnvironment" parent="Environment"]

[node name="Sun" type="DirectionalLight3D" parent="Environment"]
transform = Transform3D(1, 0, 0, 0, 0.34, 0.94, 0, -0.94, 0.34, 0, 9, 0)
shadow_enabled = true

[node name="EnvironmentDriver" type="Node" parent="Environment" node_paths=PackedStringArray("world_environment", "sun")]
script = ExtResource("2_env")
world_environment = NodePath("../WorldEnvironment")
sun = NodePath("../Sun")

[node name="WeatherVisuals" type="Node3D" parent="Environment"]
script = ExtResource("3_weather")

[node name="Terrain" type="Node3D" parent="." groups=["navmesh_source"]]

[node name="Floor" type="StaticBody3D" parent="Terrain"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.5, 0)
collision_layer = 1
collision_mask = 0

[node name="Mesh" type="MeshInstance3D" parent="Terrain/Floor"]
mesh = SubResource("mesh_floor")
surface_material_override/0 = SubResource("m_floor")

[node name="Shape" type="CollisionShape3D" parent="Terrain/Floor"]
shape = SubResource("shape_floor")

[node name="Props" type="Node3D" parent="."]

[node name="Interactables" type="Node3D" parent="."]

[node name="Actors" type="Node3D" parent="."]

[node name="Spawns" type="Node3D" parent="."]

[node name="default" type="Marker3D" parent="Spawns"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.1, 4)

[node name="Triggers" type="Node3D" parent="."]

[node name="Camera" type="Node3D" parent="."]

[node name="CameraRig" type="Node3D" parent="Camera"]
script = ExtResource("4_cam")

[node name="Camera3D" type="Camera3D" parent="Camera/CameraRig"]

[node name="Navigation" type="Node3D" parent="."]

[node name="Region" type="NavigationRegion3D" parent="Navigation"]
navigation_mesh = SubResource("navmesh")

[node name="Waypoints" type="Node3D" parent="."]
```

Add `area.my_area.name,My Area` to `localization/strings.csv`, then:

```bash
"$G" --headless --import
"$G" --headless --script tools/check_content.gd
"$G" --headless res://tests/test_runner.tscn --quit-after 400
```

**THE SCENE IS NOT THE WHOLE TASK: THE SUITE STAYS RED UNTIL THE AREA IS ALSO ON THE MAP.** Write
`data/areas/<id>.tres` as well — § Put an area on the world map, below, and it is four lines. With
the scene alone the run above reports:

```
=== 1621 passed, 4 failed, 0 skipped ===
FAILED: every authored area is on the map — expected 3, got 2
FAILED: my_area has an AreaDef — expected true, got false
```

Every area adds **20 assertions** to `transitions_test.gd` and **5** to `world_map_test.gd`, both
computed from the areas found — the plan is `PER_AREA_ASSERTIONS * areas + fixed`, so authoring an
area does not mean editing a plan.

None of those three enters your area. To actually see it, and you must:

```bash
"$G" --resolution 960x540 --quit-after 90 -- --new-game --goto=my_area \
     --shot="$(pwd)/build/shots/my_area.png" --shot-frame=70 --time=12:00 --freeze-time
```

Then **look at the PNG.** See § Nothing above ever enters your area.

### Reaching it

An area nothing travels to is dead content. Three ways in:

- **Make it the start:** `[game] world/first_area="my_area"` in `project.godot`.
- **Put a door in another area:** an `area_door.tscn` instance whose `target_area` is your id and
  whose `target_spawn` names a `Marker3D` under your `Spawns`. Doors are one-directional; author
  the return door too, and give each area a spawn named for where it is arrived from.
- **Put it on the world map**, below, so a player who has been there once can travel back.

---

## Put an area on the world map

The map is one `.tres` per area in `data/areas/`, found by directory scan the way items and
quests are. **You write no code**, and nothing on the map screen knows any area exists.

**EVERY AREA YOU AUTHOR NEEDS ONE, AND THE SUITE FAILS UNTIL IT HAS ONE.** This section used to
say an area with no `.tres` here was "simply not on the map — legitimate for a cupboard"; that was
written from intent and it is false. `world_map_test.gd` asserts that the defs and the authored
areas are the same set, so a scene with no def is four red assertions in a suite that was green a
moment earlier. `data/areas/` may only be empty in a game that has authored no areas at all,
which is the state a stripped template starts in.

There is no way to have an area that is deliberately off the map. A place you would rather not
advertise is authored with `known_from_start = false` and simply never discovered, which draws it
as a grey `???` rather than hiding it.

### The file

The id is the **file name and the area id**, with no prefix — `data/areas/orchard.tres` is
`id = &"orchard"`, the same id `scenes/areas/orchard/orchard.tscn` declares. There is no prefix
because an area id is already a public identifier: it is a folder name.

```
[gd_resource type="Resource" script_class="AreaDef" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/content/world/area_def.gd" id="1_def"]

[resource]
script = ExtResource("1_def")
id = &"orchard"
name_key = "area.orchard.name"
map_position = Vector2(0.61, 0.24)
arrival_spawn = &"from_courtyard"
known_from_start = false
```

| Field | What it is |
|---|---|
| `id` | the area id, equal to the file name and to the folder under `scenes/areas/` |
| `name_key` | the CSV key for the name drawn beside the dot. Use the same key the area scene's `display_name_key` uses — the suite fails if the two disagree |
| `map_position` | where the dot goes, **normalised**: `(0,0)` is the top-left of the map plate and `(1,1)` the bottom-right. Normalised so the same number is right at every window size |
| `arrival_spawn` | which `Marker3D` under the area's `Spawns` a fast traveller lands on. Empty means the first one. The suite fails if it names a marker that is not there |
| `known_from_start` | on the map before the player has been anywhere. True for where the game begins, and for anywhere known by reputation |

### Being found

**Discovery is a flag, `map/<area id>`, and nothing else.** Two consequences you can use today
without touching `src/`:

- **Arriving discovers a place.** `WorldMap` listens to `Events.area_entered`, so walking through
  a door is enough. Nothing to author.
- **Anything that writes the flag reveals a place.** A `DialogueNode` effect with
  `effect_flag = &"map/orchard"` and `effect_write = 1` (SET_TRUE) means an NPC telling you about
  the orchard puts it on your map. So does a `TriggerVolume`, a `Lever`, or a quest step's
  consequence — and none of them has heard of the map.

The same key runs the other way: a `Gate` with `requires_flag = &"map/orchard"` is a road that
opens once you know where it goes, with no code at all.

Because it is a flag, it is already saved, already cleared by a new game, and already announced
on `flag_changed`. There is no map save section.

### Seeing it

`M` opens the map. A place you are standing in is drawn in white and says so; a place you have
found is a gold dot you can select and press Enter on to travel; a place you have not is a grey
dot marked with the `ui.map.unknown` row. Travel goes through the same
`Events.area_change_requested` a door uses, so `Director` still owns every transition.

```bash
"$G" --resolution 960x540 --quit-after 120 -- --new-game --open-menu=map \
     --shot="$(pwd)/build/shots/map.png" --shot-frame=100 --time=12:00 --freeze-time
```

Add `--goto=my_area` before `--open-menu=map` to photograph the map from somewhere else, or
`--flag=map/my_area:true` to pose a place as found without walking there.

---

## Tag the ground you walk on, and give a character an attribute

Two small systems that share a section because they share a shape: **both are one line of authored
data over `Flags` or over node metadata, and neither has a resource, a registry or a save section.**

### The ground: one metadata key per body

A surface is a `metadata/surface` entry on a `StaticBody3D` in your area — or on any ancestor of
one, which is the useful part.

```
[node name="Terrain" type="Node3D" parent="." groups=["navmesh_source"]]
metadata/surface = &"stone"

[node name="Ground" type="StaticBody3D" parent="Terrain"]
collision_layer = 1
collision_mask = 0
metadata/surface = &"grass"

[node name="Steps" type="StaticBody3D" parent="Terrain"]
collision_layer = 1
collision_mask = 0
```

That is three surfaces from two tags: `Ground` is grass because it says so, `Steps` is stone
because the nearest tagged ancestor says so, and anything else under `Terrain` is stone too. Tag
the root once and override only what differs — the way a stylesheet works, for the reason a
stylesheet works that way.

**The name is yours and the engine has never heard of it.** There is no list of legal surfaces and
no enum, because a list in `src/` would be engine code naming your content, which `check_boundary`
fails the build over. `sand`, `snow`, `boardwalk` and `wet_stone` all work the day you write them.

**What follows from a tag, with no further authoring:** a character carrying the `Footsteps`
component (the player prefab has one) takes a step every 1.7 metres walked, and the step's sound is
**derived from the surface's name** — brightness and decay both. So two surfaces sound different
and the same surface sounds the same everywhere. There are no audio files; art is deferred, so the
step is generated the way the rain is.

**Untagged ground is legal and silent, and it says so once** at INFO level:
`Ground under 'Footsteps' carries no metadata/surface, so steps are silent here`. A game that wants
no footsteps simply tags nothing.

**CHECKING A TAG IS THE ONE THING THIS DOCUMENT CANNOT GIVE YOU A COMMAND FOR, so here is what it
takes.** No gate reads `metadata/surface` — it is node metadata, not content, so `check_content`
never sees it — and nothing is logged when an area loads. The surface is resolved only when a
character actually WALKS, and no debug flag walks anybody: `--stand-by` teleports and the capture
flags pose a still. So a tag is confirmed by the footstep line appearing on a run you drive by
hand with the arrow keys, and the honest answer for a headless check is that there is not one.
Tag the root, override what differs, and read the first line each surface logs when you walk onto
it.

### A character: one flag, one name, one consumer

An attribute is the flag `attr/<character id>/<name>`, holding an integer number of **steps** from
0, clamped to ±4. There is no resource to author and nothing to register.

```bash
"$G" --resolution 960x540 --quit-after 120 -- --new-game --flag=attr/player/pace:4 \
     --shot="$(pwd)/build/shots/quick.png" --shot-frame=100 --time=12:00 --freeze-time
```

`pace` is the one attribute the engine reads today: `PlayerController` scales **every** gait by
`1.0 + steps * 0.125`, so at +4 the player walks, runs and sneaks half again as fast and at -4 at
half speed. Anything that can write a flag can change it — a `DialogueChoice` effect, a
`TriggerVolume`, a `Lever`, a quest consequence — and none of them has heard of attributes.

Because it is a flag it is already saved, already cleared by a new game and already announced on
`flag_changed`, so a quest step or a dialogue condition can test one with no code at all.

**Naming a new attribute costs nothing; READING one costs a line of engine code**, and that is
stated rather than hidden. `attr/player/patience` is writable today and nothing will do anything
with it. The name of an attribute lives as a constant on whatever consumes it — `PlayerController.PACE`
— precisely so that an attribute nobody reads has nowhere to be written down.

---

## Add an interactable object

Everything the player can act on is an **instance of a prefab from `scenes/objects/`**, placed
under an area's `Interactables` (or `Triggers`, for a volume). You write no code for any of these.

| Prefab | Class | The fields that matter |
|---|---|---|
| `sign.tscn` | `Readable` | `text_key`, `display_seconds` |
| `lever.tscn` | `Lever` | `world_flag`, `notify_on_key`, `notify_off_key` |
| `gate.tscn` | `Gate` | `requires_flag` **or** `requires_item`, `locked_key`, `opened_key`, `stays_open`, `blocker`, `open_shake` |
| `pickup.tscn` | `Pickup` | `item` (an `ExtResource` pointing at an `ItemDefinition`), `count` |
| `chest.tscn` | `ItemContainer` | `contents` — `Array[ItemDefinition]([...])`, repeat an entry for a second copy |
| `rest_point.tscn` | `RestPoint` | `target_hour`, `night_only`, `rested_key` |
| `climb_point.tscn` | `ClimbPoint` | `bottom_point`, `top_point` (`Marker3D`s), `requires_flag` |
| `area_door.tscn` | `AreaDoor` | `target_area`, `target_spawn` |
| `trigger_volume.tscn` | `TriggerVolume` | `world_flag`, `notify_key`, `fires_once`, `notify_seconds` |
| `path_action.tscn` | `PathActionPoint` | `action` (a `PathAction` resource), `standing_id` |
| `speaker.tscn` | `Speaker` | `conversation_id` |

Every one of them also takes the `Interactable` fields: `object_id`, `label_key`, `verb`,
`interact_priority`, `available`, `one_shot`, `hold_seconds`.

```
[node name="GardenNotice" parent="Interactables" instance=ExtResource("7_sign")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 2, 0.9, -3)
object_id = &"garden_notice"
label_key = "object.sign.garden.label"
text_key = "object.sign.garden.text"
```

**A trigger volume never names its consequence.** It sets a flag and emits
`Events.trigger_fired`; anything may watch either. Same for a lever. That is what stops the object
catalogue growing a class per plot beat.

**`verb` is stored as an ordinal.** `GameEnums.InteractVerb` is appended to and never reordered
for exactly this reason: moving a value would silently repoint every authored scene at a different
verb. Write the number (`verb = 5` is `TALK`) or leave the prefab's default.

---

## Add an item

One file, four fields, no registration:

```
[gd_resource type="Resource" script_class="ItemDefinition" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/content/items/item_definition.gd" id="1_def"]

[resource]
script = ExtResource("1_def")
id = &"item/rose_key"
name_key = "item.rose_key.name"
category = 2
max_stack = 1
```

- Save it in **`data/items/`**. `ItemDb` finds it by scanning that directory (ADR-0006) — an
  `ItemDefinition` anywhere else is invisible to `Inventory.add(id)` while still being loadable by
  a `Pickup`, which is the one silent failure this design admits, and `check_content` reports it.
- `id` is `item/` plus the file name. `max_stack = 1` is how a unique key item is expressed;
  there is no `stackable` bool, because two fields encoding one fact eventually disagree.
- `category` is a `GameEnums.ItemCategory` ordinal: `0` TOOL, `1` CONSUMABLE, `2` KEY_ITEM,
  `3` QUEST, `4` MATERIAL, `5` CLOTHING, `6` DOCUMENT, `7` TREASURE. There is no weapon or armour
  category and there will not be one.
- `name_key` must have a CSV row, or the inventory screen prints the key at the player.
- `equip_slot` is optional and defaults to `0` NONE, which is what almost every item is. See the
  next section for what a non-zero value buys.

---

## Make an item equippable, and gate a way through on it

An equippable item is an ordinary item with one extra field. There is no equipment resource, no
slot table to register in and nothing to wire:

```
[gd_resource type="Resource" script_class="ItemDefinition" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/content/items/item_definition.gd" id="1_def"]

[resource]
script = ExtResource("1_def")
id = &"item/brass_lantern"
name_key = "item.brass_lantern.name"
category = 0
max_stack = 1
equip_slot = 1
```

`equip_slot` is a `GameEnums.EquipSlot` ordinal: `0` NONE, `1` LIGHT, `2` TOOL, `3` GARMENT,
`4` TRINKET. There is no weapon slot and no armour slot, for the same reason `ItemCategory` has
no weapon category. Like `InteractVerb`, the enum is appended to and never reordered, because
your `.tres` stores the number.

The player equips it from the satchel screen: `I` to open, arrow keys to the row, **Enter** to
hold or stow. A held row reads `Brass Lantern  x1   [in hand]`. **The item stays in the bag while
it is held** — so a gate that wants it *carried* is still satisfied, and `Inventory.count_of()`
never disagrees with the screen.

### The seam: what is held is a FLAG

Holding an item writes one flag, and that is the whole interface:

```
equip/<wearer id>/<item id>          e.g.  equip/player/item/brass_lantern
```

The wearer id is `player` unless a scene overrode it on that carrier's `Equipment` node. Because
it is a flag, **everything that can already read a flag can gate on what is in hand, with no code
and no new field**:

| To make | Set |
|---|---|
| a way through that needs a light | a `Gate` with `requires_flag = &"equip/player/item/brass_lantern"` |
| a quest step that ends when you pick the lantern up and hold it | a `QuestStep` with that flag and `condition_test = 1` |
| a reply that only appears with a light in hand | a `DialogueChoice` with that flag and `condition_test = 1` |
| a climb only possible unencumbered | a `ClimbPoint`'s `requires_flag`, tested the other way |

None of those four classes knows equipment exists. The gate in the demo courtyard is exactly the
first row:

```
[node name="ShadowedArch" parent="Interactables" instance=ExtResource("9_gate")]
object_id = &"shadowed_arch"
label_key = "object.gate.arch.label"
requires_flag = &"equip/player/item/brass_lantern"
locked_key = "object.gate.arch.locked"
opened_key = "object.gate.arch.opened"
```

### Write the refusal, or the player gets a line about a different door

`locked_key` is what the player reads when they are turned away. Leave it out and they get the
generic `refusal.locked` — *"It will not budge. Something holds it shut."* — which is true of
every locked thing in every game and tells them nothing about needing a light. Every `Interactable`
may name a line this way for the reason it refuses; `Gate` names one for LOCKED, and a
`PathAction`'s `refusal_key` names one for LOW_STANDING.

### Three behaviours worth knowing before you write

- **One item per slot, and the newcomer wins.** Holding a second LIGHT stows the first rather than
  being refused, because a refusal would make swapping a lantern a two-step chore.
- **Losing the item stows it.** Sell, drop or lose an item and the flag goes with it, so a gate
  gated on it locks again — though a `Gate` with `stays_open = true`, which is the default, has
  already opened for good.
- **A new game clears it, and a save restores it.** Equipment has no save section of its own; it
  IS flags, so it round-trips through the machinery that already exists.

### Seeing it

```bash
G=/c/Rai/softwares/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe
"$G" --resolution 960x540 --quit-after 90 -- --new-game --give=item/brass_lantern \
     --equip=item/brass_lantern --open-inventory --shot=held.png --shot-frame=70 \
     --time=12:00 --freeze-time
```
`--equip` applies **after** the area lands, for the same reason `--flag` does: the flag it writes
is a flag, and `--new-game` clears every one of them first. Swap `--open-inventory` for
`--stand-by=ShadowedArch --interact=1` to photograph the gate being refused, and then the same
line with `--equip` to photograph it opening.

**For a gate in an area of your own, add `--goto` and move the frames out.** `--stand-by` waits
for a settled area, which lands well after the seventieth frame when a travel is in flight:

```bash
"$G" --resolution 960x540 --quit-after 340 -- --new-game --goto=my_area \
     --stand-by=MyGate --interact=260 --shot="$(pwd)/build/shots/refused.png" \
     --shot-frame=290 --time=12:00 --freeze-time
```

---

## Add a conversation

A conversation is a `.tres` in `data/dialogue/`, found by scan like an item. It is an **ordered
array of nodes**, and the runner falls through — the entry point is the first node whose condition
passes, not `nodes[0]`. That is what makes "if we have met, greet me differently" two nodes and no
wiring at all.

### The three resources

- **`Conversation`** — `id` (equal to `talk/` plus the file name) and `nodes`, in authored order.
- **`DialogueNode`** — `node_id`, `speaker_key`, `text_key`, and then either `next_node` or
  `choices`. Plus one condition (`condition_flag`, `condition_test`, `condition_value`) and one
  effect (`effect_flag`, `effect_write`, `effect_value`).
- **`DialogueChoice`** — `text_key`, `target_node`, and a condition of its own. **No effect:**
  effects fire on *arrival* at a node, so a node has the same consequence however it was reached.

`condition_test` is a `GameEnums.FlagTest` ordinal — `0` ALWAYS, `1` IS_TRUE, `2` IS_FALSE,
`3` EQUALS, `4` AT_LEAST, `5` AT_MOST. `effect_write` is `GameEnums.FlagWrite` — `0` NONE,
`1` SET_TRUE, `2` SET_FALSE, `3` SET_INT, `4` ADD.

**It is a closed set of comparisons, deliberately, and not an expression language.** The moment a
conversation can hold an expression it needs a parser, error reporting and a sandbox, and the
`.tres` stops being reviewable in a diff. If six tests are genuinely not enough, the answer is a
seventh, not a grammar.

Two behaviours worth knowing before you write:

- **An empty `next_node` ends the conversation.** It does *not* fall through to the next node in
  the array — "ends here" and "continues to whatever happens to be next" must not look identical.
- **A choice whose condition fails is omitted, not greyed out.** The opposite of a locked gate,
  on purpose: a gate you cannot open tells you to come back, a reply you cannot give tells you
  only that the writer thought of it.

### A worked conversation

Sub-resources are declared before `[resource]` and referenced by `SubResource("id")`:

```
[gd_resource type="Resource" script_class="Conversation" load_steps=8 format=3]

[ext_resource type="Script" path="res://src/content/dialogue/conversation.gd" id="1_talk"]
[ext_resource type="Script" path="res://src/content/dialogue/dialogue_node.gd" id="2_node"]
[ext_resource type="Script" path="res://src/content/dialogue/dialogue_choice.gd" id="3_choice"]

[sub_resource type="Resource" id="choice_ask"]
script = ExtResource("3_choice")
text_key = "talk.warden.choice.ask"
target_node = &"answer"

[sub_resource type="Resource" id="choice_leave"]
script = ExtResource("3_choice")
text_key = "talk.warden.choice.leave"
target_node = &""

[sub_resource type="Resource" id="node_greet_again"]
script = ExtResource("2_node")
node_id = &"greet_again"
speaker_key = "talk.warden.name"
text_key = "talk.warden.greet_again"
next_node = &"menu"
condition_flag = &"met/warden"
condition_test = 1

[sub_resource type="Resource" id="node_greet_first"]
script = ExtResource("2_node")
node_id = &"greet_first"
speaker_key = "talk.warden.name"
text_key = "talk.warden.greet_first"
next_node = &"menu"
effect_flag = &"met/warden"
effect_write = 1

[sub_resource type="Resource" id="node_menu"]
script = ExtResource("2_node")
node_id = &"menu"
speaker_key = "talk.warden.name"
text_key = "talk.warden.menu"
choices = Array[DialogueChoice]([SubResource("choice_ask"), SubResource("choice_leave")])

[sub_resource type="Resource" id="node_answer"]
script = ExtResource("2_node")
node_id = &"answer"
speaker_key = "talk.warden.name"
text_key = "talk.warden.answer"

[resource]
script = ExtResource("1_talk")
id = &"talk/warden"
nodes = Array[DialogueNode]([SubResource("node_greet_again"), SubResource("node_greet_first"), SubResource("node_menu"), SubResource("node_answer")])
```

`greet_again` comes **before** `greet_first` in the array: the runner takes the first node whose
condition passes, so the conditional greeting has to be offered the chance to win.

Every `text_key`, `speaker_key` and choice `text_key` needs a CSV row. `check_content` resolves
all of them, and resolves dangling `next_node` / `target_node` links as well — the single most
likely mistake in a format like this, and otherwise invisible until a player walks that branch.

**A conversation is not saved.** Persisting a position would write a node id into the save file
and make every node id in every `.tres` a permanent public identifier. A save taken
mid-conversation reloads with the conversation over and control returned.

---

## Add an NPC

An NPC is an instance of `scenes/characters/npc.tscn` under an area's `Actors`. The prefab already
carries the brain, the sprite, a navigation agent, a `PersistentState` and a `Talk` speaker; you
override their fields from the area scene.

### 1. A schedule, if it should move

`data/schedules/<name>.tres`, found by scan:

```
[gd_resource type="Resource" script_class="NpcSchedule" load_steps=5 format=3]

[ext_resource type="Script" path="res://src/content/npc/npc_schedule.gd" id="1_sched"]
[ext_resource type="Script" path="res://src/content/npc/schedule_entry.gd" id="2_entry"]

[sub_resource type="Resource" id="morning"]
script = ExtResource("2_entry")
from_hour = 6
waypoint = &"gate_post"
activity = 1

[sub_resource type="Resource" id="night"]
script = ExtResource("2_entry")
from_hour = 20
waypoint = &"bench"
activity = 2

[resource]
script = ExtResource("1_sched")
id = &"schedule/keeper"
entries = Array[ScheduleEntry]([SubResource("morning"), SubResource("night")])
```

- `id` is `schedule/` plus the file name.
- `activity` is a `GameEnums.NpcActivity` ordinal: `0` STAND, `1` WANDER, `2` SLEEP.
- **An entry has no `until_hour`.** It runs until the next begins, and the last wraps past
  midnight, so a day is always completely covered and two entries cannot disagree about who owns
  14:00. List them in ascending `from_hour`.
- **`waypoint` names a `Marker3D` under some area's `Waypoints`, by node name.** `check_content`
  fails a schedule that names a waypoint no area has — an NPC sent somewhere that does not exist
  stands still forever and nothing says why. It cannot check that the marker is in the *right*
  area; that is a placement mistake, and it looks like an NPC that never leaves its spawn.
- **Put waypoints somewhere the body can walk**, which is not the same as somewhere the navmesh
  covers. See `agent_max_climb`, above.

**A MARKET DAY: ONE EXTRA ENTRY, NOT A SECOND SCHEDULE.** As of T5.32 an entry also carries
`on_day_of_cycle`, and **`-1` means every day and is the default** — so everything above is
complete and correct for a schedule that repeats daily, and every `.tres` written before the field
existed keeps working with no edit. To make the keeper go somewhere else on one day of the cycle,
leave the ordinary block alone and add one entry beside it:

```
[sub_resource type="Resource" id="market_morning"]
script = ExtResource("2_entry")
from_hour = 6
on_day_of_cycle = 3
waypoint = &"market_stall"
activity = 0
```

- **A day-specific entry BEATS an every-day entry at the same hour.** That is the whole gesture:
  the two collide on `from_hour` and the day breaks the tie, so you never rewrite the ordinary
  block to make room for a special one.
- **Every hour the special day says nothing about still runs the ordinary blocks.** Authoring one
  unusual morning does not blank the rest of that day.
- **The cycle length is `Clock.days_per_cycle`, which defaults to 7 and is your game's to set** —
  from code at startup, the same way `seconds_per_minute` is set. Days run `1` to
  `days_per_cycle`, and day 1 of a new game is day 1 of the cycle.
- **EVERY SCHEDULE NEEDS AT LEAST ONE ENTRY AT `-1`, and `check_content` fails one that has
  none.** This is the rule to know, because breaking it is silent in the worst way. A schedule made
  only of day-specific entries answers **nothing at all** on any day it does not name — measured at
  24 hours of 24 — and `NpcBrain` returns early on that, so the NPC stands wherever it last was and
  nothing says why. One every-day entry is exactly what guarantees full coverage, so the gate asks
  for exactly that. T5.32 introduced the hole and T5.33 closed it; if you are reading a fork at
  `5.6.0`, the hole is open and unreported.
- **Nothing validates a day against the real cycle length**, and this is the other trap here. An
  `on_day_of_cycle` of `9` on a seven-day cycle parses, loads, passes `check_content` and is simply
  a block that never runs. `NpcSchedule` and `ScheduleEntry` are in the `content` layer and may not
  touch an autoload, so no validator there can ask `Clock` what the cycle length is —
  `check_layers.gd` exists to refuse exactly that dependency. Count your own days.
- **Two entries agreeing on the hour AND the day is still a reported defect**, because that one is
  ambiguous in the old array-order way. Sharing only the hour is not.

### 2. Placing it, and the editable trap

Declare the prefab as an `ExtResource` at the top of the area scene, then instance it:

```
[ext_resource type="PackedScene" path="res://scenes/characters/npc.tscn" id="19_npc"]

[node name="Warden" parent="Actors" instance=ExtResource("19_npc")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1.7, 0, 4.2)
schedule_id = &"schedule/warden"

[node name="PersistentState" parent="Actors/Warden"]
object_id = &"warden"

[node name="Talk" parent="Actors/Warden"]
object_id = &"warden_talk"
label_key = "object.warden.label"
conversation_id = &"talk/warden"

[editable path="Actors/Warden"]
```

`schedule_id` is on the instance root, so it needs no marker. `PersistentState` and `Talk` are
**children of the instanced prefab**, and overriding them is what requires the `[editable]` line.

An NPC with no `schedule_id` stands where it was placed, which is a legitimate thing to author.
An NPC with no `conversation_id` on its `Talk` offers a prompt that does nothing, which is not.

### 3. Optional: path actions on the same NPC

An NPC's non-combat verbs — scrutinise, barter, inquire — are **overlapping interactables, not a
menu**: the sensor already ranks and Tab-cycles between overlapping targets, and a menu would be a
second selection mechanism competing with the first. Instance `path_action.tscn` as an extra child
of the NPC (also inside the `[editable]`), point its `action` at a `PathAction` in `data/actions/`,
and set `standing_id` to the same name the NPC's standing is kept under.

`PathAction` distinguishes a **refusal** from a **failure**, and the distinction is the design: a
refusal happens before anything, costs nothing and explains itself; a failure happens after
committing and costs something. `once` applies to success only, or one early failure would lock
the player out forever.

Unlike items, conversations and schedules, a `PathAction` is **referenced by path, not found by
scan** — there is no registry and no id-equals-filename rule. `check_content` still validates
every `.tres` in `data/actions/`.

---

## Add a quest

A quest is a `.tres` in `data/quests/`, found by scan like an item. **You never write code and you
never wire anything to it.** A quest names the flag conditions it cares about, and `QuestTracker`
watches `Flags` and does the rest.

### The one idea to get first: a quest observes, it is never told

There is no "give quest" call, no `start_quest()` and nothing for an NPC to point at. A quest
declares:

- a **start condition** — one flag test. When it passes, the quest is active.
- **steps in order** — one flag test each. The current objective is the *first* step whose test
  does not pass. When none is left, the quest is complete.

So a conversation that already writes `met/warden` starts any quest that tests `met/warden`, and
the conversation has never heard of quests. Same for a lever, a trigger volume, a gate, or a path
action — anything that writes a flag can advance a quest, and none of them needs changing.

Which means the practical question when authoring a quest is **"what flag does the thing I want
already write?"** The six writers, and where each is documented:

| To finish a step on | The flag comes from | Set it in |
|---|---|---|
| talking to someone | a `DialogueNode` effect | § Add a conversation — `effect_flag` / `effect_write` |
| throwing a lever | `Lever.world_flag` | § Add an interactable object |
| walking somewhere | `TriggerVolume.world_flag` | § Add an interactable object |
| acting on an object | `PersistentState` — `obj/<area_id>/<object_id>/<field>` | the field table below |
| a path action succeeding | `PathAction.success_flag` | § Add an NPC, step 3 |
| holding an item | `Equipment` — `equip/<wearer>/<item id>` | § Make an item equippable |
| carrying N of an item | `Inventory` — `bag/<carrier>/<item id>` | § Count items in a quest step |
| the time of day | `Clock` — `time/hour`, `time/day`, `time/day_of_cycle`, `time/phase/<name>` | § Gate on the time or the weather |
| the weather | `Weather` — `weather/kind/<name>` | § Gate on the time or the weather |

**An item count IS a flag**, as of T3.3 — see the next section. That is the seventh writer, and it
is the only one whose value is a *number* rather than a truth.

**And so is the clock**, as of T5.31 — the eighth and ninth writers, and the only two you never
have to set: they publish themselves and are never saved. See § Gate on the time or the weather.

**THE `obj/` FIELD NAMES, BECAUSE GUESSING ONE COSTS YOU A STEP THAT CAN NEVER FINISH.** Each
prefab persists under one field, and every one of them is shorter than the word you would guess:

| Prefab | The flag it writes |
|---|---|
| `gate.tscn` | `obj/<area>/<object_id>/open` — **not** `opened` |
| `lever.tscn` | `obj/<area>/<object_id>/thrown` |
| `chest.tscn` | `obj/<area>/<object_id>/emptied` |
| `pickup.tscn` | `obj/<area>/<object_id>/taken` |
| `sign.tscn` | `obj/<area>/<object_id>/read` |
| `trigger_volume.tscn` | `obj/<area>/<object_id>/fired` |
| `path_action.tscn` | `obj/<area>/<object_id>/done` |

**This is the one flag family no gate can check for you, and it is the likeliest mistake in this
document.** `check_content` fails a step that counts an item no `.tres` declares, and resolves
every dialogue link — but an `obj/` key naming a field nothing writes is indistinguishable from
one naming a field something writes, because the field lives in engine code and the object is
placed in a scene. T4.2 wrote `obj/orchard/bramble_way/opened` from this table when it named no
fields at all: `check_content` passed, the journal drew the objective, the run reported
`0 warnings, 0 errors`, and the step could never have been satisfied. Read the field out of a run
before you trust it — every write is logged at DEBUG as `obj/... = true`.

### The two resources

- **`Quest`** — `id` (equal to `quest/` plus the file name), `name_key`, `summary_key`, `steps` in
  authored order, and one start condition (`condition_flag`, `condition_test`, `condition_value`).
- **`QuestStep`** — `step_id` (unique within the quest), `summary_key`, and one completion
  condition with the same three field names.

`condition_test` is a `GameEnums.FlagTest` ordinal, the same closed set a dialogue condition uses —
`0` ALWAYS, `1` IS_TRUE, `2` IS_FALSE, `3` EQUALS, `4` AT_LEAST, `5` AT_MOST. `ALWAYS` as a start
condition means the quest is active from the first frame of a new game, which is right for a
tutorial objective and wrong for everything else.

### A worked quest

Sub-resources are declared before `[resource]` and referenced by `SubResource("id")`:

```
[gd_resource type="Resource" script_class="Quest" load_steps=4 format=3]

[ext_resource type="Script" path="res://src/content/quest/quest.gd" id="1_quest"]
[ext_resource type="Script" path="res://src/content/quest/quest_step.gd" id="2_step"]

[sub_resource type="Resource" id="step_lantern"]
script = ExtResource("2_step")
step_id = &"lantern"
summary_key = "quest.warden_lamps.step.lantern"
condition_flag = &"count/lanterns_lit"
condition_test = 4
condition_value = 3

[sub_resource type="Resource" id="step_report"]
script = ExtResource("2_step")
step_id = &"report"
summary_key = "quest.warden_lamps.step.report"
condition_flag = &"story/warden_thanked"
condition_test = 1

[resource]
script = ExtResource("1_quest")
id = &"quest/warden_lamps"
name_key = "quest.warden_lamps.name"
summary_key = "quest.warden_lamps.summary"
steps = Array[QuestStep]([SubResource("step_lantern"), SubResource("step_report")])
condition_flag = &"met/warden"
condition_test = 1
```

Save it in **`data/quests/`**. `name_key`, `summary_key` and every step's `summary_key` need a CSV
row, and `check_content` fails on any that does not have one — plus it prints every flag the quest
and its steps name, which is the line to read when a quest starts and can never finish.

### Four behaviours worth knowing before you write

- **Step order is authored, not chronological.** Satisfying step two before step one leaves step
  one as the current objective. That is what makes a journal read like instructions.
- **Completion is permanent; a step is not.** Once every step has passed, the quest is complete and
  *stays* complete even if the flags move back — a counter that gets decremented must not reopen a
  finished quest. An **active** quest's objective, by contrast, is re-derived every time a flag
  changes, so clearing the flag behind objective two brings objective two back. Both are
  deliberate; the reasoning is in `src/systems/quest/quest_tracker.gd`.
- **A completed quest gives you nothing by itself.** It emits `Events.quest_completed(quest_id)`
  and stops. To hand over an item, open a gate or start the next chapter, listen to that signal —
  or, with no code at all, have a conversation node condition on the flag the last step tested.
- **A quest is saved by id.** Started and completed are written to the save; the current objective
  is re-derived on load, so renaming a `step_id` does not break an old save. Renaming a **quest
  id** does: it is a public identifier, exactly like an `object_id`.

### Seeing it

The journal is the `J` key, or `--open-menu=journal` for a capture. Because a step is a flag
condition, `--flag=` poses quest progress without playing to it:

```bash
G=/c/Rai/softwares/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe
"$G" --resolution 960x540 --quit-after 90 -- --new-game --flag=met/warden:true \
     --open-menu=journal --shot=journal.png --shot-frame=70 --time=12:00 --freeze-time
```

`--flag` applies **after** the area lands, because `--new-game` clears every flag first.

---

## Count items in a quest step

"Bring me three rose petals" is a step like any other. There is no new field, no `required_item`
and nothing to wire — an `Inventory` publishes how much of each thing its carrier holds as a
flag, and a step tests that flag with the closed set it already had:

```
bag/<carrier_id>/<item id>            bag/player/item/rose_petal -> 3
```

```
[sub_resource type="Resource" id="step_petals"]
script = ExtResource("2_step")
step_id = &"petals"
summary_key = "quest.keepers_errand.step.petals"
condition_flag = &"bag/player/item/rose_petal"
condition_test = 4
condition_value = 3
```

`4` is `AT_LEAST`, so a fourth petal does not un-finish the step. `carrier_id` is an `@export` on
the `Inventory` node — `player` for the player's bag, and a stash or an NPC satchel sets its own,
which is why the carrier is in the key at all.

**Six things to know, and the third and fourth are the ones that surprise people.**

- **Only `AT_LEAST` (4) and `EQUALS` (3) count.** `AT_MOST` is a ceiling, not a tally, and the
  journal deliberately draws no progress line under one: "2 / 3" beneath *keep it under three*
  tells the player to gather the one thing they must not.
- **`condition_value` must be at least 1.** `AT_LEAST 0` is satisfied by an empty bag, so it is an
  unconditional step wearing an errand's clothes. `check_content` fails the build on one.
- **The journal draws the tally by itself**, as `— Gather three rose petals.   2 / 3`, from
  `ui.journal.progress`. Change the wording in the CSV, not in a screen.
- **A count can go back down, and a step reopens with it.** Spend two of the three and the
  objective returns, because a step is a live question about the world — the same rule that makes
  clearing a lever's flag reopen the step it finished. A **completed quest** does not reopen,
  which is exactly why that latch exists.
- **An item id that no `.tres` in `data/items/` declares can never be satisfied**, and nothing at
  runtime says so — the count simply reads zero forever. `check_content` fails on that too, which
  is the only thing between a plural slip and an errand nobody can finish.
- **The count is not in your save file twice.** The flag is a projection of the bag, published by
  `Inventory` and re-published on load; the counts themselves are saved once, by the bag.

**What this does NOT give you** is a step that *takes* the items. Nothing hands anything over: a
completed quest emits `Events.quest_completed` and stops (see the fourth behaviour above). A
consuming game that wants the petals collected on delivery listens to that signal, or puts an
`ItemContainer` in front of the keeper.

### Seeing a count, and posing one

The journal is the `J` key, or `--open-menu=journal` for a capture, and `--give=` poses a count
the way `--flag=` poses everything else - because a count is a flag:

```bash
G=/c/Rai/softwares/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe
"$G" --resolution 960x540 --quit-after 130 -- --new-game --give=item/rose_petal:2 \
     --flag=met/gardener:true --open-menu=journal --shot=journal.png --shot-frame=110 \
     --time=12:00 --freeze-time
```

Both flags apply **after** the area lands, because `--new-game` clears every flag *and empties the
bag* first.

```bash
G=/c/Rai/softwares/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe
"$G" --resolution 960x540 --quit-after 90 -- --new-game --flag=met/warden:true \
     --open-menu=journal --shot=journal.png --shot-frame=70 --time=12:00 --freeze-time
```

`--flag` applies **after** the area lands, because `--new-game` clears every flag first.

---

## Gate on the time or the weather

**You set nothing. `Clock` and `Weather` publish these themselves, every tick, and none of them is
saved** — they are recomputed from the clock's own saved state on load. Name one in any
`condition_flag` and it works, in a conversation or in a quest step alike.

| Write this in `condition_flag` | With this test | And it means |
|---|---|---|
| `time/hour` | `AT_LEAST 9` | it is 09:00 or later |
| `time/hour` | `AT_MOST 17` | it is no later than 17:59 |
| `time/day` | `AT_LEAST 3` | the third day has begun |
| `time/day_of_cycle` | `EQUALS 3` | it is day 3 of the repeating cycle — a market day |
| `time/day_of_cycle` | `AT_LEAST 5` | it is the back half of the cycle |
| `time/phase/dusk` | `IS_TRUE` | it is dusk right now |
| `time/phase/deep_night` | `IS_FALSE` | it is anything but the small hours |
| `weather/kind/rain` | `IS_TRUE` | it is raining |
| `weather/kind/clear` | `IS_FALSE` | the sky is doing something |

The `<name>` on the end is a `GameEnums.DayPhase` or `GameEnums.WeatherKind` entry **lowercased**:
`dawn`, `morning`, `midday`, `afternoon`, `dusk`, `night`, `deep_night`; and `clear`, `cloudy`,
`overcast`, `rain`, `storm`, `fog`, `snow`, `wind`.

**Shop hours are two conditions, and a quest step or a dialogue node has one each.** So a shop that
is open 09:00–17:59 is a step gated on `time/hour AT_LEAST 9` whose *next* step is gated on
`AT_MOST 17`, or — far more usually — a conversation whose nodes branch on one of them. If you
need both at once on a single line, that is a game writing a tiny listener in its own code root
that sets a flag of its own; the base deliberately does not grow an expression language for it.

**A PHASE IS A NAME, NOT A NUMBER, AND THE TRAP IS WORTH ONE PARAGRAPH.** There is no `time/phase`
holding a number, and you must not go looking for one. Enum ordinals are a storage format —
`GameEnums` is append-only precisely because its numbers sit inside your `.tscn` and `.tres` files
— so an `EQUALS 4` on a phase would be correct only by accident of enum order. And an *ordering*
comparison on a phase is meaningless regardless: across a day the ordinals run
`6,6,6,6,6,0,0,1,1,1,1,2,2,2,3,3,3,4,4,4,5,5,5,5`, because `DEEP_NIGHT` is the last enum entry and
the earliest hours. Equality on a named bool is the only sound question, which is why it is the
only one offered.

**BUT `time/day_of_cycle` IS AN INT, AND THE PARAGRAPH ABOVE DOES NOT APPLY TO IT.** That is worth
being explicit about, because the two sit in the same table and the reasoning looks transferable.
It is not. A phase has an enum behind it and a day *wraps* where an enum does not, which is what
makes ordering on it meaningless. A day of the cycle has no enum behind it and does not wrap inside
its own range: it runs `1` to `Clock.days_per_cycle` and stops. So **both `EQUALS` and `AT_LEAST`
mean exactly what you would expect** — `EQUALS 3` is one day, `AT_LEAST 5` is the back half of the
cycle — and there is no bool-per-name row like `time/day_of_cycle/3` to look for. Ask the int.

**And there are no weekday names, months, seasons or dates, deliberately.** A cycle *length* is a
number, so the base supplies it as a default with a seam; a *calendar* — what day 3 is called, how
many days are in a month, when autumn starts — is your game's own, and
[ADR-0007](decisions/ADR-0007-template-default-vs-game-choice.md) is where that line is drawn. If
you want "Market Day" on screen, that is a localization key your game maps from
`time/day_of_cycle`, and the mapping lives in your code root rather than in `src/`.

**Exactly one phase flag and one weather flag exist at a time.** The others are *erased*, not set
false — so `IS_FALSE` on `time/phase/dawn` is true all day, exactly as you want, and a debug dump
stays one row per concept instead of fifteen.

**Do not put your own flags under `time/` or `weather/`.** Those two namespaces belong whole to
those two files and are declared derived, so a flag of yours there would silently stop being
saved.

There is deliberately no `time/minute`: a minute is a continuous value for interpolating a
lighting gradient, not a question a condition asks, and publishing it would rewrite a flag 1,440
times a day. For a `night_only` rest point, note you do not need a flag at all — `RestPoint` has an
`@export var night_only` that asks `Clock.is_night()` directly.

---

## The editable trap

**A `[node]` block whose `parent=` descends into an instanced node requires
`[editable path="<that instance>"]` at the foot of the scene.**

Without it, running from source works perfectly — the text loader applies the override. An export
converts `.tscn` to binary `.scn`, and the conversion **silently discards** the override, so the
prefab reverts to its defaults in the shipped build *only*. The demo's NPC shipped with no
`object_id`, no prompt and no conversation exactly this way, while every ladder rung, both CI jobs
and 930 assertions stayed green.

`tools/check_content.gd` gates it now, and is deliberately stricter than the failure needs — an
*added* node inside an instance survives the conversion and is still required to be declared,
because "which of the two kinds is this" is a distinction the exporter makes and an author should
not have to remember. Godot needs the marker at **every** level, so a nested instance needs one
per level.

Two related notes. `index="4"` on such a block is written by the editor and is **not** what
resolves the node — the name is; stale indices look like the culprit here and are not. And
overriding a property on the instance's *root* (like `schedule_id` above) needs no marker at all.

---

## Localization

`localization/strings.csv`, header row `keys,en`. Which prefixes are yours and which are the
engine's is the table in [`TEMPLATE.md`](TEMPLATE.md): `area.*`, `object.*`, `item.*`
(except `item.category.*`), `talk.*`, `action.*` and `quest.*` are content; `ui.*`, `verb.*`,
`refusal.*`, `notify.*`, `weather.*` and `time.*` are engine. Those six content prefixes are
exactly what `check_boundary.gd` derives `CONTENT_NAMESPACES` from, so the table and the gate
cannot disagree without the build going red.

```
area.my_area.name,My Area
object.sign.garden.label,Weathered Notice
object.sign.garden.text,"Mind the thorns, and the hour."
```

Quote any value containing a comma. Re-run `--headless --import` afterwards to regenerate the
`.translation`. A key with no row is not an error at load — `tr()` returns the key itself, and the
player reads `object.sign.garden.label` on screen — which is why `check_content` resolves every
`_key` literal in every scene and every key a conversation or a path action names.

---

## The gates, and what each one catches

Run all of them. In this order, because a later one assumes the earlier passed.

```bash
G=/c/Rai/softwares/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe
"$G" --headless --import                                     # grep for SCRIPT ERROR / Parse Error
"$G" --headless --quit-after 30                              # must end "0 warnings, 0 errors"
"$G" --headless res://tests/test_runner.tscn --quit-after 400
"$G" --headless --script tools/check_content.gd
"$G" --headless --script tools/check_boundary.gd
"$G" --headless --script tools/check_budgets.gd
"$G" --headless --script tools/check_strings.gd
"$G" --headless --script tools/check_layers.gd
"$G" --headless --script tools/check_signals.gd
"$G" --headless --script tools/check_methods.gd
"$G" --resolution 960x540 --quit-after 90 -- --new-game --shot=shot.png --shot-frame=70 \
     --time=12:00 --freeze-time
```

| Gate | Catches, for an author |
|---|---|
| `--import` | a `.tscn` that does not load, a script that does not parse |
| boot run | that the game boots clean to its main menu. **It does not enter an area** — see below |
| test suite | a missing required child, an area with no spawn, an interior that follows the sun, a schedule waypoint no area has, a quest with no steps, an area on the map with no scene, a map dot whose `arrival_spawn` no area has |
| `check_content` | a duplicate `object_id`, a `_key` with no CSV row, an unquoted comma, a dangling dialogue link, an id that disagrees with its file name, a stray `ItemDefinition`, a quest step whose objective has no CSV row, a gate whose `locked_key` has no row, an `AreaDef` whose `name_key` has no row, **a quest step counting an item no `.tres` declares, or counting zero of one**, **a missing `[editable]` marker** |
| `check_boundary` | your content id appearing in `src/` or in `tests/unit/`. Since T5.4 it also fails a CSV ROW that translates content which is not there, which is what makes an unfinished prune a build error rather than a silent ship. A content id is matched as a WHOLE WORD, so an item called `pear` does not collide with the word `appeared`; a whole-word hit is a real one, and it is a bug in the *engine* rather than in your content |
| `check_budgets` | 250 code lines per file, 40 per function. Markdown is not counted |
| `check_strings` | a player-facing literal reaching `.text` without `tr()`, and a `*_KEY` const naming a CSV row that does not exist |
| `check_layers` | a dependency pointing the wrong way through `core -> content -> systems -> gameplay -> ui`. You will not trip this authoring content; you will the moment you add a script |
| `check_signals` | a signal declared in `events.gd` that nothing emits. Say `NO EMITTER` in its `##` block if that is deliberate — and it then fails if one ever appears |
| `check_methods` | a public method under `src/` that nothing calls. The exemption is the phrase `NO CALLER` in its own `##` block, with a reason beside it |
| windowed capture | everything the other ten cannot see |

### Nothing above ever enters your area, and that surprises everyone once

**A plain run stops at the main menu.** `--headless --quit-after 30` boots, reports
`0 warnings, 0 errors` and never loads an area, so it cannot tell you that your `area_id` is
wrong, that your navmesh baked empty, or that your NPC has no schedule. Neither can a `--shot`
on its own: the PNG is the title screen.

**`--new-game` is what starts a game**, and it is one of a set of debug flags the development
harness answers. They are behind `OS.is_debug_build()`, so they do not exist in a shipped build.

| Flag | Does |
|---|---|
| `--new-game` | starts a game — enters `[game] world/first_area` |
| `--goto=<area_id>` | travels to an area, so you can capture one that is not the first |
| `--shot=<abs path>` and `--shot-frame=<n>` | capture a PNG, at that frame. The area load is threaded and needs frames — 70 with `--quit-after 90` is a safe pair |
| `--time=HH:MM` and `--freeze-time` | a reproducible hour. Without the freeze, weather and the clock keep rolling and no two captures match |
| `--stand-by=<node name>` | put the player beside a node, by its **node name** — not its `object_id`. Asking for `warden_talk` fails; ask for `Warden`. It waits for a SETTLED area, so with `--goto` it lands late: give `--interact` about 260 and `--quit-after` about 340 |
| `--equip=<item id>[,<id>]` | put carried items **in hand**, after the area lands. `--give` first, on the same line — an item nobody carries is refused |
| `--flag=<key>:<value>` | forge a plot flag **after** the area lands, so quest progress can be posed: `--flag=met/warden:true`, `--flag=count/lit:3`. `--new-game` clears flags first, which is why it cannot be earlier |
| `--interact=<frame>`, `--cycle=<n>`, `--talk-advance=<frame>` | press the interact key, Tab between overlapping targets, advance a conversation |
| `--give=<item id>[:count]` | put items in the bag **after** the area lands, so a counted quest step can be posed: `--give=item/rose_petal:2`. `--new-game` empties the bag first, the same reason it cannot be earlier |
| `--standing=<who>:<n>`, `--weather=<kind>` | pose the world before the shutter |

**Capture your first version of an area at midday.** A new area has no props and no lanterns, and
the shipped dusk hour renders it very nearly black — which looks exactly like a lighting bug and
is not one.

**`--headless` shades nothing.** It uses a dummy rasteriser, so a visual claim — an area is lit, a
sprite is drawn from the right cell, a menu is legible — needs the windowed capture, and needs you
to *look at the PNG*. A day/night system once ran, logged correct times, reported no errors and lit
nothing at all, because one `@export` was unwired.

**And `0 warnings, 0 errors` does not mean the scripts compiled.** That line counts the game's own
`Log.warn` / `Log.error` calls; an engine-level `Parse Error` is neither. The import rung is the
compile check — grep its output for `SCRIPT ERROR` and `Parse Error` and require zero.

## Make something you can hit (combat fork only)

**The combat core in one object.** `scenes/objects/strike_target.tscn` is an interactable with a
`Vitals` and a `Combatant` child. Interacting resolves one hit through the combat core and toasts
the result. The courtyard's training dummy is an instance of it. Its fields are:

- on the root (`StrikeTarget`):
  - `label_key`;
  - `power`, and `element` if any;
  - `struck_key` and an optional `critical_key`, each filled with `{amount}`, `{left}` and
    `{max}`;
  - `revive_when_defeated`, so that a dummy stands back up.
- on the `Combatant` child:
  - a unique `combatant_id`, which namespaces the `vital/<id>/hp` flag;
  - a `faction`;
  - `base_stats`, for example `max_hp`, `defence` and `crit_chance`.

  Override it with an `[editable path=...]` line, the same as an NPC (§ The editable trap).

**Whoever interacts hits.** If they have a `Combatant`, its sheet and formula resolve the hit.
The template's player has none, so `power` alone decides, through the target's own formula. A
target with no `Combatant` child is not offered at all. The formulas themselves, turn-based,
action and hybrid, are phases C2 to C4 in [`COMBAT.md`](COMBAT.md).

**Seeing it:** walk to the dummy and press Interact. The toast reads, for example, "Thwack. 7
damage, 23 of 30 left."

## Add an encounter and a party (combat fork only)

**A turn-based fight is data and one placed object.** The courtyard's thorn thicket is the worked
example: `data/encounters/thorn_wisps.tres`, the roster `data/party/roster.tres`, the skill
`data/skills/ember.tres`, and a `WispNest` instance of `scenes/objects/encounter_point.tscn`.

1. **Skills**: `data/skills/<name>.tres`, a `Skill` with id `skill/<name>`. It holds:
   - a `name_key`;
   - a `cost_pool` and `cost`;
   - a `target` (SELF, ALLY, ENEMY or ANY) and a `scope` (ONE or ALL);
   - `power`, where a negative power heals;
   - an `element`;
   - `statuses` with a `status_chance`.
2. **The party**: one `PartyRoster` file, named in `project.godot` by `[combat] party/roster`.
   Each member is a `CombatantDef` with:
   - a unique `combatant_id`, a `name_key`, a `faction` and `base_stats` (at least `max_hp`;
     `speed` orders turns);
   - `commands` (empty means Attack, Defend, Flee);
   - a `level_curve` to grow.

   Everyone is active until something calls `Party.arrange`.
3. **The encounter**: `data/encounters/<name>.tres`, an `Encounter` with id `encounter/<name>`.
   - Its `enemies` are `CombatantDef`s. List one twice for two of it; they become "Name 1" and
     "Name 2".
   - Give each enemy a `brain` (weighted `BrainEntry`s with a target rule and optional
     conditions), or leave it null to just attack.
   - Set `turn_order` (ROUNDS or CTB), `can_flee`, `experience` and `loot` (item ids).
   - Optionally set `music`, an audio stream: it plays while the fight is open, and the area's
     own music returns afterwards. Left empty, the field's music keeps playing.
4. **The trigger**: place `encounter_point.tscn` under `Interactables`. Set its `object_id`, its
   `label_key`, and its `encounter_id`. A game's own trigger, such as a zone, a cutscene or a
   random roll, emits `Events.encounter_requested(id)` instead.
5. **Strings**:
   - fighter and skill names live under `combat.`;
   - the point's label lives under `object.<object_id>.`.

   `NEW_GAME.md`'s prune removes `object.` rows but not `combat.` ones, so a game strips those by
   hand.

**Seeing it:** walk to the thicket and press Interact. The field freezes under the battle menu.
Win, and the screen lists the experience, each level gained and the loot; Continue returns to the
field exactly where it was. `skill_test.gd` and `encounter_test.gd` fail on any authoring problem
in `data/skills/`, `data/statuses/` or `data/encounters/`.

## Skills, statuses and combat depth (combat fork only)

**Everything below is data.** The demo party in `data/party/roster.tres` uses every piece of it,
and a game copies from there. Each file's own `##` header says the same thing at more length.

**A skill** (`data/skills/<name>.tres`, a `Skill`, id `skill/<name>`), beyond the fields in the
section above:

| Field | What it does |
|---|---|
| `hits` | The strike lands this many times on each target, for a flurry. Statuses still roll once per target. |
| `effects` | A list of `SkillEffect`s run on every hit: DAMAGE, HEAL, RESTORE (any pool, such as `mp`), DRAIN (`fraction` of the damage back to the user), CURE (one `status_id`), DISPEL (every status with `tag`, such as `debuff` or `ailment`) and REVIVE (`amount` is the fraction of max hp; the skill then aims only at the fallen). |
| `tags` | Free labels. `magic` is what a reflect bounces by default; a tag can also be a weakness, such as `blade`. |
| `sure_hit` | It cannot miss. |
| `toggle_status` | Makes it a **stance**: using it puts this status on the user, and using it again takes it off. On costs; off is free. A stance has no power, effects or statuses of its own. |
| `boost_power`, `boost_hits` | Per Boost level spent: the skill's power grows by this fraction, and it lands this many more times. |

**A status** (`data/statuses/<name>.tres`, a `StatusEffect`, id `status/<name>`):

| Field | What it does |
|---|---|
| `name_key` | Its name in the battle readout and log. |
| `unit`, `duration` | Turns or seconds. A duration of 0 or less lasts until cured. |
| `stacking`, `max_stacks` | REFRESH, STACK (adds its modifiers again) or IGNORE. |
| `modifiers` | Stat changes while held: a buff (`defence` +30) or a debuff (`attack` ×0.6). |
| `tick_pool`, `tick_change` | Poison or regen: a pool change each turn, or each `tick_interval` seconds. |
| `tags` | `buff`, `debuff`, `ailment` or your own. A DISPEL clears by tag, and a fighter's `resist_<tag>` stat resists by tag (1 is immune). |
| `blocks` | SKIP_TURN (sleep, stun), NO_SKILLS (silence), NO_ITEMS, NO_FLEE. ATTACK and DEFEND are never blocked. |
| `breaks_on_hit` | Ends at the first hit that does damage, as a sleep does. |
| `reactions`, `reaction_chance`, `reflect_tag` | COUNTER strikes back at a plain attack that landed; REFLECT bounces a skill with `reflect_tag` back to its user. |

**A fighter** (`CombatantDef`) gets its depth from stats and three lists:
- **Pools** are any `max_<pool>` stat: `max_mp`, `max_bp`, `max_limit`, `max_shield`. Each starts
  full, unless `start_<pool>` gives a fraction: a limit gauge has `start_limit` 0.
- **Meters:** `regen_<pool>` refills a pool each turn, and a negative value drains it.
  `fill_on_hit_<pool>` fills a pool by that fraction of damage taken.
- **Accuracy and evasion:** the `accuracy` and `evasion` stats. With neither, nothing ever misses.
- **Weakness and Break:** `weak_to` lists elements or skill tags. Each landed hit on one takes a
  `shield` point, and the last one breaks the fighter: it loses a turn and takes +50% damage.
  `attack_tags` is what its plain attack counts as. Give it `max_shield`, or nothing breaks.
- **Boost:** any fighter with `max_bp` gets a Boost row; `regen_bp` 1 is Octopath's rule.
- **Menus:** a command's `category` (a localization key) files it under a submenu, such as
  Magic or Special. Commands without one stay on the first menu.

**Seeing it:** fight the courtyard thicket. The Wanderer has Magic (Ember, Lull, Blight), Special
(Skyfall, which needs a full limit gauge), the Keen Edge stance and Boost. The Keeper has Salve,
Cleanse, Rekindle and Bulwark. The wisps are weak to fire and to blades, one may sing the party
to sleep, and two Embers break a wisp. `combat_content_test.gd` fails on a missing string or an
unsound skill or status.

## Action combat: fighting in real time in the field (combat fork only)

**The player swings, rolls and locks on in the field itself, with no battle screen.** It is
switched on by one project setting and filled in by three kinds of data file. The worked example
is the lantern hall: the loadout `data/action/wanderer_loadout.tres`, and two Ember Moths
(`data/action/ember_moth.tres` with the brain `data/action/ember_moth_brain.tres`) placed under the
hall's `Actors`.

**Controls:** attack is K (pad X), dodge is Space (pad right trigger), lock on is Q (pad left
trigger), the next target is R (pad R3), and the hybrid's command menu is F (the pad's extra
centre button, `MISC1`; it opens only for a loadout with `atb` rules and `commands`).
`combat_actions.gd` installs them at boot. They cannot be rebound
in the menu yet: that waits for C5.3.

1. **The player's loadout:** an `ActionLoadout` file, named in `project.godot` by
   `[combat] action/loadout`. Leave the setting empty and the game has no field combat; a path to
   a file that is gone is treated the same way, quietly. The loadout holds:
   - `fighter`: a `CombatantDef`, exactly as for the turn-based party (`combatant_id`, `name_key`,
     `faction` player, `base_stats`, `attack_tags`, a `level_curve`);
   - `moves`: a `MoveSet`, with the `attack_chain` (one `ActionMove` per press, in order) and a
     `dodge`. Its `skills` slots are data only for now: the hybrid's menu uses the loadout's own
     `commands` instead (next section);
   - `defeat_rule`: what the player's fall means, after `delay` seconds on the ground.
     RESPAWN_AT_ENTRY (the default) gets up with `revive_fraction` of max hp at the area's
     entrance, with every enemy back; REVIVE_IN_PLACE gets up where they fell; RELOAD_SAVE loads
     the last save, or respawns at the entry when there is none.
2. **A move** (`ActionMove`) is timing, a hit, and a shape:

   | Field | What it does |
   |---|---|
   | `startup`, `active`, `recovery` | Seconds before the hit, while the hitbox is live, and after it. |
   | `chain_after` | Seconds into recovery after which the next attack press continues the chain. A press before that is buffered for `MoveTimeline.buffer_window`. Must not exceed `recovery`. |
   | `iframes_from`, `iframes_to` | Seconds from the start of the move during which the mover cannot be hit. A dodge needs some, or `MoveSet.problems()` complains. |
   | `power`, `element`, `hits` | The hit, through the same damage formula as turn-based combat. |
   | `poise` | Shield points it takes from a fighter with `max_shield`, whether or not the hit matches a weakness. Breaking works as in turn-based combat. |
   | `knockback` | How far a hit pushes its target back. |
   | `skill` | Optional: the hit resolves as this `Skill` through the shared skill path, so a spell can be cast in real time. |
   | `hitbox_size`, `hitbox_offset` | The box the hit fills, in metres, relative to the mover's facing (`-z` is in front). Make it generous: the placeholder sprites are thin. |
   | `travel_speed` | Metres per second the mover slides forward while the move runs. A roll is a move with travel and i-frames and no power. |
3. **An enemy:** place `scenes/objects/action_enemy.tscn` under the area's `Actors`, then set on
   the instance:
   - `fighter`: its `CombatantDef` (faction enemy, the default);
   - `brain`: an `ActionBrain`;
   - `experience` and `loot` (item ids), granted the moment it falls;
   - `remember_defeat`: true for a one-off foe that stays gone; false, the default, means it is
     back whenever the area is entered again.

   Two instances sharing one definition are told apart by node name: their ids become
   `<combatant_id>/<node name>`.
4. **The brain** (`ActionBrain`) decides when to wander, chase, attack, retreat and go home:

   | Field | What it does |
   |---|---|
   | `aggro_radius` | It notices a hostile this close. |
   | `give_up_radius` | It stops chasing past this. Must be at least `aggro_radius`. |
   | `leash_radius` | It walks home when this far from where it was placed. |
   | `attack_range`, `attack_cooldown` | How close it must be to attack, and the seconds between attacks. |
   | `move_speed`, `wander_radius`, `wander_every` | How it walks, and how far and how often it idles about. |
   | `retreat_below`, `retreat_distance` | Below this fraction of hp it backs off this far. |
   | `moves` | Weighted `ActionBrainEntry`s: a `move`, a `weight`, an optional `reach` and `min_reach` (the target's distance must fit), and `only_below` (an hp fraction, for a desperation move). |
5. **Pressure and stagger (C4.6).** A fighter in the field counts in seconds, so a break there
   is an FF7-Remake-style stagger, not the turn-based BROKEN:
   - a hit on one of its `weak_to` keys **pressures** it: `status/pressured`, 3 seconds of
     taking double poise (its `poise_taken` stat goes up by 1);
   - the hit that empties its `shield` **staggers** it: `status/staggered`, 4 seconds standing
     still (SKIP_TURN, which the field honours for SECONDS statuses) and taking 60% more damage
     (`damage_taken` +0.6). When it wears off the shield refills.

   To change either, build your own `StatusEffect` and set `Weakness.pressured` or
   `Weakness.staggered` once at boot (and `Weakness.broken` for the turn-based break). Any
   status may give `poise_taken`: +1 doubles the poise a fighter takes, -0.5 halves it. The HUD's
   target line lists the target's statuses, so "Pressured" and "Staggered" show there
   (`ui.combat_status.*` strings).
6. **Strings:** the fighter's `name_key` is shown by the field HUD's target line, under
   `combat.`. `NEW_GAME.md`'s prune leaves `combat.` rows, so a game strips those by hand.

**Seeing it:** walk from the courtyard into the lantern hall. Two moths wander near the south
wall; walk towards them and they come for you. Lock on, attack three times for the full chain,
and roll through a lunge. The HUD at the bottom left shows your hp and the locked moth's. Each
moth is weak to your blade: the first hits pressure it, and when its three shield points are
gone it is staggered, stock-still for four seconds. Each moth falls after three or four hits and gives 12 experience; the first drops a stone chip.
`combat_content_test.gd` fails on a missing name string or an unsound loadout, fighter or brain
under `data/action/`.

## The hybrid: ATB and field commands (combat fork only)

**FF7 Remake's pattern, built from the action formula's parts.** The player fights in real time.
A gauge of ATB bars fills as they do, and F (pad `MISC1`) opens a command menu over the running
fight, slowed almost to a stop. A spell or an item costs whole bars. The worked example is the
same loadout as above, `data/action/wanderer_loadout.tres`: two bars, Ember under Magic, Salve on
the first menu.

1. **The gauge:** set the loadout's `atb` to an `AtbRules`. Leave it empty and the fighter has no
   gauge and no menu: a pure action game.

   | Field | Default | What it does |
   |---|---|---|
   | `segments` | 2 | How many bars. |
   | `segment_size` | 100 | Points in one bar. |
   | `per_second` | 4 | Points gained every second of fight time, doing nothing. |
   | `on_hit_dealt` | 12 | Points for each hit the fighter lands. |
   | `on_dodge` | 10 | Points for each attack the fighter rolls through. |

   Spending removes whole bars and keeps the part-filled one. The fill follows the fight's own
   clock, so it slows with the menu open and stops at 0.
2. **The menu:** the loadout's `commands`, a list of `BattleCommand`s exactly like a party
   member's in a turn-based battle, but only SKILL and ITEM: attack is a button and the field
   cannot flee, so `combat_content_test.gd` reports any other kind. A command's `category` (such
   as `combat.category.magic`) files it under a submenu; empty puts it on the first menu. An ITEM
   command also spends one `item_id` from the player's inventory.
3. **The price:** each `Skill` has `atb_cost`, the bars one field use costs (default 1, ignored in
   turn-based battles). Its `cost` and `cost_pool` (mp) are paid too. A row the player cannot use
   is greyed out with the reason: not enough ATB, not enough mp, no item, no target, or a status
   that forbids it.
4. **Targets:** a one-target attack goes to the locked-on foe, else the nearest within 8 m; an
   all-targets one to every foe within 8 m; a heal or a buff to the player.
5. **The slow:** `[combat] hybrid/slow` in `project.godot` is how fast the fight runs while the
   menu is open. 0.1 is the default; 0 is a true wait mode; 1 does not slow at all.

**Seeing it:** in the lantern hall, fight the moths until the HUD's `ATB` reads `1 / 2` or more,
then press F. The fight crawls. Choose Magic, then Ember: both moths burn, 3 mp and one bar are
spent, and the fight runs at full speed again. Salve heals you the same way.

### A party in the field (C4.7)

1. **Who comes along:** list each member's own `ActionLoadout` in the lead loadout's
   `companions`. Each is a whole loadout (fighter, moves, `atb`, `commands`), because the player
   can take control of it. Once `Party.arrange` has set a line-up, only the active members come;
   before that, all of them.
2. **Following:** each member is a `PartyFollower` (`scenes/objects/party_follower.tscn`, which
   you may restyle) that walks `spacing` metres behind the leader for each place in the line, at
   `speed`, and is set down on the leader's feet when more than `catch_up` metres away. It can be
   hit. It swings at foes only with a field brain (step 6).
3. **Switching:** C (pad `PADDLE1`) hands the player's body to the next standing member. Their
   hp, statuses, gauge, moves and commands come with them, the two swap places, and the one
   handed over goes to the back of the line. A fallen member is passed over, and the key does
   nothing mid-swing or while a menu is open.
4. **Rewards:** a field kill gives its experience to every standing member.
5. **Thinking (C4.8):** give a member's `fighter` (its `CombatantDef`) a `brain`, the same
   `BattleBrain` a turn-based battle reads. While a foe stands within 8 m, the follower draws
   from it every `think_every` seconds (1, on the prefab) of fight time. Only SKILL and ITEM
   entries count in the field, and only those it can pay for now in ATB bars (`Skill.atb_cost`)
   and mp. Aim with the entry's `target_rule`: LOWEST_HP on an ALLY skill heals the most hurt
   member, FIRST on an ENEMY skill casts at the nearest foe, and an ALL skill takes everyone in
   reach. `below_fraction` tests the follower's own pool, as in battle. With no brain it only
   walks. The member you control never thinks; its brain waits until you switch away.
6. **Fighting (C4.9):** give a member's loadout a `field_brain`, the same `ActionBrain` a
   real-time enemy uses (every field is in § Action combat). While it follows:
   - a foe within `aggro_radius` is chased, and let go beyond `give_up_radius`;
   - in reach it attacks with a move drawn from `moves` by weight. **List the member's
     `attack_chain[0]` as a move and it plays the whole chain**, swing after swing; any other
     move (a lunge) plays alone. Then it waits `attack_cooldown`;
   - `leash_radius` is measured from its PLACE IN THE LINE, not from where it started: strayed
     further, it gives up and walks back to the leader;
   - `retreat_below` makes it back away when hurt; `wander_*` is ignored, it keeps its place.
   It strikes through its own hitbox, as whoever the member is now. A knockback pushes it
   (`stun_time` on the prefab, 0.25 s). No field brain: it never swings, as before.

**Seeing it:** the Keeper (`data/action/keeper_loadout.tres`) follows the Wanderer into the
lantern hall. Press C and you are the Keeper, with a staff, Salve and Bulwark on F; press it
again to take the Wanderer back.

### The whole hybrid in one room (C4.11)

The lantern hall is the worked example of every part above at once.
- **The Keeper** has both brains. Its `fighter.brain` lists Salve (LOWEST_HP, weight 4,
  `below_fraction` 0.6: once the Keeper is under 60% hp it heals whoever is most hurt) and
  Bulwark (weight 1). Its `field_brain` lists `staff_one`, the first of its chain, so it plays
  both swings, and leashes it 7 m from its place in the line.
- **The Lantern Warden** (`data/action/lantern_warden.tres`, brain
  `lantern_warden_brain.tres`) is a foe built for the loop: 90 hp, `max_shield` 4, `weak_to`
  fire, and a slow, heavy slam. Ember (fire) hits it on its weakness: one shield point and
  PRESSURED for 3 s, during which every blow wears double poise. At 0 shield it is STAGGERED for
  4 s, taking more damage and standing still; then its shield refills.
- **Play it:** fight the moths until `ATB` reads `1 / 2`, lock onto the Warden (Q), press F and
  cast Ember, then close in with the chain while the Keeper swings beside you. The HUD's target
  line shows `[Pressured]`, then `[Staggered]`.
- **An open floor edge** lets a knockback push a body off the world. The hall has `EdgeSouth`, a
  collision-only wall on its open side; give your own arenas walls or edges on every side until
  C5.8's safety net lands.

### Variants with no new system (C4.10)

Three well-known styles come from parts that already exist.
- **An ATB battle** (the classic Final Fantasy gauge): an encounter with `turn_order` CTB, whose
  `CtbScheduler` is fed with time instead of jumping turn to turn. Each frame, call
  `advance(CombatClock.scaled(delta) * ticks_per_second)` on the battle's scheduler; when it names
  someone, call `Battle.next_turn()`. Holding `CombatClock` at 0 while a menu is open is "wait"
  mode. Speeds and the scheduler's `delay` set how long each gauge takes. The battle screen still
  runs plain CTB; a screen that feeds time is a game's choice.
- **Pause-and-play:** set `[combat] hybrid/slow` to 0. The command menu then stops the fight while
  it is open, and the chosen command lands the moment it is picked.
- **Timed hits:** a `TimedWindow` resource. `opens` and `closes` are seconds after the move starts;
  a press between them multiplies the power by `bonus` (1.5). `perfect` (seconds, 0 for none) is a
  tighter centre worth `perfect_bonus` (2.0). Call `multiplier(pressed_at)` and multiply the hit's
  power by it; `problems()` flags a window that closes before it opens, a negative bonus, or a
  centre wider than the window.

## Mixing formulas (C5.1, combat fork only)

**Which formula a fight uses is decided by what the area places.** There is no mode setting.

| Place this | The fight is |
|---|---|
| an `ActionEnemy` (`scenes/objects/action_enemy.tscn`) | real time; the hybrid when the player's loadout has `atb` |
| an `ActionEnemy` with a `SymbolEncounter` child | turn-based, opened when the foe touches or is struck by the party |
| an `EncounterPoint` (`scenes/objects/encounter_point.tscn`) | turn-based, opened when the player talks to it |

One area can hold all three, and a boss can be turn-based in a field that is fought in real time.

**A symbol encounter**, step by step:
1. Place an `ActionEnemy` and give it a `fighter` (the body you see and can lock onto) and a
   `brain`. For a foe that never swings, leave the brain's `moves` empty and set
   `chase_only`: it notices, chases and wanders, nothing more.
2. Set its `experience` to 0 and its `loot` empty. The encounter pays the rewards, and the field
   body would pay them twice.
3. Add a `Node` child with the script `src/gameplay/combat/symbol_encounter.gd`. Because the
   enemy is an instanced scene, mark it editable (in the editor, or an `[editable path=...]`
   line in the `.tscn`); `check_content.gd` fails without it.

   | Field | Default | What it does |
   |---|---|---|
   | `encounter_id` | (none) | The `Encounter` it opens, `encounter/<name>` |
   | `touch_radius` | 1.2 | How close, in metres, a party member must come |
   | `grace` | 3.0 | Seconds of fight time it leaves the party alone after a flee, a loss, or a request no battle answered |

4. **What happens:**
   - a touch, or a party strike landing on it (a follower's too), opens the battle once;
   - **a win** drops the field body to 0 hp: it falls, lingers and is removed, and stays gone
     if `remember_defeat`;
   - **a flee or a loss** leaves it standing, quiet for `grace`;
   - a strike that fells it outright ends it in the field, with no battle, so give the body more
     hp than one blow.

**Seeing it:** in the courtyard, a thorn wisp wanders east of the wisp nest
(`data/action/thorn_wisp_symbol.tres`, brain `symbol_brain.tres`). Walk into it, or let the
Keeper strike it, and the Thorn Wisps battle opens. The nest beside it opens the same battle when
you talk to it.

## Saves around combat (C5.2, combat fork only)

**What a save keeps:** every pool (`Vitals` stores hp, mp, shield and the rest in `Flags` as
`vital/<who>/<pool>`), each fighter's statuses with their turns or seconds left (`StatusSet`'s
section, `statuses/<id>`; the player's is `statuses/player`), which `remember_defeat` foes were
beaten, and which weaknesses were revealed.

**What a load resets:** field enemies (an area is rebuilt fresh, as on re-entry, so their hp and
their AI start over), every ATB gauge, and the fight clock.

**When a save is refused.** `CombatSaveGuard`, a node under GameRoot, tells upstream's
`SaveSystem.blockers` "not now" at two moments:

| Moment | Reason shown | Why |
|---|---|---|
| a turn-based battle is open | `ui.combat_save.in_battle` | the party's mid-fight hp and battle-only statuses would be kept |
| the player lies defeated | `ui.combat_save.fallen` | a load fires no defeat edge, so they would never get up |

The save screen shows "Can't save now: <reason>"; the autosave skips and tries again at the next
area entry. Loading is never refused.

**Adding your own moment** (a cutscene, a boss door) is one line in any node:

```gdscript
SaveSystem.blockers.add(&"boss_door", func() -> String:
	return "ui.my_game.sealed" if _sealed else "")   # "" means saving is fine
```

Remove it in `_exit_tree` with `SaveSystem.blockers.remove(&"boss_door")`. A blocker whose owner
is freed is dropped on its own.

**A fallen player always gets up on an area entry**, unless they are still lying out their
`DefeatRule.delay`. That is how a reload ends the wait, and it rescues a save written at 0 hp by
an older build.

## Read next

[`ART_CONTRACT.md`](ART_CONTRACT.md) — what art has to satisfy to drop in ·
[`TESTING.md`](TESTING.md) — adding assertions to a template you did not write ·
[`ARCHITECTURE.md`](ARCHITECTURE.md#the-extension-surface) — what you may subclass and what is the
engine's own business ·
[`NEW_GAME.md`](NEW_GAME.md) · [`TEMPLATE.md`](TEMPLATE.md)
