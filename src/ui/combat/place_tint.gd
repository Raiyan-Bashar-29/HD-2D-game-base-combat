class_name PlaceTint
extends ColorRect
## A battlefield's place, laid over the view (C10.14). Placeholder look: a see-through colour.
##
## IN PLAIN WORDS: while a battlefield with a `place` stands in the player's fight, the whole view
## is washed with that place's `tint` at `STRENGTH`. When none stands, the wash goes. It redraws
## when a battlefield rises or comes down.
##
## OWNS: the wash.
## MUST NOT: change the fight, or find battlefields itself (`BattlefieldNews` does).

## How strongly the tint washes the view.
const STRENGTH: float = 0.18

## Whose fight is shown; the player when null (tests set it).
var subject: Node


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	Events.battlefield_raised.connect(func(_w: StringName, _p: StringName) -> void: refresh())
	Events.battlefield_lowered.connect(func(_w: StringName, _p: StringName, _b: bool) -> void: refresh())


## Shows the first standing place's tint, or hides.
func refresh() -> void:
	var who: Node = subject if subject != null else Director.player
	var fighter: Combatant = Combatant.of(who) if who != null and is_instance_valid(who) else null
	visible = false
	for run: BattlefieldRun in (BattlefieldNews.standing(fighter) if fighter != null else []):
		var field: BattlefieldMechanism = run.mechanism as BattlefieldMechanism
		if field != null and field.place != null:
			color = Color(field.place.tint.r, field.place.tint.g, field.place.tint.b, STRENGTH)
			visible = true
			return
