extends TestCase
## Music ducking: how far down it goes, that it is a fade, that the count balances, and that
## the running game is actually wired to it.
##
## WHY THIS CASE CAN PROVE MORE THAN T5.7's AND T5.9's CAMERA WORK COULD. Gotcha 2 says
## `--headless` shades nothing, so a look is a look and only a windowed capture carries it. A
## BUS VOLUME IS NOT A LOOK: the audio server hands back a number in decibels even under the
## dummy driver this run uses, so the whole of this feature — the level, the timing and the
## balance — is a measurement here rather than a photograph. `AmbienceBed.is_audible()` is
## already `false` in this run and that changes none of it.
##
## AND THE FADE IS STEPPED, NOT WAITED FOR. `run()` is synchronous, so no idle frame ever
## arrives and a tween left alone never moves — which is exactly the trap T5.7 wrote down: a
## finished fade and an instant cut read the same, and what distinguishes them is the frames
## between. `SceneTree.get_processed_tweens()` and `Tween.custom_step()` give those frames
## back, so "the bus has NOT moved yet" and "half the fade is half the drop" are both
## assertable, and a duck rewritten as a cut fails here.
##
## OWNS: assertions about the duck — its level, its shape in time, its balance across
## overlapping conversations, and the wire from `Events.dialogue_started` to the mixer.
## MUST NOT: assert what a conversation says or how it branches, which is `dialogue_test.gd`,
## or how the volume settings themselves reach the buses, which is `settings_effects_test.gd`.

const GAME_ROOT: String = "res://scenes/boot/game_root.tscn"
const DUCK_SCRIPT: String = "res://src/systems/audio/dialogue_duck.gd"
const MUSIC_SETTING: String = "audio/music"
const AMBIENCE_SETTING: String = "audio/ambience"
const SFX_SETTING: String = "audio/sfx"
## The fixture conversation, so the end-to-end drive names no demo content and survives a
## stripped template.
const TALK: StringName = FixtureContent.TALK

var _duck: DialogueDuck = null


func run() -> void:
	plan(37)
	_set_up()
	_a_duck_is_relative_to_the_players_own_volume()
	_a_duck_is_a_fade_and_not_a_cut()
	_a_volume_change_mid_duck_does_not_lift_the_duck()
	_the_count_balances_across_overlapping_conversations()
	_a_real_conversation_ducks_and_releases()
	_the_running_game_has_one_and_it_is_wired()
	_the_alias_with_no_caller_is_gone()
	_tear_down()


func _set_up() -> void:
	Settings.reset_to_defaults()
	Audio.unduck(0.0)
	_duck = DialogueDuck.new()
	_duck.name = "TestDialogueDuck"
	attach(_duck)


## THE DEFECT THIS ROW WAS REALLY ABOUT. `duck()` tweened to an ABSOLUTE -8 dB, which against
## a player who had turned music down was not a duck at all but a BOOST — the same call making
## the music quieter or louder depending on a slider. Every assertion here is against the level
## the player's own setting puts the bus at.
func _a_duck_is_relative_to_the_players_own_volume() -> void:
	Settings.set_value(MUSIC_SETTING, 1.0)
	equal("at full volume the music bus sits at 0 dB",
			is_equal_approx(Audio.target_db("Music"), 0.0), true)
	Audio.duck()
	equal("and a duck drops it by the whole offset",
			is_equal_approx(Audio.target_db("Music"), Audio.DUCK_DB), true)

	# 0.25 linear is about -12 dB, so the old absolute -8 dB target was FOUR DECIBELS ABOVE
	# where the player had put the music. This is the assertion that reversion fails.
	Settings.set_value(MUSIC_SETTING, 0.25)
	var quiet: float = linear_to_db(0.25)
	equal("a quieter setting carries the ducked level down with it",
			is_equal_approx(Audio.target_db("Music"), quiet + Audio.DUCK_DB), true)
	equal("AND THE DUCK IS STILL DOWNWARD, which an absolute target was not",
			Audio.target_db("Music") < quiet, true)

	Settings.set_value(MUSIC_SETTING, 0.0)
	equal("a bus the player muted stays muted while ducked",
			is_equal_approx(Audio.target_db("Music"), -80.0), true)

	equal("a bus outside DUCKED_BUSES is not moved by a duck at all",
			is_equal_approx(Audio.target_db("SFX"), linear_to_db(Settings.get_float(SFX_SETTING))),
			true)

	Settings.set_value(MUSIC_SETTING, 1.0)
	Audio.duck(4.0)
	equal("and a POSITIVE duck cannot make the music louder than the player asked",
			is_equal_approx(Audio.target_db("Music"), 0.0), true)
	Audio.unduck()
	equal("unducking puts the target back on the settings level",
			is_equal_approx(Audio.target_db("Music"), 0.0), true)


