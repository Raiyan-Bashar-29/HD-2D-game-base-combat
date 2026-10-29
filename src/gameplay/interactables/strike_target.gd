class_name StrikeTarget
extends Interactable
## Something the player hits by interacting with it: a training dummy, a gong, a cracked wall.
## The smallest proof that the combat core runs in the field, with no battle around it.
##
## THE TARGET IS A `Combatant` CHILD, NOT A FIELD HERE. Its id, its faction, its base stats and
## its `Vitals` are authored on the scene, exactly as an enemy's would be, so this class adds the
## one thing a combatant cannot do by itself: be offered as an interaction.
##
## AN ATTACKER WITH NO `Combatant` STILL HITS. Whoever interacts is asked for its `Combatant`, and
## its sheet and formula resolve the hit. An actor with none (the template's player has none)
## strikes with an empty sheet through the target's own formula, so `power` alone decides the hit.
##
## OWNS: offering the strike, resolving it, the result toast and the optional revive.
## MUST NOT: choose turns or timing, know what defeat means beyond reviving, or drive the UI. It
## asks for a toast by key, as `Readable` does.

## The hit's base power, before the formula's stages.
@export var power: float = 5.0
## An element for the element stage; empty for none.
@export var element: StringName = &""
## Toast after a hit, a localization key. Placeholders: `{amount}`, `{left}`, `{max}`.
@export var struck_key: String = ""
## Toast after a critical hit, when set. The same placeholders.
@export var critical_key: String = ""
## A training dummy stands back up: on defeat, revive to full. Off, a defeated target is refused.
@export var revive_when_defeated: bool = false
@export var toast_seconds: float = 2.5

const AMOUNT_ARG: String = "amount"
const LEFT_ARG: String = "left"
const MAX_ARG: String = "max"

## Seeded randomly. A test seeds it to make a hit repeatable.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	verb = GameEnums.InteractVerb.USE
	super()
	rng.randomize()
	if target() == null:
		Log.warn("interact", "%s is a strike target with no Combatant child" % name)


## The combatant this object is. Null when the scene forgot one, and then nothing is offered.
func target() -> Combatant:
	return Combatant.of(self)


func is_offerable() -> bool:
	return super() and target() != null


func refusal(_who: Node3D) -> GameEnums.RefusalReason:
	var vitals: Vitals = Vitals.of(self)
	if vitals != null and vitals.is_defeated() and not revive_when_defeated:
		return GameEnums.RefusalReason.ALREADY_DONE
	return GameEnums.RefusalReason.NONE


func perform(who: Node3D) -> void:
	var into: Combatant = target()
	var attacker: Combatant = Combatant.of(who)
	var result: DamageResult
	if attacker != null:
		result = attacker.hit(into, power, element, rng)
	else:
		result = into.resolving_formula().resolve(DamageRequest.of(StatSheet.new(), into.sheet, power, element), rng)
		into.receive(result, &"")
	var vitals: Vitals = Vitals.of(self)
	if vitals == null or result == null:
		return
	var pool: StringName = into.damage_pool
	var args: Dictionary = {AMOUNT_ARG: result.total(), LEFT_ARG: vitals.current(pool),
			MAX_ARG: vitals.maximum(pool)}
	var key: String = critical_key if result.critical and critical_key != "" else struck_key
	if key != "":
		Events.notify_requested.emit(key, toast_seconds, args)
	if revive_when_defeated and vitals.is_defeated():
		vitals.revive(vitals.maximum(vitals.defeat_pool))
