class_name BattleTiming
extends Node
## A timed hit on the battle screen (C10.31), as in the Mario RPGs or Sea of Stars.
##
## IN PLAIN WORDS: when a member uses a skill with a `prompt`, the menu steps aside and a line says
## "Ready..."; once the window opens it says "Now!". A press (accept or attack) grows the skill by
## the window's grade: its perfect bonus in the centre, its bonus in the window, nothing outside.
## No press by the time the window has closed lands it plain. The grade is announced
## (`prompt_graded`). Only the player's turns are timed; AI turns never wait. With the
## hold-to-attack setting on, nothing is timed.
##
## OWNS: the wait for the press and its grade.
## MUST NOT: change how the skill lands beyond `SkillUse.timed`, or time a turn nobody plays.

const READY_KEY: String = "ui.battle.timing.ready"
const NOW_KEY: String = "ui.battle.timing.now"
## Seconds after the window closes before it lands plain.
const GRACE: float = 0.2

var screen: BattleScreen
var command: BattleCommand
var targets: Array[Combatant] = []
var elapsed: float = 0.0
var _cue: Label


## True when `command` waits for a timed press: its skill has a prompt, and hold-to-attack is off.
static func wants(command: BattleCommand) -> bool:
	return command != null and command.skill != null and command.skill.prompt != null \
			and not CombatSettings.is_on(CombatSettings.HOLD_TO_ATTACK)


## A wait for the press on `on`, for `chosen` aimed at `aimed`. The menu steps aside meanwhile.
static func begin(on: BattleScreen, chosen: BattleCommand, aimed: Array[Combatant]) -> BattleTiming:
	var made := BattleTiming.new()
	made.screen = on
	made.command = chosen
	made.targets = aimed
	made._cue = on.add_note(TranslationServer.translate(READY_KEY))
	if on.rows != null:
		for row: Node in on.rows.get_children():
			if row is Button:
				(row as Button).disabled = true
	return made


func _process(delta: float) -> void:
	step(delta)


## `seconds` of real time pass; past the window, it lands plain.
func step(seconds: float) -> void:
	elapsed += seconds
	var window: TimedWindow = command.skill.prompt
	if is_instance_valid(_cue):
		_cue.text = tr(NOW_KEY if window.inside(elapsed) else READY_KEY)
	if elapsed > window.closes + GRACE:
		_finish(window.grade(elapsed), 1.0)


## The player pressed: the skill lands graded by when.
func press() -> void:
	var window: TimedWindow = command.skill.prompt
	_finish(window.grade(elapsed), window.multiplier(elapsed))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept") or Actions.pressed_now(event, CombatActions.ATTACK):
		get_viewport().set_input_as_handled()
		press()


func _finish(grade: StringName, grown: float) -> void:
	if is_queued_for_deletion():
		return
	var actor: Combatant = screen.battle.current()
	if actor != null:
		Events.prompt_graded.emit(actor.combatant_id, grade)
	SkillUse.timed = grown
	screen.act_now(command, targets)
	SkillUse.timed = 1.0
	queue_free()
