class_name Footsteps
extends Node3D
## The sound a character makes walking, and the ground it is made on. A component under a
## `CharacterBody3D`, on the same reasoning as `Inventory` and `Equipment`: an NPC gets one by
## being given one, and nothing global has to know how many characters exist.
##
## THIS IS THE ONE CLAIM THE VERIFICATION LADDER CANNOT SEE AT ALL, and that is why the file is
## shaped the way it is. A footstep is not visual, so no capture reads it; it needs a physics
## frame, so no assertion reaches it (`TestCase.run()` is synchronous); and under `--headless`
## the audio driver is `Dummy`, where every `play()` leaks its playback into the AudioServer
## (gotcha 20). So the file is split along that line, exactly as `SurfaceWetness` split for
## drying:
##
##   - ASSERTABLE, and asserted: `travel()` is a pure accumulator, `GroundSurface.of_node()` is
##     a pure query, and `brightness_for()` is a pure function of a name. Between them they are
##     "how often is a step taken, what am I standing on, and what does it sound like".
##   - NOT ASSERTABLE, and proved by a windowed run with the log quoted: the raycast, the frame
##     loop and the `play()` itself.
##
## THE SOUND IS GENERATED, AND ITS TIMBRE IS DERIVED FROM THE SURFACE'S NAME. Art is deferred
## indefinitely and audio is art, so a `.wav` per surface is a dependency this project will not
## take. `AmbienceBed` generates its rain the same way and for the same reason. Deriving the
## timbre from the NAME rather than from a table is what keeps this file inside the boundary
## rule: a table mapping a surface to a brightness would be engine code naming demo content, and
## it would mean a game that authors a sixth surface gets silence until someone edits `src/`.
## A game with real recordings replaces `stream_for()` and nothing else.
##
## OWNS: the stride, the downward probe, the generated streams and one player.
## MUST NOT: name a surface, decide movement speed, or be depended on by anything. Deleting
## this node must leave the character walking in silence and nothing else.

## Metres between steps. Independent of gait on purpose: a run covers the distance faster and
## therefore steps faster, with no second number to keep in agreement with the first.
@export var stride: float = 1.7
## How far below the node's origin to look for ground.
@export var probe_depth: float = 1.2
## Loudness of a step, linear. Under the ambience bed, which is under the music.
@export var volume: float = 0.45

## Timbre range the surface names are spread across. Both ends are audible and clearly
## different: 0.08 is a soft thud, 0.9 a sharp scuff.
const MIN_BRIGHTNESS: float = 0.08
const MAX_BRIGHTNESS: float = 0.9
## How fast the burst dies away. 1.6 is a ring, 5.0 a click. A SECOND derived axis, so that two
## names landing near each other on one of them still sound different. Defence in depth: the
## real fix for that is `_spread` below, and this is what makes the remaining odds small.
const MIN_DECAY: float = 1.6
const MAX_DECAY: float = 5.0
## Salt for the second axis. Hashing the same text twice gives the same number, so without it
## the two axes would move together and the second one would prove nothing.
const DECAY_SALT: String = "/decay"
const STEP_SECONDS: float = 0.13
const MIX_RATE: int = 22050
## Below this a character is standing still enough that a stride would take minutes to fill.
const MOVING: float = 0.05

var _ray: RayCast3D = null
var _player: AudioStreamPlayer3D = null
var _streams: Dictionary[StringName, AudioStreamWAV] = {}
var _travelled: float = 0.0
var _steps: int = 0
var _surface: StringName = GroundSurface.NONE
## Said once per lifetime, never per step. An untagged ground is legal, because a game may
## author no surfaces at all, but it must not be SILENT about being silent. Same treatment as
## an area with no `AreaDef`.
var _reported_untagged: bool = false


func _ready() -> void:
	_ray = RayCast3D.new()
	_ray.name = "Probe"
	_ray.target_position = Vector3(0.0, -probe_depth, 0.0)
	_ray.collision_mask = Layers.WORLD
	_ray.enabled = true
	add_child(_ray)

	_player = AudioStreamPlayer3D.new()
	_player.name = "Step"
	_player.bus = "SFX"
	add_child(_player)


func _physics_process(delta: float) -> void:
	var body: CharacterBody3D = get_parent() as CharacterBody3D
	if body == null or not body.is_on_floor():
		return
	var speed: float = Vector2(body.velocity.x, body.velocity.z).length()
	if speed < MOVING:
		return
	if travel(speed * delta):
		take_step()


## Add distance walked; true when that completed a stride. The remainder is CARRIED rather than
## reset, or a character walking in small increments would never take a step at all, which is
## exactly what happens on a frame-rate spike if you compare an absolute total to a threshold.
func travel(distance: float) -> bool:
	if distance <= 0.0:
		return false
	_travelled += distance
	if _travelled < stride:
		return false
	_travelled -= stride
	return true