## The half no return code can carry: a duck that arrived instantly would satisfy every level
## assertion above. `run()` never sees an idle frame, so the tweens are stepped by hand.
func _a_duck_is_a_fade_and_not_a_cut() -> void:
	Settings.set_value(MUSIC_SETTING, 1.0)
	Settings.set_value(AMBIENCE_SETTING, 1.0)
	var before: Array[Tween] = get_tree().get_processed_tweens()
	Audio.duck()
	equal("the bus has NOT moved yet, because a duck is a fade and not a cut",
			is_equal_approx(_bus_db("Music"), 0.0), true)
	_step(before, Audio.DUCK_SECONDS * 0.5)
	equal("half the fade is half the drop",
			is_equal_approx(_bus_db("Music"), Audio.DUCK_DB * 0.5), true)
	_step(before, Audio.DUCK_SECONDS)
	equal("and the whole fade lands exactly on the target",
			is_equal_approx(_bus_db("Music"), Audio.DUCK_DB), true)
	equal("the ambience bed goes down with the music",
			is_equal_approx(_bus_db("Ambience"), Audio.DUCK_DB), true)

	before = get_tree().get_processed_tweens()
	Audio.unduck()
	equal("and it comes back up over time too", is_equal_approx(_bus_db("Music"),
			Audio.DUCK_DB), true)
	_step(before, Audio.RESTORE_SECONDS)
	equal("landing where the player's own setting says", is_equal_approx(_bus_db("Music"), 0.0),
			true)


## `_apply_all_volumes` answers every settings change by re-applying every bus, so it is the
## one thing in the file that can cancel a duck nobody asked it to cancel. It goes through
## `target_db`, and this is what says so.
func _a_volume_change_mid_duck_does_not_lift_the_duck() -> void:
	Settings.set_value(MUSIC_SETTING, 1.0)
	var before: Array[Tween] = get_tree().get_processed_tweens()
	Audio.duck()
	_step(before, Audio.DUCK_SECONDS)
	var half: float = linear_to_db(0.5)
	Settings.set_value(MUSIC_SETTING, 0.5)
	equal("moving the slider mid-duck lands on the DUCKED level",
			is_equal_approx(_bus_db("Music"), half + Audio.DUCK_DB), true)
	equal("and not on the un-ducked one", _bus_db("Music") < half, true)
	before = get_tree().get_processed_tweens()
	Audio.unduck()
	_step(before, Audio.RESTORE_SECONDS)
	equal("and letting go afterwards returns to the new setting, not the old one",
			is_equal_approx(_bus_db("Music"), half), true)
	Settings.set_value(MUSIC_SETTING, 1.0)


## THE FAILURE THE COUNT EXISTS FOR. Two conversations overlap — an NPC talking to another NPC
## while the player reads a sign — and a plain duck/unduck pair lifts the music back up on the
## FIRST ending, underneath a conversation still running. Nothing would be red.
func _the_count_balances_across_overlapping_conversations() -> void:
	Settings.set_value(MUSIC_SETTING, 1.0)
	var before: Array[Tween] = get_tree().get_processed_tweens()
	equal("nothing is holding the music down to begin with", _duck.held(), 0)
	Events.dialogue_started.emit(&"first")
	equal("one conversation holds it", _duck.held(), 1)
	_step(before, Audio.DUCK_SECONDS)
	equal("and the music is down", is_equal_approx(_bus_db("Music"), Audio.DUCK_DB), true)

	Events.dialogue_started.emit(&"second")
	equal("a second conversation holds it too", _duck.held(), 2)
	before = get_tree().get_processed_tweens()
	Events.dialogue_finished.emit(&"first")
	equal("and one of them ending releases only its own hold", _duck.held(), 1)
	_step(before, Audio.RESTORE_SECONDS)
	equal("SO THE MUSIC IS STILL DOWN, with somebody still talking",
			is_equal_approx(_bus_db("Music"), Audio.DUCK_DB), true)

	before = get_tree().get_processed_tweens()
	Events.dialogue_finished.emit(&"second")
	equal("the last one ending releases the duck", _duck.held(), 0)
	_step(before, Audio.RESTORE_SECONDS)
	equal("and the music comes back", is_equal_approx(_bus_db("Music"), 0.0), true)

	Events.dialogue_finished.emit(&"never started")
	equal("a stray end cannot drive the count negative and strand the music down",
			_duck.held(), 0)


