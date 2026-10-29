class_name CharacterVisual
extends Node3D
## Turns movement into a billboarded, lit, correctly-sorted sprite. Used by the player and
## by every NPC, unchanged.
##
## THE SPRITE3D SETTINGS THAT MATTER, and why each one is what it is:
##
##   billboard = BILLBOARD_FIXED_Y
##       Rotates to face the camera around the Y axis only. Full BILLBOARD_ENABLED also
##       tips the sprite back as the camera pitches down, so a character standing on flat
##       ground appears to lean. Fixed-Y keeps them upright.
##
##   alpha_cut = ALPHA_CUT_DISCARD
##       This is the important one. With alpha blending, a sprite writes no depth, so it
##       cannot sort against other transparent things and casts no shadow. Discarding
##       transparent pixels instead makes the sprite opaque geometry: it sorts by depth
##       correctly, occludes properly, and casts a real shadow. The cost is no soft edges,
##       which is exactly right for pixel art.
##
##   texture_filter = TEXTURE_FILTER_NEAREST
##       Keeps pixels crisp. Linear filtering turns pixel art into mush at this scale.
##
##   shaded = true
##       Makes the sprite respond to lights, so a character walking under a lantern at
##       night is actually lit by it. Without this the day/night cycle would not touch
##       characters and they would look pasted on.
##
## THE SHEET'S DIMENSIONS ARE NOT IN THIS FILE. They are a `SpriteSheetLayout` resource on the
## `layout` @export, and every number that depends on them — hframes, vframes, the foot offset,
## the frame wrap, the direction sectors — is read from it. See that class for the grid.
##
## OWNS: the sprite, its facing, its sheet column, its animation frame, and how long it has
## been standing still.
## MUST NOT: read input, move the character, contain game rules, or hold any sheet dimension of
## its own. It is told a velocity and a state, and it draws.
##
## THE SECOND WAY IT IS TOLD, since T5.14, is `Events.turn_requested` - a turn asked for by
## somebody else and answered only when the request names THIS character. Still being told;
## still no rule of its own. The reason it listens rather than being called is in that signal's
## own block, and the reason listening is safe here when `player_state_changed` is not is on
## `_on_turn_requested`.

## The layout assumed when the @export below is unwired. Not a fallback anybody should rely on:
## it exists so an unwired node draws a recognisable character while the log says it is unwired,
## because gotcha 2's whole lesson is that a silent default looks exactly like success.
const DEFAULT_FACINGS: int = 8
const DEFAULT_FRAMES: int = 4
const DEFAULT_CELL: Vector2i = Vector2i(32, 48)

## How this character's sheet is cut up, as authored data. THE ART CONTRACT SEAM: until T2.1 this
## was `FACING_COUNT = 8` and `FRAME_COUNT = 4` as constants right here, so a game whose sheet had
## four facings and six frames needed a code edit — the one thing a template must never ask for.
@export var layout: SpriteSheetLayout = null

@export var texture: Texture2D = null
## World size of one texture pixel. 0.01 makes a 48px-tall sprite 0.48m... too small for a
## person, so the default is tuned so a 48px figure is about 1.7m.
@export var pixel_size: float = 0.035
## How many sheet frames per second at full walking speed.
@export var walk_fps: float = 8.0
## How many sheet frames per second while STANDING STILL, for sheets whose idle is a real cycle
## rather than a pose. Slower than a walk on purpose: an idle at walking pace reads as marching.
## Only used when the sheet's idle block differs from its walk block - see `_idle_animates`.
@export var idle_fps: float = 3.0
## Movement speed treated as "full walk" for animation timing.
@export var reference_speed: float = 3.2
## Lifts the sprite so its feet sit on the ground rather than its centre.
@export var ground_offset: float = 0.0

var sprite: Sprite3D = null

