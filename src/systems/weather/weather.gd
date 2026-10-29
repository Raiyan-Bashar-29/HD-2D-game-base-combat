extends Node
## Weather state. Autoload `Weather`.
##
## WHY IT IS GLOBAL AND NOT PER-AREA
## Weather should persist when you walk through a door and back out, otherwise stepping into
## a house becomes a way to reroll the rain. The state lives here and outlives any area; each
## area only declares which kinds are *possible* there, and whether it is sheltered.
##
## AND WHY IT PUBLISHES A FLAG AS WELL AS A SIGNAL
## Same reason as `clock.gd`, which carries the long version: a signal serves a listener with
## CODE, and authored content has none — `FlagQuery` reads `Flags` and nothing else, so before
## T5.31 no conversation or quest step could mention the weather. The kind is projected into
## `weather/kind/<name>`, one bool, declared derived so it never reaches a save file.
##
## OWNS: the current kind, the blend between two kinds, intensity, scheduling changes, and
## publishing the kind into the `weather/` flag namespace.
## MUST NOT: spawn a particle, touch a light, play a sound, or read a flag it published. It
## publishes state and a 0..1 blend value. Presentation belongs to the area's own weather
## visuals node.
##
## HOW A LISTENER USES IT
##     Events.weather_changing.connect(_on_weather_changing)   # start a cross-fade
##     Weather.blend()                                         # 0..1 progress this frame
##     Weather.intensity()                                     # 0..1 how heavy it is now

## How long a natural weather change takes to blend, in real seconds.
const DEFAULT_BLEND: float = 12.0
## Minimum and maximum real seconds a weather state persists before rerolling.
const MIN_SPELL: float = 90.0
const MAX_SPELL: float = 420.0

## THE DERIVED FLAG NAMESPACE THIS FILE OWNS, WHOLE. A game must not put a flag of its own here.
const FLAG_PREFIX: String = "weather/"
## One bool under the kind's own NAME, exactly one of which exists at a time — not the
## `GameEnums.WeatherKind` ordinal. `clock.gd`'s `_publish_phase` carries the two measurements
## that settled the shape for both files, and it is the same argument here: an ordinal is a
## storage format an authored condition would depend on by accident, and a String flag is
## unreadable by every test in `FlagQuery`'s closed set.
const KIND_PREFIX: String = "weather/kind/"

var _current: GameEnums.WeatherKind = GameEnums.WeatherKind.CLEAR
var _target: GameEnums.WeatherKind = GameEnums.WeatherKind.CLEAR
var _blend: float = 1.0
var _blend_rate: float = 0.0
var _time_left: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Kinds the current area permits. Empty means "anything". Set by the area on load.
var _allowed: Array[GameEnums.WeatherKind] = []
## Set by the area: indoors and caves suppress visible weather without changing the state,
## so stepping outside again shows the same storm you left.
var sheltered: bool = false


func _ready() -> void:
	_rng.randomize()
	_time_left = _rng.randf_range(MIN_SPELL, MAX_SPELL)
	SaveSystem.register(&"weather", _collect_save, _apply_save)
	Flags.declare_derived(FLAG_PREFIX)
	# Both wipes of the store, for the reason spelled out in `clock.gd._ready`.
	Events.game_started.connect(_publish_kind)
	Events.game_loaded.connect(_on_game_loaded)
	_publish_kind()
	Log.info("weather", "Starting as %s" % kind_name(_current))


func _process(delta: float) -> void:
	if _blend < 1.0:
		_blend = minf(1.0, _blend + _blend_rate * delta)
		if is_equal_approx(_blend, 1.0):
			_current = _target
			Log.info("weather", "Settled into %s" % kind_name(_current))
			Events.weather_changed.emit(_current)
		return

	_time_left -= delta
	if _time_left <= 0.0:
		_roll_next()


func current() -> GameEnums.WeatherKind:
	return _current


func target() -> GameEnums.WeatherKind:
	return _target


## 0.0 at the instant a change starts, 1.0 when it has fully arrived. Visuals cross-fade
## from `current` to `target` across this value.
func blend() -> float:
	return _blend


func kind_name(kind: GameEnums.WeatherKind) -> String:
	return GameEnums.WeatherKind.keys()[kind]


## How heavy the weather is right now, accounting for an in-progress blend. Rain particle
## count, puddle wetness and ambience volume should all scale off this single number.
func intensity() -> float:
	var from: float = _base_intensity(_current)
	var to: float = _base_intensity(_target)
	return lerpf(from, to, _blend)


