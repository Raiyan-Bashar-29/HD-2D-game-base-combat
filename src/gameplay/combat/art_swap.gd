class_name ArtSwap
extends Node
## Shows the art of the member on a body (C9.9d): its walking sheet, and a strip and sounds for
## the move it is playing. See `MemberArt` and `MoveArt`.
##
## IN PLAIN WORDS: one of these sits on every field body (`ActionHost.fit_identity`), beside the
## `LookSwap`. Each physics frame it asks two questions and changes the body only when an
## answer changed.
## 1. "Whose art is it?" The held form's look, when that look has art (a second costume);
##    otherwise the member's (`Combatant.art`). The sheet goes on the body's `CharacterVisual`.
##    With no art, the body's own sheet comes back. Because the `Combatant` moves with the
##    member on a party switch, each body shows the member now on it.
## 2. "Is a move with art playing?" The body's `Hurtbox` holds the timeline. While a move whose
##    id is in the art's `moves` runs, a second sprite shows its strip (mirrored when the body
##    faces away or left, like the sheet) and the walking sprite is hidden. Each of the move's
##    sounds plays once per swing, at its time.
##
## OWNS: putting a member's sheet, move strips and move sounds on a body.
## MUST NOT: change stats, moves or statuses, start a move, or name a character.

const STRIP_NAME: String = "MoveStrip"

## The art whose sheet is on the body now, or null.
var current: MemberArt = null
## How many sounds this node has started, for a test to count.
var sounds_played: int = 0

var _base: Array = []
var _swing: int = -1
var _next_sound: int = 0


## The art `body` shows now: the held form's, else the member's, else null.
static func art_of(body: Node) -> MemberArt:
	var look: LookDef = LookSwap.look_of(body)
	if look != null and look.art != null:
		return look.art
	var member: Combatant = Combatant.of(body)
	return member.art if member != null else null


## The art of the move with `id` on `body`: the held form's first, then the member's, or null.
static func move_art_of(body: Node, id: StringName) -> MoveArt:
	var look: LookDef = LookSwap.look_of(body)
	if look != null and look.art != null and look.art.moves.has(id):
		return look.art.moves[id]
	var member: Combatant = Combatant.of(body)
	if member != null and member.art != null and member.art.moves.has(id):
		return member.art.moves[id]
	return null


func _physics_process(_delta: float) -> void:
	watch()


## Shows what the body should show now. Public so a test steps it without waiting for frames.
func watch() -> void:
	var visual: CharacterVisual = _visual()
	if visual == null or visual.sprite == null:
		return
	var wanted: MemberArt = art_of(get_parent())
	if wanted != current:
		_swap(visual, wanted)
		current = wanted
	_show_move(visual)


func _swap(visual: CharacterVisual, wanted: MemberArt) -> void:
	if _base.is_empty():
		_base = [visual.sprite.texture, visual.layout, visual.pixel_size, visual.ground_offset]
	if wanted != null and wanted.sheet != null:
		visual.use_sheet(wanted.sheet, wanted.layout, wanted.pixel_size, wanted.ground_offset)
	else:
		visual.use_sheet(_base[0] as Texture2D, _base[1] as SpriteSheetLayout,
				_base[2] as float, _base[3] as float)


func _show_move(visual: CharacterVisual) -> void:
	var timeline: MoveTimeline = _timeline()
	var art: MoveArt = null
	if timeline != null and timeline.busy():
		art = move_art_of(get_parent(), timeline.move.id)
	var strip: Sprite3D = _strip(visual, art != null and art.strip != null)
	visual.sprite.visible = strip == null
	if art == null:
		_swing = -1
		return
	if timeline.swing != _swing:
		_swing = timeline.swing
		_next_sound = 0
	while _next_sound < art.sounds.size() and art.time_of(_next_sound) <= timeline.elapsed:
		_play(art.sounds[_next_sound])
		_next_sound += 1
	if strip == null:
		return
	var cell: Vector2i = art.cell()
	strip.texture = art.strip
	strip.hframes = art.frames
	strip.frame = art.frame_at(timeline.elapsed)
	strip.pixel_size = visual.pixel_size
	strip.modulate = visual.sprite.modulate
	strip.flip_h = int(visual.facing()) >= GameEnums.Facing.size() / 2
	strip.offset = Vector2(0.0, float(cell.y) * 0.5)
	strip.position = Vector3(0.0, -float(cell.y - 1 - art.feet.y) * visual.pixel_size, 0.0)


# The strip's sprite under the visual: made when `wanted` and missing, freed when not wanted.
func _strip(visual: CharacterVisual, wanted: bool) -> Sprite3D:
	var strip: Sprite3D = visual.get_node_or_null(STRIP_NAME) as Sprite3D
	if not wanted:
		if strip != null:
			visual.remove_child(strip)
			strip.free()
		return null
	if strip == null:
		strip = Sprite3D.new()
		strip.name = STRIP_NAME
		strip.billboard = visual.sprite.billboard
		strip.alpha_cut = visual.sprite.alpha_cut
		strip.texture_filter = visual.sprite.texture_filter
		strip.shaded = visual.sprite.shaded
		strip.double_sided = true
		strip.cast_shadow = visual.sprite.cast_shadow
		visual.add_child(strip)
	return strip


func _play(stream: AudioStream) -> void:
	sounds_played += 1
	if stream == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = "SFX"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _timeline() -> MoveTimeline:
	for child: Node in get_parent().get_children():
		if child is Hurtbox:
			return (child as Hurtbox).timeline
	return null


# The body's `CharacterVisual`, among its children, or null.
func _visual() -> CharacterVisual:
	for child: Node in get_parent().get_children():
		if child is CharacterVisual:
			return child as CharacterVisual
	return null
