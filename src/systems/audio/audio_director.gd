extends Node
## Music and ambience playback, and the mixer layout. Autoload `Audio`.
##
## WHY THE BUSES ARE BUILT IN CODE
## A bus layout is normally a binary .tres that nobody can read in a diff and everybody is
## afraid to touch. Four buses declared here are readable, and the volume settings wire
## straight onto them by name.
##
## OWNS: the bus layout, the music player pair, the ambience player, applying volume settings
## to buses, and how far below those settings a duck sits.
## MUST NOT: own positional sound. A creaking door owns its own AudioStreamPlayer3D, because
## the sound belongs to the door and should die with it. Routing a world sound through a
## global singleton is how you end up with a footstep playing after the character is gone.
## MUST NOT decide WHEN to duck either — that is an occasion, and an occasion is a fact about
## the running game. `DialogueDuck` owns the one this template has, for the same reason
## `Autosave` owns the occasion to save while `SaveSystem` owns only the format.
##
## NOTE ON ASSETS: there is no audio in the project yet. Every method here accepts null and
## does nothing gracefully, so the system is complete and testable before a single .ogg
## exists. That is deliberate, not unfinished. A bus volume in dB, on the other hand, is a
## number the audio server hands back even under the dummy driver — which is why the ducking
## below is asserted in the suite rather than only described.

const BUSES: Array[String] = ["Music", "Ambience", "SFX", "UI"]
const DEFAULT_FADE: float = 1.5
## Below this, a bus is muted outright rather than left at an inaudible level.
const SILENCE_THRESHOLD: float = 0.001

## How far a duck drops the buses below wherever the player's own volume settings put them,
## and how long each leg of the move takes. Down fast and back up slower: a duck that returns
## as quickly as it fell reads as a glitch rather than as the music stepping aside.
const DUCK_DB: float = -8.0
const DUCK_SECONDS: float = 0.4
const RESTORE_SECONDS: float = 0.6
## The buses a duck moves. SFX and UI are deliberately NOT among them: ducking exists so that
## something else can be heard over the bed, and that something is almost always a sound
## effect or a UI sound. Taking those down too would move the whole mix and reveal nothing.
const DUCKED_BUSES: Array[String] = ["Music", "Ambience"]

var _music_a: AudioStreamPlayer = null
var _music_b: AudioStreamPlayer = null
var _music_active_is_a: bool = true
var _ambience: AudioStreamPlayer = null
var _current_music_path: String = ""
## The offset in force right now: 0.0 when nothing is ducking, negative while something is.
## Held as STATE and not only as a tween target, because a volume slider moved while the duck
## is down re-applies every bus and would otherwise lift the duck with nothing asking it to.
var _duck_db: float = 0.0
## The moves the current duck or unduck is making, so the next one can cancel them. Two tweens
## racing on one bus is how a duck ends up resolving to whichever of them finished last.
var _fades: Array[Tween] = []

## The layered environmental bed, for anything that needs more than one sound at once —
## weather is the first caller. Kept as a child object rather than more methods here, because
## a mixer that grows a layer per effect is a file that grows without limit.
var beds: AmbienceBed = null


func _ready() -> void:
	# The players below already opt out of pause individually, but the cross-fade tweens are
	# created on THIS node and would stall with it - so a track started just before a menu
	# opened would hang at -60 dB until the menu closed. Part of the pause table in
	# src/ui/root/ui_root.gd.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_music_a = _make_player("Music", "MusicA")
	_music_b = _make_player("Music", "MusicB")
	_ambience = _make_player("Ambience", "Ambience")
	beds = AmbienceBed.new()
	beds.name = "Beds"
	add_child(beds)
	Events.setting_changed.connect(_on_setting_changed)
	_apply_all_volumes()
	Log.info("audio", "Buses ready: Master + %s" % ", ".join(BUSES))


## Cross-fade to a new music track. Passing null fades out to silence — which is also how the
## music is STOPPED, and now the only way: a `stop_music()` alias stood beside this for three
## phases with no caller anywhere in the repository. Two spellings of one operation in a file
## with a hard 150-line budget is a cost with nothing on the other side of it.
##
## Requesting the track that is already playing does nothing, so an area re-entry does not
## restart the music from the top.
func play_music(stream: AudioStream, fade: float = DEFAULT_FADE) -> void:
	var path: String = stream.resource_path if stream != null else ""
	if path == _current_music_path and path != "":
		return
	_current_music_path = path

	var incoming: AudioStreamPlayer = _music_b if _music_active_is_a else _music_a
	var outgoing: AudioStreamPlayer = _music_a if _music_active_is_a else _music_b
	_music_active_is_a = not _music_active_is_a

	if stream != null:
		incoming.stream = stream
		incoming.volume_db = -60.0
		incoming.play()
		_fade_to(incoming, 0.0, fade)
	if outgoing.playing:
		_fade_to(outgoing, -60.0, fade, true)
	Log.debug("audio", "Music -> %s" % (path if path != "" else "(silence)"))