## True if the player should be getting wet. Used by interactions and surface footsteps.
func is_wet() -> bool:
	if sheltered:
		return false
	return _target == GameEnums.WeatherKind.RAIN or _target == GameEnums.WeatherKind.STORM


## Ask for a specific change. Used by the plot, by debug tools, and by area entry.
func request(kind: GameEnums.WeatherKind, seconds: float = DEFAULT_BLEND) -> void:
	if kind == _target:
		return
	_target = kind
	_blend = 0.0
	_blend_rate = 1.0 / maxf(0.05, seconds)
	_time_left = _rng.randf_range(MIN_SPELL, MAX_SPELL)
	_publish_kind()
	Log.info("weather", "%s -> %s over %.1fs" % [kind_name(_current), kind_name(kind), seconds])
	Events.weather_changing.emit(kind, seconds)


## Snap instantly with no blend. For loading a save and for entering an area that forces
## its own weather, where a visible cross-fade would look like a glitch.
func force(kind: GameEnums.WeatherKind) -> void:
	_current = kind
	_target = kind
	_blend = 1.0
	_blend_rate = 0.0
	_publish_kind()
	Events.weather_changed.emit(kind)


## Restrict what can be rolled here. Called by an area when it loads; pass an empty array
## to allow everything again.
func set_allowed(kinds: Array[GameEnums.WeatherKind]) -> void:
	_allowed = kinds
	if not _allowed.is_empty() and not _allowed.has(_target):
		request(_allowed[0])


## The flag that reads true while a kind is the weather. PUBLIC because it is the spelling an
## AUTHOR writes into a quest step, and one nobody should have to rebuild from a header.
func kind_flag(kind: GameEnums.WeatherKind) -> StringName:
	return _kind_flag_named(kind_name(kind))


func _kind_flag_named(key_name: String) -> StringName:
	return StringName("%s%s" % [KIND_PREFIX, key_name.to_lower()])


## IT PUBLISHES `_target`, NOT `_current`, AND THAT IS THE FILE'S OWN EXISTING ANSWER rather than
## a new opinion: `is_wet()` decides whether the player is getting wet from `_target` too, so a
## flag reading `_current` would disagree with the only other question this file already answers
## about "what weather is it". A blend is presentation; the state has already changed.
##
## Erase-then-set, one row at a time, for the reasons `clock.gd._publish_phase` records.
func _publish_kind() -> void:
	var current: StringName = kind_flag(_target)
	for key_name: String in GameEnums.WeatherKind.keys():
		var key: StringName = _kind_flag_named(key_name)
		if key != current:
			Flags.erase_flag(key)
	Flags.set_flag(current, true)


func _on_game_loaded(_slot: int) -> void:
	_publish_kind()


func _roll_next() -> void:
	var options: Array[GameEnums.WeatherKind] = _allowed.duplicate()
	if options.is_empty():
		options = [
			GameEnums.WeatherKind.CLEAR,
			GameEnums.WeatherKind.CLOUDY,
			GameEnums.WeatherKind.OVERCAST,
			GameEnums.WeatherKind.RAIN,
			GameEnums.WeatherKind.FOG,
			GameEnums.WeatherKind.WIND,
		]
	options.erase(_target)
	if options.is_empty():
		_time_left = _rng.randf_range(MIN_SPELL, MAX_SPELL)
		return
	request(options[_rng.randi_range(0, options.size() - 1)])


## Baseline heaviness per kind. Tuned by feel, not physics.
func _base_intensity(kind: GameEnums.WeatherKind) -> float:
	match kind:
		GameEnums.WeatherKind.CLEAR:
			return 0.0
		GameEnums.WeatherKind.CLOUDY:
			return 0.15
		GameEnums.WeatherKind.OVERCAST:
			return 0.35
		GameEnums.WeatherKind.WIND:
			return 0.45
		GameEnums.WeatherKind.FOG:
			return 0.55
		GameEnums.WeatherKind.RAIN:
			return 0.7
		GameEnums.WeatherKind.SNOW:
			return 0.7
		GameEnums.WeatherKind.STORM:
			return 1.0
	return 0.0


func _collect_save() -> Dictionary:
	return {"kind": int(_target)}


func _apply_save(data: Dictionary, _from_version: int) -> void:
	var kind: int = DictRead.get_int(data, "kind", int(GameEnums.WeatherKind.CLEAR))
	var count: int = GameEnums.WeatherKind.keys().size()
	if kind < 0 or kind >= count:
		Log.warn("weather", "Saved weather %d is out of range — defaulting to CLEAR" % kind)
		kind = int(GameEnums.WeatherKind.CLEAR)
	force(kind as GameEnums.WeatherKind)
