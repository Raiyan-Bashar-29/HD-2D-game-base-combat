class_name ComboCounter
extends Node
## A fighter's combo (C10.24): how many hits it has landed with no gap longer than `GAP`
## seconds of fight time between them.
##
## IN PLAIN WORDS: each hit its fighter lands (`combatant_damaged` naming it as the attacker) adds
## one; `GAP` seconds with no hit reset it to 0. Each change is announced by `combo_changed`, so
## the HUD shows "Combo 3" without polling. It lives under the body, beside the fighter.
##
## OWNS: the count and its clock.
## MUST NOT: change a hit or reward a combo; a game reads `count` for that.

## Seconds with no landed hit before the count starts again.
const GAP: float = 1.5

var count: int = 0
var _left: float = 0.0


## The counter under `body`, or null.
static func of(body: Node) -> ComboCounter:
	for child: Node in (body.get_children() if body != null else []):
		if child is ComboCounter:
			return child as ComboCounter
	return null


func _ready() -> void:
	Events.combatant_damaged.connect(_on_damaged)


func _physics_process(delta: float) -> void:
	pass_time(CombatClock.scaled(delta))


## `seconds` of fight time pass; past the gap the count starts again.
func pass_time(seconds: float) -> void:
	if count == 0:
		return
	_left -= seconds
	if _left <= 0.0:
		count = 0
		Events.combo_changed.emit(_id(), count)


func _on_damaged(_who: StringName, by: StringName, amount: int, _critical: bool) -> void:
	if amount <= 0 or by == &"" or by != _id():
		return
	count += 1
	_left = GAP
	Events.combo_changed.emit(by, count)


func _id() -> StringName:
	var fighter: Combatant = Combatant.of(get_parent())
	return fighter.combatant_id if fighter != null else &""
