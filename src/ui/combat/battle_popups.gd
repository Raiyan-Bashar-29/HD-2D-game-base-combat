class_name BattlePopups
extends Node
## Damage numbers on the battle screen (C10.23). Placeholder look: a `Label`, no art.
##
## IN PLAIN WORDS: while its battle screen is open, each hit on a fighter of that battle floats
## its amount up from beside the fighter's line for `LIFE` seconds of real time, then it goes.
## A critical hit is marked. It hangs on the screen, not on the line, so a redraw of the lines
## does not take it away early.
##
## OWNS: the floating amounts and their life.
## MUST NOT: change the fight, or draw the lines (`BattleReadout` does).

const AMOUNT_KEY: String = "ui.combat.pop.amount"
const CRITICAL_KEY: String = "ui.combat.pop.critical"
const LIFE: float = 0.9
const RISE: float = 40.0

## The screen it draws on.
var screen: BattleScreen
## The amounts up now, each with its age in seconds.
var shown: Dictionary[Label, float] = {}


## Pop-ups for `on`, a battle screen.
static func for_screen(on: BattleScreen) -> BattlePopups:
	var made := BattlePopups.new()
	made.screen = on
	return made


func _ready() -> void:
	Events.combatant_damaged.connect(_on_damaged)


func _process(delta: float) -> void:
	for pop: Label in shown.keys():
		if not is_instance_valid(pop):
			shown.erase(pop)
			continue
		shown[pop] += delta
		pop.position.y -= RISE * delta
		pop.modulate.a = clampf(1.0 - shown[pop] / LIFE, 0.0, 1.0)
		if shown[pop] >= LIFE:
			shown.erase(pop)
			pop.queue_free()


func _on_damaged(who: StringName, _by: StringName, amount: int, critical: bool) -> void:
	if screen == null or screen.battle == null or amount <= 0:
		return
	for fighter: Combatant in screen.battle.party + screen.battle.enemies:
		if is_instance_valid(fighter) and fighter.combatant_id == who:
			_pop(screen.name_of(fighter), tr(CRITICAL_KEY if critical else AMOUNT_KEY).format({"amount": amount}))
			return


func _pop(name: String, text: String) -> void:
	var pop := Label.new()
	pop.text = text
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(pop)
	for line: Node in (screen.rows.get_children() if screen.rows != null else []):
		var label: Label = line as Label
		if label != null and label.text.begins_with(name):
			pop.global_position = label.global_position + Vector2(label.size.x * 0.6, 0.0)
			break
	shown[pop] = 0.0
