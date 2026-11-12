class_name BattlefieldMechanism
extends FormMechanism
## M4, a battlefield (C6.9a): a rule laid over the fight for a while. See `docs/GEAR.md` § Part 3.
##
## IN PLAIN WORDS: a battlefield is a form (M5) that reaches past its caster. Using the power
## raises it and the caster holds `status` while it stands; using it again, its drain running
## dry, its time running out or the caster falling ends it. While it stands, each of `effects`
## changes the fighters of one group: the caster, its side, the other side, or everyone. A domain
## expansion, a reality marble, an aura, weather magic and holy ground are all this with
## different data.
##
## WHERE: `radius` 0 covers the whole fight. Above 0, in the field it covers the fighters within
## that many metres of the caster, and follows the caster as it moves (an aura); a battle has no
## distances, so there it always covers the whole fight.
##
## HOW LONG: `seconds` in the field and `turns` (of the caster's own) in a battle; 0 stands until
## it is ended. The upkeep is the form's drain (`drain_pool` with `drain_per_second`,
## `drain_per_turn` and `drain_per_action`), and its `aftermath` goes on when it ends by its own
## rules, the burnout after a domain. Its `exclusive_group`, `look` and `name_key` work as a
## form's do. A battlefield is never a cycle.
##
## OWNS: the shape of a battlefield.
## MUST NOT: hold running state. `BattlefieldRun` (gameplay) runs it.

## The rules it lays over the fighters, one group each.
@export var effects: Array[BattlefieldEffect] = []
## Metres around the caster it covers in the field. 0: the whole fight.
@export var radius: float = 0.0
## How long it stands in the field. 0: until ended.
@export var seconds: float = 0.0
## How many of the caster's own turns it stands in a battle. 0: until ended.
@export var turns: int = 0


func kind() -> StringName:
	return &"battlefield"


## Every status this battlefield can put on: the form's own, then each effect's, so a held one is
## found again on a load (`PowerKit.status`).
func statuses() -> Array[StatusEffect]:
	var out: Array[StatusEffect] = super.statuses()
	for effect: BattlefieldEffect in effects:
		if effect != null:
			for held: StatusEffect in effect.statuses:
				if held != null:
					out.append(held)
	return out


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = super.problems(context)
	if effects.is_empty():
		found.append("%s is a battlefield with no effects" % context)
	for i: int in effects.size():
		if effects[i] == null:
			found.append("%s has an empty effect %d" % [context, i])
		else:
			found.append_array(effects[i].problems("%s effect %d" % [context, i]))
	if not cycle.is_empty():
		found.append("%s is a battlefield with a cycle" % context)
	if radius < 0.0 or seconds < 0.0 or turns < 0:
		found.append("%s has a negative radius, time or turn count" % context)
	return found