## Look down, and make the noise that ground makes. Public so a probe can force one without
## walking, which is the only way the audio path can be exercised on demand.
func take_step() -> void:
	_steps += 1
	var found: StringName = ground()
	if found != _surface:
		_surface = found
		Log.debug("audio", "Footing is now '%s'" % _spoken(found))
	if found == GroundSurface.NONE:
		_report_untagged()
		return
	_play(found)


## What this character is standing on, right now. Empty when nothing is under the probe, and
## equally empty when the ground is there and carries no tag; `is_grounded()` separates them.
func ground() -> StringName:
	if _ray == null or not _ray.is_colliding():
		return GroundSurface.NONE
	return GroundSurface.of_node(_ray.get_collider() as Node)


func is_grounded() -> bool:
	return _ray != null and _ray.is_colliding()


## The last surface a step was actually taken on. NO CALLER — and the line that used to stand
## here said "read by the probe", which was never true of any probe this repository has. It is a
## query and not a signal for the stated reason: it is the hook a dust puff or a footprint decal
## reads on the frame it spawns, and this template has neither.
func current_surface() -> StringName:
	return _surface


## NO CALLER, for the same reason and as the same pair: a distance-walked achievement, a tutorial
## that fires on the tenth step, or a debug overlay all read this, and none of the three is here.
func steps_taken() -> int:
	return _steps


## How bright a surface's step is, derived from its name and nothing else. Deterministic across
## runs, because a hash of the same text is: two surfaces sound reliably different, and the same
## surface sounds the same in one area as in the next.
static func brightness_for(surface: StringName) -> float:
	if surface == GroundSurface.NONE:
		return 0.0
	return _spread(String(surface), MIN_BRIGHTNESS, MAX_BRIGHTNESS)


## How sharply a surface's step dies away. The second derived axis; see MIN_DECAY.
static func decay_for(surface: StringName) -> float:
	if surface == GroundSurface.NONE:
		return 0.0
	return _spread(String(surface) + DECAY_SALT, MIN_DECAY, MAX_DECAY)


## Place a name somewhere in a range, deterministically and WITHOUT clustering.
##
## `String.hash()` ALONE IS NOT ENOUGH, and the windowed probe is the only thing that could
## have said so. Godot's string hash mixes its low bits weakly, so short names of similar
## length land near each other: measured, `"grass"` hashes to 260508453 and `"stone"` to
## 274826446 — wildly different numbers whose last three digits are 453 and 446. Taking a
## modulus of that put the demo's grass and stone within 0.006 of one another and the two
## steps were indistinguishable BY EAR, with every rung green and a `playing=true` in the log.
## The avalanche below is one multiply and two shifts, and it moves the same pair to 796 and
## 572. A hash that looks random is not the same as a hash that IS, and only the ear noticed.
static func _spread(text: String, low: float, high: float) -> float:
	var mixed: int = absi(text.hash()) & 0x7fffffff
	mixed = ((mixed ^ (mixed >> 13)) * 0x5bd1e995) & 0x7fffffff
	mixed = (mixed ^ (mixed >> 15)) & 0x7fffffff
	return low + (high - low) * (float(mixed % 1000) / 999.0)


func _play(surface: StringName) -> void:
	if not _streams.has(surface):
		_streams[surface] = stream_for(surface)
	_player.stream = _streams[surface]
	_player.volume_db = linear_to_db(clampf(volume, 0.001, 1.0))
	# Gotcha 20: against the Dummy driver a playback is queued and released on the NEXT mix,
	# and headless quits before there is one, so every step would be a leaked instance in the
	# suite's output. `AmbienceBed.is_audible()` is the one place that is measured.
	if AmbienceBed.is_audible():
		_player.play()


func _report_untagged() -> void:
	if _reported_untagged:
		return
	_reported_untagged = true
	Log.info("audio", "Ground under '%s' carries no metadata/%s, so steps are silent here"
		% [name, GroundSurface.META])


func _spoken(surface: StringName) -> String:
	return String(surface) if surface != GroundSurface.NONE else "(untagged)"


## One short enveloped burst of low-passed noise: the filter is the surface's timbre and the
## envelope is what makes it a step rather than a hiss. Static and pure, so a test can compare
## two surfaces without a node, a bus or a device.
static func stream_for(surface: StringName) -> AudioStreamWAV:
	var count: int = int(MIX_RATE * STEP_SECONDS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4409 + absi(String(surface).hash())
	var coefficient: float = clampf(brightness_for(surface), 0.01, 1.0)
	var decay: float = decay_for(surface)
	var data := PackedByteArray()
	data.resize(count * 2)
	var filtered: float = 0.0
	for i: int in count:
		filtered = lerpf(filtered, rng.randf_range(-1.0, 1.0), coefficient)
		var envelope: float = pow(1.0 - float(i) / float(count), decay)
		data.encode_s16(i * 2, clampi(roundi(filtered * envelope * 14000.0), -32768, 32767))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
