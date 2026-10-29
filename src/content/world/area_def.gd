class_name AreaDef
extends ContentEntry
## Where one area sits on the world map, and how a traveller arrives there.
##
## THE ID IS THE FILE NAME, AND IT IS THE AREA ID. `data/areas/orchard.tres` must declare
## `id = &"orchard"`, and that is the same id `scenes/areas/orchard/orchard.tscn` declares and
## the same one `Director` travels to. There is deliberately NO prefix, unlike `item/` and
## `quest/`: those prefixes exist so a save file is self-describing about a thing that lives
## only in a save file, and an area id is already a public identifier — a folder name. A
## `map/orchard` id would have meant a translation table between this registry and `Director`,
## and a translation table is a second place the truth lives.
##
## WHY AN AREA NEEDS A SECOND RESOURCE AT ALL, when `AreaRoot` already declares an id and a
## name key. Because `AreaRoot` lives INSIDE the area scene, and a world map has to draw an area
## the player has never been to — which means loading it, which means loading its terrain, its
## navmesh and its NPCs to find out where a dot goes. This is the thin, cheap half: a game can
## scan every one of these at boot without instantiating anything. The two agreeing is checked
## by the suite rather than assumed.
##
## THE POSITION IS AUTHORED DATA, AND THAT IS THE WHOLE REASON THIS FILE EXISTS. `MapScreen`
## draws a dot at `map_position` and has never heard of any area. A map that knew where the
## courtyard goes would be engine code naming demo content, which `tools/check_boundary.gd`
## fails the build over — see `docs/TEMPLATE.md`.
##
## OWNS: the immutable map data of one area, and validating its own fields.
## MUST NOT: read a flag, load a scene, decide whether the area is discovered, or touch an
## autoload — `tools/check_content.gd` loads this class under `--script`, where autoload
## identifiers do not resolve, so one `Log` call would break a build gate.

## `id` is inherited from `ContentEntry`; for this catalogue it is this file name with NO prefix.
## Localization key for the name drawn on the map. Never raw text. Should match the area
## scene's own `display_name_key`; `tests/unit/world_map_test.gd` asserts that it does.
@export var name_key: String = ""
## Where the dot goes, in NORMALISED map space: (0,0) is the top-left of the map plate and
## (1,1) the bottom-right. Normalised rather than in pixels so the same authored number is
## right at every window size and every UI scale, and so a game may redraw the plate at any
## resolution without touching a single .tres.
@export var map_position: Vector2 = Vector2(0.5, 0.5)
## Which spawn marker a fast traveller lands on. Empty means the destination's first spawn,
## exactly as an `AreaDoor` with no `target_spawn` means it.
@export var arrival_spawn: StringName = &""
## On the map before the player has been anywhere. True for the place a game begins, and for
## anywhere a game wants known by reputation. Everything else is discovered by arriving, or by
## anything at all that writes the discovery flag — see `src/systems/world_map/world_map.gd`.
@export var known_from_start: bool = false


## Everything wrong with this area, as data rather than a log line, so the same check serves the
## game, the test suite and the headless validator.
##
## IT DOES NOT CHECK THAT A SCENE EXISTS, and the omission is deliberate. The area id becomes a
## file path through `Director.AREA_PATH_TEMPLATE`, which is the one place in the project that
## knows that shape; reconstructing it here would be a second copy of it, and a second copy is
## how two answers to one question begin. `tests/unit/world_map_test.gd` asserts the scene
## exists, THROUGH `Director.area_path`, because the suite is the one rung where that autoload
## resolves.
func problems() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if id == &"":
		found.append("%s has no id" % resource_path)
	if name_key == "":
		found.append("%s (%s) has no name_key" % [resource_path, id])
	if map_position.x < 0.0 or map_position.x > 1.0 or map_position.y < 0.0 or map_position.y > 1.0:
		found.append("%s sits at %s, which is outside the 0..1 map plate" % [id, map_position])
	return found
