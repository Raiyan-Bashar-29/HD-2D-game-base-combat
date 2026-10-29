class_name GameConfig
extends RefCounted
## The handful of values a CONSUMING GAME sets, and the only place under `src/` that reads them.
##
## WHY THIS EXISTS
## `docs/TEMPLATE.md` states the boundary rule: no file under `src/` may name demo content. But
## some engine code genuinely needs to know a game-specific answer — which area a new game starts
## in, what the game is called. Before this file, `Director` answered the first with
## `const FIRST_AREA := &"courtyard"` and `Log` answered the second with the literal `Gulistan`,
## both in code that is supposed to outlive every game built on it.
##
## The answer is not to delete the question but to move where it is asked. `project.godot` is
## already the one file a new game must edit — name, description, version, icon — so it is the
## natural home for "which area do I start in" too, and `tools/check_content.gd` deliberately
## does not scan it. An `@export` on `scenes/boot/game_root.tscn` was the alternative and was
## rejected: `TEMPLATE.md` classifies `scenes/boot/` as engine, so that would have moved the leak
## rather than closed it.
##
## THE PLAYER SCENE JOINED THIS FILE AT T5.29, AND ADR-0007 IS WHY.
## `game_root.gd` held `const PLAYER_SCENE := "res://scenes/characters/player.tscn"` — engine
## code, in the `core` layer, naming the prefab a game replaces first. It looked like a template
## DEFAULT and it was a template RULE: there was no seam, so a game whose protagonist has a
## different shape had to edit `src/`, which `ARCHITECTURE.md` forbids in as many words. The
## distinction and the test that catches it are ADR-0007's; this is the first thing that test
## found.
##
## OWNS: reading the `[game]` section of project.godot, and the fallbacks when it is absent.
## MUST NOT: cache, validate against content, or grow into a settings store. `Settings` owns
## player preferences; this owns the five facts a game author writes once and never changes.

## The area a new game begins in. Empty is a real answer — a template with no game in it yet —
## and `Director` reports it rather than loading nothing and going quiet.
const FIRST_AREA_SETTING: String = "game/world/first_area"
## The spawn marker within that area. `default` is a template convention, not demo content:
## every area is expected to have one, which is why it has a fallback and the area does not.
const FIRST_SPAWN_SETTING: String = "game/world/first_spawn"
const DEFAULT_FIRST_SPAWN: StringName = &"default"
## The player prefab `GameRoot` spawns once per session. **It has a fallback where the first area
## has none**, and the asymmetry is deliberate: a template with no game in it yet legitimately
## starts in no area, but it can never legitimately have no player, so an unset key means the
## template's own prefab rather than an empty world. `scenes/characters/` is Engine per
## `TEMPLATE.md`, so naming that path here is engine naming engine — not the boundary leak the
## `const` in `game_root.gd` was.
const PLAYER_SCENE_SETTING: String = "game/world/player_scene"
const DEFAULT_PLAYER_SCENE: String = "res://scenes/characters/player.tscn"
## Everything outside this becomes an underscore when the name is used in a file name.
const SLUG_ALPHABET: String = "abcdefghijklmnopqrstuvwxyz0123456789"


static func first_area() -> StringName:
	return _string_name(FIRST_AREA_SETTING, &"")


static func first_spawn() -> StringName:
	return _string_name(FIRST_SPAWN_SETTING, DEFAULT_FIRST_SPAWN)


## Deliberately NOT validated here — this file's MUST NOT line forbids it, and `GameRoot` already
## reports a scene that will not load, by path, on the one code path that could care.
static func player_scene() -> String:
	var raw: Variant = ProjectSettings.get_setting(PLAYER_SCENE_SETTING, "")
	var value: String = str(raw)
	return value if value != "" else DEFAULT_PLAYER_SCENE


## The game's display name, for a banner or a window title. Falls back to the engine's own
## default rather than to a literal, so an unnamed project says so instead of lying.
static func game_name() -> String:
	var raw: Variant = ProjectSettings.get_setting("application/config/name", "")
	var value: String = str(raw)
	return value if value != "" else "Unnamed Game"


## The same name reduced to something safe in a filename: lower case, and every run of
## characters that is not a letter or a digit collapsed to one underscore.
static func game_slug() -> String:
	var slug: String = ""
	for character: String in game_name().to_lower():
		if SLUG_ALPHABET.contains(character):
			slug += character
		elif not slug.ends_with("_"):
			slug += "_"
	return slug.trim_suffix("_").trim_prefix("_")


## ProjectSettings hands back a Variant, and `str()` is the only conversion that is safe on one
## whatever the author typed into project.godot.
static func _string_name(key: String, fallback: StringName) -> StringName:
	var raw: Variant = ProjectSettings.get_setting(key, "")
	var value: String = str(raw)
	return StringName(value) if value != "" else fallback