## Ambience is the environmental bed: wind, birds, rain. It layers under music.
func play_ambience(stream: AudioStream, fade: float = DEFAULT_FADE) -> void:
	if _ambience.stream == stream:
		return
	if stream == null:
		_fade_to(_ambience, -60.0, fade, true)
		return
	_ambience.stream = stream
	_ambience.volume_db = -60.0
	_ambience.play()
	_fade_to(_ambience, 0.0, fade)


## Duck music and ambience, for dialogue and for cutscene emphasis. Idempotent: ducking while
## already ducked re-aims at the same place rather than stacking a second drop on top.
func duck(amount_db: float = DUCK_DB, seconds: float = DUCK_SECONDS) -> void:
	# Clamped at zero because a POSITIVE "duck" is a request to make the music louder than the
	# player asked for, and no caller gets to do that through this door.
	_duck_db = minf(amount_db, 0.0)
	_move_buses(seconds)


## Undo duck() by re-reading the settings, so it cannot drift out of sync with the mixer.
func unduck(seconds: float = RESTORE_SECONDS) -> void:
	_duck_db = 0.0
	_move_buses(seconds)


## Where a bus should sit RIGHT NOW: the level the player's own volume setting puts it at,
## plus whatever duck is in force.
##
## RELATIVE, AND THAT IS THE WHOLE POINT OF THIS METHOD. `duck()` used to tween to an ABSOLUTE
## -8 dB, which is not a duck at all — it is "set the music to -8 dB". Against a player who had
## turned music down to 0.25 (-12 dB) it made the music LOUDER by four decibels every time
## somebody spoke; against the default 1.0 it ducked by eight. One call, two opposite effects,
## chosen by a slider on the options screen. The muted case is the same rule from the other
## end: nothing here may lift a bus the player set to zero.
func target_db(bus_name: String) -> float:
	var base: float = _db_for_bus(bus_name)
	if base <= -80.0 or not DUCKED_BUSES.has(bus_name):
		return base
	return base + _duck_db


## Create the buses if they are not already present, each routed to Master.
func _ensure_buses() -> void:
	for bus_name: String in BUSES:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		var index: int = AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")


func _make_player(bus_name: String, node_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.bus = bus_name
	# Music and ambience must keep playing while the game is paused in a menu.
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player


## Slide the ducked buses to wherever `target_db` now says, cancelling any move still running.
func _move_buses(seconds: float) -> void:
	for running: Tween in _fades:
		if running.is_valid():
			running.kill()
	_fades.clear()
	for bus_name: String in DUCKED_BUSES:
		var index: int = AudioServer.get_bus_index(bus_name)
		if index < 0:
			continue
		var tween: Tween = create_tween()
		tween.tween_method(_set_bus_db.bind(index), AudioServer.get_bus_volume_db(index),
				target_db(bus_name), maxf(0.01, seconds))
		_fades.append(tween)


func _fade_to(player: AudioStreamPlayer, target: float, seconds: float, stop_after: bool = false) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", target, maxf(0.01, seconds))
	if stop_after:
		tween.tween_callback(player.stop)


## THROUGH `target_db` AND NOT `_db_for_bus`, so a volume slider moved mid-duck lands on the
## ducked level rather than lifting the duck. Answering the settings change is right; the duck
## is not the settings' to cancel.
func _apply_all_volumes() -> void:
	_set_named_bus("Master", target_db("Master"))
	for bus_name: String in BUSES:
		_set_named_bus(bus_name, target_db(bus_name))


## Map a bus to its setting. Master is special-cased because its setting is "audio/master".
func _db_for_bus(bus_name: String) -> float:
	var linear: float = Settings.get_float("audio/%s" % bus_name.to_lower())
	if linear <= SILENCE_THRESHOLD:
		return -80.0
	return linear_to_db(linear)


func _set_named_bus(bus_name: String, db: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, db)
	AudioServer.set_bus_mute(index, db <= -80.0)


func _set_bus_db(db: float, index: int) -> void:
	AudioServer.set_bus_volume_db(index, db)


func _on_setting_changed(section: String, _key: String, _value: Variant) -> void:
	if section == "audio":
		_apply_all_volumes()
