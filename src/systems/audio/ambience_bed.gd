class_name AmbienceBed
extends Node
## Several environmental sound layers playing at once, each at its own level. One instance,
## created by the Audio autoload and reachable as `Audio.beds`.
##
## WHY LAYERS AND NOT ONE TRACK PER WEATHER
## Weather cross-fades rather than switching, so a single ambience slot would have to cut over
## at some arbitrary point in the blend. Layers let the rain rise while the wind falls, which
## is what a storm arriving actually sounds like, and it costs one player per layer.
##
## WHY THE SOUND IS GENERATED HERE RATHER THAN LOADED
## There is no audio in this project and art is deferred indefinitely, so a bed that needed an
## .ogg would be a bed that is never heard and therefore never verified. Filtered white noise
## IS rain and wind to a first approximation, and it is generated exactly the way the
## placeholder textures are. The moment real recordings exist, `stream_for` is the one
## function that changes.
##
## WHY THERE IS NO TWEEN
## The caller drives this every frame from a value that is already smooth — the weather blend
## is the fade. A tween per call would mean sixty overlapping tweens a second, all fighting
## over one volume_db.
##
## OWNS: one AudioStreamPlayer per named layer, the generated streams, and the levels.
## MUST NOT: know what weather is, or what a layer means. It is told a name and a level.

## Layer name -> how bright its noise is. 1.0 is white; lower values roll the top off, which
## is the difference between rain hissing and wind moaning.
const LAYERS: Dictionary[StringName, float] = {
	&"rain": 0.55,
	&"wind": 0.05,
}
## Below this a layer is stopped outright rather than left running inaudibly.
const SILENT: float = 0.004
## Loop length in seconds. Long enough not to sound like a stutter, short enough that
## generating it costs a few milliseconds at boot.
const LOOP_SECONDS: float = 2.0
const MIX_RATE: int = 22050

var _players: Dictionary[StringName, AudioStreamPlayer] = {}
var _levels: Dictionary[StringName, float] = {}


func _ready() -> void:
	# Ambience must survive a menu, exactly as the music players do. Part of the pause table
	# in src/ui/root/ui_root.gd.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var index: int = 0
	for layer: StringName in LAYERS:
		var brightness: float = LAYERS[layer]
		_build(layer, brightness, index)
		index += 1
	Log.info("audio", "Ambience bed ready: %s" % ", ".join(_names()))


## True when there is a real audio device. `--headless` reports the driver as "Dummy", and
## measured, not assumed: the windowed run reports "WASAPI".
##
## WHY THIS GUARD HAD TO EXIST. Every play() against the Dummy driver queues an
## AudioStreamPlaybackWAV in the AudioServer that is released on the NEXT MIX — and headless
## quits before there is one. The test suite reported exactly one leaked instance per play()
## call, plus the two generated streams they held: six, matching four plays. Stopping the
## players and nulling their streams in _exit_tree does not help, because the AudioServer owns
## the playbacks, not the players. Leak noise at exit is how a real error gets lost, so the bed
## keeps its levels and skips playback it could not be heard through anyway. The levels are the
## real state either way; the assertions read those.
static func is_audible() -> bool:
	return AudioServer.get_driver_name() != "Dummy"


## Hand the generated streams back before the process ends, so nothing outlives the tree.
func _exit_tree() -> void:
	for layer: StringName in _players:
		var player: AudioStreamPlayer = _players[layer]
		player.stop()
		player.stream = null


## Set one layer's loudness, 0.0 silent to 1.0 full. Safe to call every frame.
func set_level(layer: StringName, level: float) -> void:
	var player: AudioStreamPlayer = _player(layer)
	if player == null:
		Log.warn("audio", "No ambience layer named '%s'" % layer)
		return
	var wanted: float = clampf(level, 0.0, 1.0)
	_levels[layer] = wanted
	if wanted <= SILENT:
		if player.playing:
			player.stop()
		return
	player.volume_db = linear_to_db(wanted)
	if not player.playing and is_audible():
		player.play()


## What a layer was last set to. The assertions read this rather than volume_db, because a
## muted bus would make the decibels lie about what was asked for.
func level(layer: StringName) -> float:
	if not _levels.has(layer):
		return 0.0
	var found: float = _levels[layer]
	return found


func is_playing(layer: StringName) -> bool:
	var player: AudioStreamPlayer = _player(layer)
	return player != null and player.playing


func _player(layer: StringName) -> AudioStreamPlayer:
	if not _players.has(layer):
		return null
	return _players[layer]


func _names() -> Array[String]:
	var out: Array[String] = []
	for layer: StringName in _players:
		out.append(String(layer))
	return out


func _build(layer: StringName, brightness: float, salt: int) -> void:
	var player := AudioStreamPlayer.new()
	player.name = "Layer_%s" % layer
	player.bus = "Ambience"
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.stream = stream_for(brightness, salt)
	player.volume_db = -60.0
	add_child(player)
	_players[layer] = player
	_levels[layer] = 0.0


## A looping bed of one-pole low-passed white noise. `brightness` is the filter coefficient:
## 1.0 passes the raw hiss, 0.05 leaves a low rumble. Seeded from `salt` so two layers never
## generate the identical waveform and phase-cancel into something metallic.
static func stream_for(brightness: float, salt: int) -> AudioStreamWAV:
	var count: int = int(MIX_RATE * LOOP_SECONDS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9871 + salt * 5717
	var data := PackedByteArray()
	data.resize(count * 2)
	var filtered: float = 0.0
	var coefficient: float = clampf(brightness, 0.01, 1.0)
	for i: int in count:
		filtered = lerpf(filtered, rng.randf_range(-1.0, 1.0), coefficient)
		# Headroom: the bed sits under music and must never be the loudest thing playing.
		data.encode_s16(i * 2, clampi(roundi(filtered * 9000.0), -32768, 32767))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = count
	return wav