var _layout: SpriteSheetLayout = null
var _facing: GameEnums.Facing = GameEnums.Facing.SOUTH
## The sheet COLUMN. Deliberately NOT derived from _facing: the enum is how many directions the
## GAME reasons about, `layout.facings` is how many the ART distinguishes, and mapping one onto
## the other would put the sector width back in two places that have to agree by hand.
var _column: int = 0
var _frame_time: float = 0.0
var _frame: int = 0
var _moving: bool = false
## WHAT THE CHARACTER IS DOING, which decides which animation BLOCK is drawn while `_moving`
## decides whether the block advances. The two were one boolean until T5.2, which is why a
## running character replayed the walk cycle faster and a sheet had nowhere to put a run.
## Pushed in by whoever drives this visual - never read from `Events.player_state_changed`,
## because every NPC uses this class and none of them is the player.
var _state: GameEnums.MoveState = GameEnums.MoveState.IDLE
## HOW LONG THIS CHARACTER HAS BEEN STANDING STILL, and whether it is mid-break. The whole of
## the second idle's chooser lives in these two numbers, and neither is a rule: the THRESHOLD
## they are compared against is on the sheet, so what this file decides is only "has that many
## seconds passed", which is arithmetic on the `delta` it is already handed. See
## `SpriteSheetLayout.idle_break_row` for why dwell and not the weather or the clock.
var _dwell: float = 0.0
var _breaking: bool = false


func _ready() -> void:
	_layout = _resolved_layout()
	sprite = get_node_or_null(^"Sprite3D") as Sprite3D
	if sprite == null:
		sprite = Sprite3D.new()
		sprite.name = "Sprite3D"
		add_child(sprite)
	_configure_sprite()
	# ONE LISTENER PER CHARACTER, filtered by who the request names. Freeing the node
	# disconnects it, which is why nothing here undoes it.
	Events.turn_requested.connect(_on_turn_requested)


func _configure_sprite() -> void:
	if texture != null:
		sprite.texture = texture
	sprite.hframes = _layout.facings
	sprite.vframes = _layout.sheet_rows()
	for problem: String in _layout.problems(sprite.texture):
		Log.warn("world", "%s: %s" % [name, problem])
	sprite.pixel_size = pixel_size
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = true
	sprite.double_sided = true
	# Anchor the sprite by its feet. The sprite stays centred and is lifted by half its
	# height, so the node origin sits on the ground where the collision capsule does.
	sprite.centered = true
	sprite.offset = Vector2(0.0, float(_layout.cell_size.y) * 0.5)
	sprite.position = Vector3(0.0, ground_offset, 0.0)
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_apply_frame()


## Called every physics frame by whatever drives this character.
## `velocity` is world-space; only the horizontal part decides FACING and pace.
## `state` defaults to WALK so a caller that has not been updated behaves exactly as before:
## moving draws the walk block, standing still draws the idle one.
func update_from_velocity(velocity: Vector3, delta: float,
		state: GameEnums.MoveState = GameEnums.MoveState.WALK) -> void:
	var flat: Vector2 = Vector2(velocity.x, velocity.z)
	var speed: float = flat.length()
	# A CLIMB IS MOVING EVEN WHEN `flat` IS ZERO. Going up a ladder is entirely vertical, so
	# deriving "moving" from horizontal speed alone pinned the frame at 0 and left `climb_row`
	# undrawable for the whole of T5.2: the block was addressable and nothing ever advanced it.
	var climbing: bool = state == GameEnums.MoveState.CLIMB
	_moving = speed > 0.05 or climbing
	# A state that is not moving is IDLE whatever the caller said, so a character held still by
	# a dialogue box does not stand there playing its run cycle in place.
	_state = state if _moving else GameEnums.MoveState.IDLE

	# Only a HORIZONTAL move turns anybody. Aiming on a vertical climb would quantise a zero
	# vector and swing the character round to face south halfway up a ladder.
	if speed > 0.05:
		_aim(flat)
	if _moving:
		# MOVING ENDS A BREAK IMMEDIATELY AND RESETS THE CLOCK. A fidget is what a character
		# does INSTEAD of standing there, so a player who walks off mid-stretch must get the
		# walk block on that same frame, and must then have to stand still all over again.
		_dwell = 0.0
		_breaking = false
		_advance(delta, _rate_for(speed))
	else:
		_stand(delta)
	_apply_frame()


