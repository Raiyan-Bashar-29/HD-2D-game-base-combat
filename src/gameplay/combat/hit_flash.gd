class_name HitFlash
extends Node
## A hit landing in the field flashes the struck body (C10.12). Placeholder look: a tint, no art.
##
## IN PLAIN WORDS: `flash(body)` tints every sprite under the body's `Visual` with `TINT` for
## `SECONDS` of real time, then gives each back the colour it had (an unseen fighter's fade
## included). A second hit during a flash only restarts the clock. It lives as a child of the
## body, made on the first flash.
##
## OWNS: the tint and how long it lasts.
## MUST NOT: decide when a hit landed (`HitNumbers` asks) or change anything but colour.

const TINT: Color = Color(1.0, 0.4, 0.4)
const SECONDS: float = 0.1

var _left: float = 0.0
var _saved: Dictionary[SpriteBase3D, Color] = {}


## Flashes `body`; returns the flash, made on first use.
static func flash(body: Node) -> HitFlash:
	var made: HitFlash = null
	for child: Node in body.get_children():
		if child is HitFlash:
			made = child as HitFlash
	if made == null:
		made = HitFlash.new()
		made.name = "HitFlash"
		body.add_child(made)
	made._start()
	return made


## True while the tint is on.
func lit() -> bool:
	return not _saved.is_empty()


func _start() -> void:
	if _saved.is_empty():
		var visual: Node = get_parent().get_node_or_null(^"Visual")
		for sprite: Node in (visual.find_children("*", "SpriteBase3D", true, false) if visual != null else []):
			var shown: SpriteBase3D = sprite as SpriteBase3D
			_saved[shown] = shown.modulate
			shown.modulate = Color(TINT.r, TINT.g, TINT.b, shown.modulate.a)
	_left = SECONDS


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left -= delta
	if _left <= 0.0:
		for sprite: SpriteBase3D in _saved:
			if is_instance_valid(sprite):
				sprite.modulate = _saved[sprite]
		_saved.clear()
