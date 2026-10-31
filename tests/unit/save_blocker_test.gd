extends TestCase
## Save blockers (T7.2): a moment a game marks unsafe refuses every save, and says why.
##
## IN PLAIN WORDS: a blocker is a callable that returns a reason key, or "" when saving is fine.
## While one answers with a key, `SaveSystem.save_to_slot` writes nothing and returns
## `ERR_UNAVAILABLE`, the autosave skips quietly, and the save screen shows the reason. Loading is
## never refused. Each refusal is proved by the absence of a file, not by the return code alone,
## on `settings_effects_test`'s precedent: a store that returned the code and wrote anyway would
## pass half of this.
##
## OWNS: assertions about `SaveBlockers` through `SaveSystem.blockers`, and the three callers.
## MUST NOT: assert what a save contains; `core_test` owns the round trip.

const SLOT: int = 2
const FIRST: StringName = &"blocker_test_first"
const SECOND: StringName = &"blocker_test_second"
const AREA: StringName = &"blocker_test_area"
const REASON_A: String = "blocker_test.reason_a"
const REASON_B: String = "blocker_test.reason_b"


## A stand-in for whatever system knows the world is mid-something.
class SaveGate:
	extends Node
	var key: String = ""

	func reason() -> String:
		return key


var _saved: Array[int] = []


func run() -> void:
	plan(17)
	SaveFixture.activate()
	# Director's section asks for an area change on load; core_test's precedent.
	SaveSystem.unregister(&"world")
	Events.game_saved.connect(_on_saved)
	_with_no_blocker_saving_is_allowed()
	_a_blocker_with_a_key_refuses_every_save()
	_the_first_key_wins_and_removing_allows_again()
	_a_freed_owner_never_blocks_for_ever()
	_the_autosave_skips_quietly()
	_the_save_screen_tells_the_player_why()
	Events.game_saved.disconnect(_on_saved)
	SaveSystem.delete_slot(SLOT)


func _with_no_blocker_saving_is_allowed() -> void:
	equal("with no blocker nothing refuses", SaveSystem.blockers.refusal(), "")
	equal("and a save writes", SaveSystem.save_to_slot(SLOT), OK)
	SaveSystem.delete_slot(SLOT)
	_saved.clear()


func _a_blocker_with_a_key_refuses_every_save() -> void:
	var gate := SaveGate.new()
	attach(gate)
	SaveSystem.blockers.add(FIRST, gate.reason)
	equal("a blocker answering \"\" refuses nothing", SaveSystem.blockers.refusal(), "")
	gate.key = REASON_A
	equal("answering with a key refuses, and says why", SaveSystem.blockers.refusal(), REASON_A)
	equal("a save is refused as unavailable", SaveSystem.save_to_slot(SLOT), ERR_UNAVAILABLE)
	equal("and no file is written", SaveSystem.has_slot(SLOT), false)
	equal("and game_saved is not announced", _saved.size(), 0)
	# Loading is never refused: write one with the gate open, then load with it shut.
	gate.key = ""
	SaveSystem.save_to_slot(SLOT)
	gate.key = REASON_A
	equal("loading still works while blocked", SaveSystem.load_from_slot(SLOT), OK)
	SaveSystem.delete_slot(SLOT)
	SaveSystem.blockers.remove(FIRST)
	gate.queue_free()


func _the_first_key_wins_and_removing_allows_again() -> void:
	var quiet := SaveGate.new()
	var loud := SaveGate.new()
	attach(quiet)
	attach(loud)
	loud.key = REASON_B
	SaveSystem.blockers.add(FIRST, quiet.reason)
	SaveSystem.blockers.add(SECOND, loud.reason)
	equal("a quiet blocker does not hide a loud one", SaveSystem.blockers.refusal(), REASON_B)
	quiet.key = REASON_A
	equal("of two keys, the first added wins", SaveSystem.blockers.refusal(), REASON_A)
	SaveSystem.blockers.remove(FIRST)
	SaveSystem.blockers.remove(SECOND)
	equal("removing both allows saving again", SaveSystem.blockers.refusal(), "")
	quiet.queue_free()
	loud.queue_free()


func _a_freed_owner_never_blocks_for_ever() -> void:
	var gate := SaveGate.new()
	gate.key = REASON_A
	SaveSystem.blockers.add(FIRST, gate.reason)
	gate.free()
	equal("a blocker whose owner was freed is dropped", SaveSystem.blockers.refusal(), "")
	equal("so saving works again", SaveSystem.save_to_slot(SLOT), OK)
	SaveSystem.delete_slot(SLOT)


func _the_autosave_skips_quietly() -> void:
	var policy := Autosave.new()
	attach(policy)
	var gate := SaveGate.new()
	attach(gate)
	gate.key = REASON_A
	SaveSystem.blockers.add(FIRST, gate.reason)
	var was_area: StringName = Director.current_area_id
	var was_on: bool = Settings.get_bool(Autosave.AUTOSAVE_SETTING)
	Director.current_area_id = AREA
	Settings.set_value(Autosave.AUTOSAVE_SETTING, true)
	equal("the autosave skips while blocked", policy.request(), ERR_SKIP)
	equal("and writes no autosave", SaveSystem.has_slot(SaveSystem.AUTOSAVE_SLOT), false)
	Settings.set_value(Autosave.AUTOSAVE_SETTING, was_on)
	Director.current_area_id = was_area
	SaveSystem.blockers.remove(FIRST)
	gate.queue_free()
	policy.queue_free()


func _the_save_screen_tells_the_player_why() -> void:
	var gate := SaveGate.new()
	attach(gate)
	gate.key = REASON_A
	SaveSystem.blockers.add(FIRST, gate.reason)
	var announced: Array[String] = []
	var args: Array[Dictionary] = []
	var listener: Callable = func(key: String, _seconds: float, with: Dictionary) -> void:
		announced.append(key)
		args.append(with)
	Events.notify_requested.connect(listener)
	var screen := SaveScreen.for_saving()
	screen._write(SLOT)
	Events.notify_requested.disconnect(listener)
	equal("the save screen toasts the refusal, not a failure",
			announced, [SaveScreen.REFUSED_KEY] as Array[String])
	equal("with the blocker's reason in it",
			DictRead.get_string(args[0] if not args.is_empty() else {}, "reason"), tr(REASON_A))
	screen.free()
	SaveSystem.blockers.remove(FIRST)
	gate.queue_free()


func _on_saved(slot: int) -> void:
	_saved.append(slot)