## Frames per second for a gait at `speed`. Clamped at both ends: a crawl still animates, and
## a sprint does not strobe.
func _rate_for(speed: float) -> float:
	return walk_fps * clampf(speed / maxf(0.01, reference_speed), 0.35, 2.0)


## Step the cycle. WITHIN the current block only - which block is drawn is `_state`'s business
## and `_apply_frame` reads both.
##
## IT RETURNS WHETHER THE CYCLE CAME BACK ROUND, which is the one fact an idle BREAK needs and
## nothing else does: a break plays once and stops, so somebody has to notice the end of it,
## and the only place that knows is the loop that wrapped the frame. Every other caller
## discards the answer, which `project.godot` permits deliberately - `return_value_discarded`
## is the one warning in the static-enforcement block set to 0.
func _advance(delta: float, fps: float) -> bool:
	var wrapped: bool = false
	_frame_time += delta * fps
	while _frame_time >= 1.0:
		_frame_time -= 1.0
		_frame = (_frame + 1) % _layout.frames
		wrapped = wrapped or _frame == 0
	return wrapped


## STANDING STILL, WHICH IS THREE DIFFERENT THINGS DEPENDING ON THE SHEET. It is a held pose
## on a single-block sheet, a breathing cycle on a sheet with an idle of its own, and since this
## row it is a breathing cycle that is INTERRUPTED every `idle_break_after` seconds by a second
## block that plays once and hands back.
##
## THE BREAK OUTRANKS `_idle_animates()` RATHER THAN NESTING INSIDE IT, and getting this the
## other way round is the bug worth naming: a sheet may legally have `idle_row == walk_row` -
## every sheet authored before T2.1 does - and a game that gives such a sheet a fidget block
## still wants the fidget. So the break is checked first, and the hold is what happens only
## when there is neither a distinct idle nor a break running. Between breaks that sheet holds
## its pose exactly as it always did, because animating its idle IS walking on the spot.
func _stand(delta: float) -> void:
	if _layout == null:
		return
	_dwell += delta
	if not _breaking and _layout.has_idle_break() and _dwell >= _layout.idle_break_after:
		_breaking = true
		_frame = 0
		_frame_time = 0.0
	if not _breaking and not _idle_animates():
		# Settle on the neutral pose rather than freezing mid-stride. A sheet with no idle
		# block of its own has nothing to play here, so holding frame 0 is the honest answer.
		_frame = 0
		_frame_time = 0.0
		return
	# ONE CYCLE AND OUT. The dwell restarts from the end of the break, not from the start of
	# it, so the gap a player sees between two fidgets is the authored number rather than that
	# number minus however long the block takes to play.
	if _advance(delta, idle_fps) and _breaking:
		_breaking = false
		_dwell = 0.0


## MAY A STANDING CHARACTER BREATHE? Only if its sheet actually has an idle block of its own.
## `idle_row == walk_row` is legal and was the only possibility before T2.1, and animating that
## case would replay the WALK cycle on the spot - which is the bug T5.2 fixed for run and sneak,
## arriving from the other direction. So the SHEET decides, exactly as it decides the gaits.
func _idle_animates() -> bool:
	if _layout == null or _layout.frames <= 1:
		return false
	return _layout.animation_for(GameEnums.MoveState.IDLE) \
			!= _layout.animation_for(GameEnums.MoveState.WALK)


## Face a direction without moving, for dialogue and scripted moments. `direction` is a
## world-space XZ vector, the same shape `update_from_velocity` derives from a velocity.
##
## ITS CALLER IS THE BUS, not any one system. Until T5.14 this method had only test callers -
## one of the 86 suite-only methods `check_methods.gd` reports - because nothing had decided
## WHO may ask for a turn. `Events.turn_requested` is that answer, and it is deliberately not
## a single owner: the player turning to a prompt and an NPC turning to whoever spoke are the
## same motion asked for by two unrelated systems, and a third will come along.
func face_direction(direction: Vector2) -> void:
	if direction.length_squared() < 0.0001:
		return
	_aim(direction)
	_apply_frame()


func facing() -> GameEnums.Facing:
	return _facing


