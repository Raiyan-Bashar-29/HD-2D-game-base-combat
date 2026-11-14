extends TestCase
## A member's art in the field (C9.9d): the sheet goes on the body, a move with art shows its
## strip and plays its sounds once per swing, a form's look may bring a second costume, and each
## body shows the member on it after a party switch.
##
## OWNS: assertions about `MoveArt`, `MemberArt`, `ArtSwap` and `CharacterVisual.use_sheet`.
## MUST NOT: name a game's characters or art files, or wait for frames.

const NOON: float = 12.0
const MOVE: StringName = &"move/fixture_art_swing"
const FORM: StringName = &"status/fixture_art_form"

var _rng := RandomNumberGenerator.new()
var _player: PlayerController
var _fighter: ActionFighter
var _art: MemberArt
var _costume: MemberArt
var _move: ActionMove
var _form: Power


func run() -> void:
	plan(13)
	SaveFixture.activate()
	Flags.clear_all()
	_rng.seed = 7
	_art = _member_art(4, true)
	_costume = _member_art(4, false)
	_move = ActionMove.new()
	_move.id = MOVE
	_move.startup = 0.2
	_move.active = 0.2
	_move.recovery = 0.6
	_shapes()
	_player = build("res://scenes/characters/player.tscn") as PlayerController
	attach(_player)
	var lead: ActionLoadout = _loadout(&"fixture_art_lead", _art)
	lead.companions = [_loadout(&"fixture_art_mate", null)]
	_fighter = ActionHost.equip(_player, lead)
	_on_the_body()
	_a_move()
	_a_costume()
	_switch(lead)
	_player.free()
	Flags.clear_all()


func _shapes() -> void:
	var art: MoveArt = _art.moves[MOVE]
	equal("a strip is spread evenly over its seconds and holds its last picture",
		[art.frame_at(0.0), art.frame_at(0.3), art.frame_at(0.99), art.frame_at(5.0), art.cell()],
		[0, 1, 3, 3, Vector2i(6, 10)])
	equal("a sound with no time plays at the start", [art.time_of(0), art.time_of(1), art.time_of(2)], [0.0, 0.5, 0.0])
	equal("clean art has no problems", _art.problems("x").size(), 0)
	var bad := MemberArt.new()
	bad.sheet = _art.sheet
	bad.pixel_size = 0.0
	bad.moves = {MOVE: MoveArt.new(), &"move/fixture_art_none": null}
	equal("no layout, no pixel size, an empty move and a missing one are four problems", bad.problems("x").size(), 4)
	var def := CombatantDef.new()
	def.combatant_id = &"fixture_art_def"
	def.name_key = "fixture.name"
	def.base_stats = {&"max_hp": 1.0}
	def.art = bad
	equal("a fighter reports its art's problems", def.problems("x").size(), 4)


func _on_the_body() -> void:
	var swap: ArtSwap = _swap(_player)
	var visual: CharacterVisual = _player.get_node(^"Visual") as CharacterVisual
	var own: Texture2D = visual.sprite.texture
	swap.watch()
	equal("the member's sheet goes on the body, cut and sized as its art says",
		[swap.current, visual.sprite.texture, visual.sprite.hframes, visual.sprite.vframes,
			is_equal_approx(visual.sprite.pixel_size, 0.05), is_equal_approx(visual.sprite.position.y, -0.1)],
		[_art, _art.sheet, 4, 2, true, true])
	Combatant.of(_player).art = null
	swap.watch()
	equal("with no art the body's own sheet comes back", [swap.current, visual.sprite.texture], [null, own])
	Combatant.of(_player).art = _art
	swap.watch()