## THE WIRE, END TO END, THROUGH THE REAL RUNNER — gotcha 54. Everything above emits the
## signals by hand, so all of it would stay green in a repository where `DialogueRunner` had
## stopped announcing itself. This drives a real fixture conversation instead.
func _a_real_conversation_ducks_and_releases() -> void:
	Flags.clear_all()
	equal("the fixture content is on disk for the registry to find", Fixtures.activate(), true)
	var runner := DialogueRunner.new()
	runner.name = "DuckTestRunner"
	attach(runner)
	Settings.set_value(MUSIC_SETTING, 1.0)
	var before: Array[Tween] = get_tree().get_processed_tweens()
	equal("a real conversation begins", runner.begin(TALK), true)
	equal("which is a hold on the music by itself", _duck.held(), 1)
	_step(before, Audio.DUCK_SECONDS)
	equal("and the mixer is down because somebody spoke, not because a test emitted",
			is_equal_approx(_bus_db("Music"), Audio.DUCK_DB), true)
	before = get_tree().get_processed_tweens()
	runner.stop()
	equal("ending it releases the hold", _duck.held(), 0)
	_step(before, Audio.RESTORE_SECONDS)
	equal("and the music comes back up", is_equal_approx(_bus_db("Music"), 0.0), true)
	Fixtures.deactivate()
	DialogueDb.rescan()
	Flags.clear_all()


## The other half of gotcha 54: every assertion above builds its own `DialogueDuck`, so all of
## it stays green in a checkout where the running game instances none and the music never ducks
## for anybody. `game_root.tscn` is the only place a real session gets one from, and it is read
## through `SceneState` rather than as text — gotcha 56.
func _the_running_game_has_one_and_it_is_wired() -> void:
	equal("the running game has a DialogueDuck under the root",
			parent_of_script(GAME_ROOT, DUCK_SCRIPT), ".")
	equal("one in the tree is listening for a conversation starting",
			Events.dialogue_started.is_connected(_duck._on_dialogue_started), true)
	equal("and for one ending",
			Events.dialogue_finished.is_connected(_duck._on_dialogue_finished), true)


## `stop_music()` was `play_music(null)` under a second name, with no caller anywhere in three
## phases. It was deleted rather than wired, and the version this landed in is MAJOR because of
## it — so the deletion is asserted, the way `_there_is_no_jump_action` asserts its own.
func _the_alias_with_no_caller_is_gone() -> void:
	equal("the stop_music alias is gone", Audio.has_method("stop_music"), false)
	equal("and the one spelling that stops the music is still there",
			Audio.has_method("play_music"), true)


## The bus level as the audio server actually holds it, which is the measurement this whole
## case rests on and is available under the dummy driver.
func _bus_db(bus_name: String) -> float:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		return 0.0
	return AudioServer.get_bus_volume_db(index)


## Advance every tween that did not exist before the call under test, by `seconds`. The
## snapshot matters: stepping tweens some other system started would move state this case does
## not own, and a screen fade or a music cross-fade is often mid-flight when the suite runs.
func _step(before: Array[Tween], seconds: float) -> void:
	for tween: Tween in get_tree().get_processed_tweens():
		if before.has(tween):
			continue
		tween.custom_step(seconds)


func _tear_down() -> void:
	Audio.unduck(0.0)
	if _duck != null:
		_duck.queue_free()
		_duck = null
	Settings.reset_to_defaults()