## THE BUS ASKED SOMEBODY TO TURN. Answer only for the character this visual draws, because
## every character in the area hears the same signal.
##
## THIS IS NOT THE THING `_state`'s COMMENT FORBIDS, and the difference is the whole design.
## `Events.player_state_changed` is about THE PLAYER, so a class every NPC also uses must not
## listen to it. `turn_requested` NAMES the character it is for, so listening is safe for
## exactly as many characters as exist - and putting the answer here rather than in
## `PlayerController` and `NpcBrain` separately is what keeps it one implementation.
func _on_turn_requested(character: Node3D, towards: Vector3) -> void:
	if character == null or not _draws(character):
		return
	var to: Vector3 = towards - global_position
	face_direction(Vector2(to.x, to.z))


## Is `character` the body this visual belongs to? An ANCESTOR rather than the parent exactly,
## because a game may hang its visual under an offset node or a rig and nothing here should
## care - and `self`, for a visual attached with no body above it, which is what a test builds.
func _draws(character: Node3D) -> bool:
	return character == self or character.is_ancestor_of(self)


## Map a world-space XZ direction to a GameEnums.Facing, corrected for camera yaw so that
## "towards the camera" is always the front-facing value even if an area frames its camera from
## a different angle. Sector 0 is towards the camera, matching Facing.SOUTH.
##
## THE SECTOR COUNT COMES FROM THE ENUM, never from a literal, for exactly the reason the
## column's comes from the layout: `TAU / 8.0` sitting beside a separate `8` is two places
## holding one number, and this file used to have both.
func facing_from_direction(direction: Vector2) -> GameEnums.Facing:
	var count: int = GameEnums.Facing.size()
	var sector: int = roundi(_screen_angle(direction) / (TAU / float(count)))
	return posmod(sector, count) as GameEnums.Facing


## Which sheet column a direction draws. The layout owns the quantisation because it owns the
## facing count; this is the only caller that needs the answer.
func column_from_direction(direction: Vector2) -> int:
	return _layout.column_for_angle(_screen_angle(direction))


## Set the enum value and the column together, so the two cannot drift apart by one being
## updated at a call site and the other forgotten.
func _aim(direction: Vector2) -> void:
	_facing = facing_from_direction(direction)
	_column = column_from_direction(direction)


func _screen_angle(direction: Vector2) -> float:
	return atan2(direction.x, direction.y) - _camera_yaw()


## The layout to draw with. Unwired is legal and LOUD: an unwired @export renders something
## plausible and says nothing, which is the whole of gotcha 2, so this one says something.
func _resolved_layout() -> SpriteSheetLayout:
	if layout != null:
		return layout
	var assumed := SpriteSheetLayout.new()
	assumed.facings = DEFAULT_FACINGS
	assumed.frames = DEFAULT_FRAMES
	assumed.cell_size = DEFAULT_CELL
	Log.warn("world", "%s has no SpriteSheetLayout; assuming %d facings x %d frames" % [
		name, assumed.facings, assumed.frames,
	])
	return assumed


func _camera_yaw() -> float:
	var view: Viewport = get_viewport()
	if view == null:
		return 0.0
	var active: Camera3D = view.get_camera_3d()
	if active == null:
		return 0.0
	return active.global_rotation.y


func _apply_frame() -> void:
	if sprite == null or _layout == null:
		return
	# A BREAK IS NOT A MoveState, so it cannot be asked for through `animation_for` - that is
	# the whole reason `idle_break_animation()` exists as a second question rather than an
	# eleventh enum value. `_breaking` is only ever true while standing, so this cannot
	# override a gait.
	var block: int = _layout.idle_break_animation() if _breaking 			else _layout.animation_for(_state)
	sprite.frame = _layout.frame_index(_column, _frame, block)


## Diagnostic for the dev capture tool. Cheap, and the first thing worth knowing when a
## character does not appear on screen.
func describe() -> String:
	if sprite == null:
		return "no sprite"
	return "sprite visible=%s frame=%d/%d pos=%s size_px=%s" % [
		str(sprite.visible), sprite.frame, sprite.hframes * sprite.vframes,
		str(sprite.global_position), str(sprite.texture.get_size() if sprite.texture else Vector2.ZERO),
	]
