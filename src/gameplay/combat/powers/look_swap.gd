class_name LookSwap
extends Node
## Shows the form a fighter is in (C6.5d): its look on the body, and its name for the screens.
## See `docs/GEAR.md` Part 4 and `LookDef`.
##
## IN PLAIN WORDS: one of these sits on every field body (`ActionHost.fit_identity`). Each physics
## frame it asks "which form is held, and what does it look like?" and changes the body only
## when the answer changed. Because it asks rather than being told, every way a form can end (a
## cure, a timer, a drain, a load, a new game, a gear change, a party switch) shows right with no
## wiring of its own.
## - The look goes on the body's `CharacterVisual`: the sprite is tinted, the visual scaled, and
##   a tag shown over the head. With no form, the remembered tint and size come back and the tag
##   goes. A body with no visual is left alone.
## - It stays with the BODY on a party switch, like the hurtbox, so each body shows the member
##   now on it.
## - With forms of two groups held at once, the first in kit order with a look (or a name) wins.
## - `look_of` and `form_name_key` are static, so the battle screen and the HUD name the form
##   from the same place.
##
## OWNS: putting a form's look on a body and taking it off.
## MUST NOT: change stats, moves or statuses, or name a character. The form (`FormRun`) does that.

## How high over the body's feet the tag sits, before the look's scale.
const TAG_HEIGHT: float = 2.1
const TAG_NAME: String = "LookTag"

## The look on the body now, or null.
var current: LookDef = null

var _base_tint: Color = Color.WHITE
var _base_scale: Vector3 = Vector3.ONE


## The look of the first held form on `body` that has one, in kit order, or null.
static func look_of(body: Node) -> LookDef:
	for run: FormRun in FormRun.held_in(body):
		var look: LookDef = (run.mechanism as FormMechanism).look_at(run.stage)
		if look != null:
			return look
	return null


## The name key of the first held form on `body` that has one, in kit order, or "".
static func form_name_key(body: Node) -> String:
	for run: FormRun in FormRun.held_in(body):
		var key: String = (run.mechanism as FormMechanism).name_at(run.stage)
		if key != "":
			return key
	return ""


func _physics_process(_delta: float) -> void:
	watch()


## Puts on the look of the form held now, if it changed since the last call. Public so a test
## steps it without waiting for frames.
func watch() -> void:
	var wanted: LookDef = look_of(get_parent())
	if wanted == current:
		return
	var visual: CharacterVisual = _visual()
	if visual != null:
		if current == null:
			_remember(visual)
		if wanted == null:
			_restore(visual)
		else:
			_apply(visual, wanted)
	current = wanted


func _remember(visual: CharacterVisual) -> void:
	_base_scale = visual.scale
	_base_tint = visual.sprite.modulate if visual.sprite != null else Color.WHITE


func _apply(visual: CharacterVisual, look: LookDef) -> void:
	if visual.sprite != null:
		visual.sprite.modulate = _base_tint * look.tint
	visual.scale = _base_scale * look.scale
	var tag: Label3D = _tag(look.label_key != "")
	if tag != null:
		tag.text = tr(look.label_key)
		tag.position = Vector3(0.0, TAG_HEIGHT * look.scale, 0.0)


func _restore(visual: CharacterVisual) -> void:
	if visual.sprite != null:
		visual.sprite.modulate = _base_tint
	visual.scale = _base_scale
	_tag(false)


# The tag over the head: made when `wanted` and missing, freed when not wanted. Null when none.
func _tag(wanted: bool) -> Label3D:
	var body: Node = get_parent()
	var tag: Label3D = body.get_node_or_null(TAG_NAME) as Label3D
	if not wanted:
		if tag != null:
			body.remove_child(tag)
			tag.free()
		return null
	if tag == null:
		tag = Label3D.new()
		tag.name = TAG_NAME
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.pixel_size = 0.01
		tag.font_size = 40
		tag.outline_size = 10
		body.add_child(tag)
	return tag


# The body's `CharacterVisual`, among its children, or null.
func _visual() -> CharacterVisual:
	for child: Node in get_parent().get_children():
		if child is CharacterVisual:
			return child as CharacterVisual
	return null