func _a_move() -> void:
	var swap: ArtSwap = _swap(_player)
	var visual: CharacterVisual = _player.get_node(^"Visual") as CharacterVisual
	_fighter.timeline.start(_move)
	swap.watch()
	var strip: Sprite3D = visual.get_node_or_null(^"MoveStrip") as Sprite3D
	equal("a move with art shows its strip in place of the sheet, and plays its first sound",
		[strip != null and strip.texture == _art.moves[MOVE].strip, visual.sprite.visible, swap.sounds_played],
		[true, false, 1])
	_fighter.timeline.step(0.6)
	swap.watch()
	swap.watch()
	equal("later it shows a later picture and plays the timed sound, each once",
		[strip.frame, strip.hframes, swap.sounds_played, is_equal_approx(strip.position.y, -0.1)], [2, 4, 2, true])
	_fighter.timeline.step(1.0)
	swap.watch()
	equal("when the move ends the sheet is back",
		[visual.get_node_or_null(^"MoveStrip") == null, visual.sprite.visible], [true, true])
	_fighter.timeline.start(_move)
	swap.watch()
	_fighter.timeline.cancel()
	swap.watch()
	equal("a second swing plays the sound again", swap.sounds_played, 3)


func _a_costume() -> void:
	var swap: ArtSwap = _swap(_player)
	PowerUse.use(Combatant.of(_player), _form, [], _rng, NOON)
	swap.watch()
	equal("a form whose look has art shows that sheet, and the member's strip for a move it lacks",
		[swap.current, ArtSwap.move_art_of(_player, MOVE)], [_costume, _art.moves[MOVE]])
	PowerUse.use(Combatant.of(_player), _form, [], _rng, NOON)
	swap.watch()


func _switch(lead: ActionLoadout) -> void:
	var mate: PartyFollower = FieldParty.spawn(_player, lead)[0]
	FieldParty.switch(_player)
	_swap(_player).watch()
	_swap(mate).watch()
	equal("after a switch each body shows the member now on it",
		[_swap(_player).current, _swap(mate).current], [null, _art])
	mate.free()


func _swap(body: Node) -> ArtSwap:
	for child: Node in body.get_children():
		if child is ArtSwap:
			return child as ArtSwap
	return null


func _member_art(frames: int, with_move: bool) -> MemberArt:
	var layout := SpriteSheetLayout.new()
	layout.facings = 4
	layout.frames = 2
	layout.animations = 1
	layout.cell_size = Vector2i(8, 10)
	var art := MemberArt.new()
	art.sheet = _picture(32, 20)
	art.layout = layout
	art.pixel_size = 0.05
	art.ground_offset = -0.1
	if with_move:
		var swing := MoveArt.new()
		swing.strip = _picture(6 * frames, 10)
		swing.frames = frames
		swing.feet = Vector2i(3, 7)
		swing.seconds = 1.0
		swing.sounds = [AudioStreamWAV.new(), AudioStreamWAV.new()]
		swing.sound_at = [0.0, 0.5]
		art.moves = {MOVE: swing}
	return art


func _picture(width: int, height: int) -> ImageTexture:
	return ImageTexture.create_from_image(Image.create(width, height, false, Image.FORMAT_RGBA8))


func _loadout(id: StringName, art: MemberArt) -> ActionLoadout:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "fixture.name"
	def.faction = &"player"
	def.base_stats = {&"max_hp": 40.0, &"attack": 5.0}
	def.level_curve = LevelCurve.new()
	def.art = art
	if art != null:
		def.power_kit = _kit()
	var made := ActionLoadout.new()
	made.fighter = def
	made.moves = MoveSet.new()
	return made


func _kit() -> PowerKit:
	var look := LookDef.new()
	look.look_id = &"look/fixture_art"
	look.art = _costume
	var status := StatusEffect.new()
	status.id = FORM
	status.name_key = "fixture.status"
	var form := FormMechanism.new()
	form.status = status
	form.look = look
	_form = Power.new()
	_form.power_id = &"power/fixture_art_form"
	_form.name_key = "fixture.power_form"
	_form.mechanism = form
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_art"
	kit.name_key = "fixture.kit"
	kit.powers = [_form]
	return kit
