class_name ShadowAtlas
extends RefCounted
## The shadow atlas, and what the PROJECT authored into it.
##
## WHY THIS IS A FILE AND NOT TWO CONSTS. `Settings._apply_shadows` turns every light in the
## world off by sizing the atlas to zero, which is the seam that makes `video/shadows` free for
## a game that adds a hundred lights. Turning them back ON is the half that was wrong: it wrote
## a `2048` const described as "the engine's own defaults", and the engine's default is 4096.
## So the first time a player in THIS repository toggled shadows, the atlas was halved and never
## restored — not a hypothetical fork's problem, a measured one. A const cannot be right here at
## all, because the number is a project setting a consuming game is invited to change.
##
## THE PATTERN IS `HD2DCameraRig._authored_dof`, ONE LAYER DOWN. Read what the project authored
## before the player's preference is folded in, and restore to THAT. The rig remembers a bool an
## area author exported; this remembers two integers a game author set in `project.godot`. Same
## shape, same reason: a preference is a VETO over what the author chose, never a replacement
## for it.
##
## WHY IT IS NOT IN `settings.gd`. That file is at its 150-line budget, and the budget is the
## point rather than the obstacle — remembering an authored value needs state, and state on the
## settings autoload is state every future setting will be tempted to add beside it. One object
## that owns one property of the renderer is the smaller thing.
##
## OWNS: the two shadow map sizes, and remembering what they were before anything touched them.
## MUST NOT: read a setting, know that `video/shadows` exists, or touch a light. It is handed a
## viewport and a bool. Who decided the bool is `Settings`'s business.

## Where a game authors the directional size. The positional one is read off the viewport itself,
## which the engine has already populated from `rendering/lights_and_shadows/positional_shadow/
## atlas_size` by the time anything can ask.
const DIRECTIONAL_SETTING: String = "rendering/lights_and_shadows/directional_shadow/size"
## Used only if the project setting is missing or is not a number. It is the engine's real
## default, unlike the 2048 this file replaced.
const FALLBACK_SIZE: int = 4096

## Negative until the first apply, so a project that genuinely authored 0 is still remembered.
var _positional: int = -1
var _directional: int = -1


## Size the atlas for `enabled`, remembering the authored sizes the first time through.
##
## ZERO IS THE OFF VALUE and it is why the remembering has to happen before the write: once the
## atlas is zero the authored number is gone from the only place it lived.
func apply(viewport: Viewport, enabled: bool) -> void:
	if viewport == null:
		return
	if _positional < 0:
		_remember(viewport)
	viewport.positional_shadow_atlas_size = _positional if enabled else 0
	RenderingServer.directional_shadow_atlas_set_size(_directional if enabled else 0, true)


## What the project authored for the positional atlas, or -1 before the first apply.
func authored_positional() -> int:
	return _positional


## What the project authored for the directional shadow, or -1 before the first apply.
func authored_directional() -> int:
	return _directional


## Read through `DictRead` rather than `int(value)`, because `ProjectSettings.get_setting`
## answers a Variant and a hand-edited `project.godot` can put a string where a number belongs —
## the same reason every save section in this project is read that way.
func _remember(viewport: Viewport) -> void:
	_positional = viewport.positional_shadow_atlas_size
	var authored: Dictionary = {"size": ProjectSettings.get_setting(DIRECTIONAL_SETTING, FALLBACK_SIZE)}
	_directional = DictRead.get_int(authored, "size", FALLBACK_SIZE)
