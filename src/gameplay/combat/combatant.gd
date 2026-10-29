class_name Combatant
extends Node
## Makes any actor combat-capable by composition: one id, one faction, one sheet shared by its
## `Vitals` and `StatusSet` siblings, and the formula its own hits resolve through.
##
## ADD IT BESIDE A `Vitals` (and a `StatusSet`, if statuses apply) under the actor. On ready it
## hands both its sheet and its id, so a status's modifier changes the same maximum that `Vitals`
## clamps to, and every signal names the same `who`. Nothing about the actor itself changes.
##
## THE ATTACKER'S FORMULA RESOLVES THE HIT. `hit` builds the request from both sheets, resolves it
## through this combatant's `formula` with the caller's seeded `rng`, and hands the RESULT to the
## target's `receive`. A defender never re-resolves, so a preview and the real hit agree.
##
## OWNS: the combatant id, the faction, the shared sheet, and applying a resolved hit.
## MUST NOT: choose targets, decide turns or timing, or decide what defeat means.

@export var combatant_id: StringName = &"player"
@export var faction: StringName = &"player"
## Null means `DamageFormula.standard()`.
@export var formula: DamageFormula
## Null means the default rule: the same faction allied, different factions hostile.
@export var factions: FactionTable
## The pool a hit lowers.
@export var damage_pool: StringName = &"hp"

var sheet: StatSheet = StatSheet.new()


func _ready() -> void:
	var vitals: Vitals = Vitals.of(get_parent())
	if vitals != null:
		vitals.sheet = sheet
		vitals.owner_id = combatant_id
	var statuses: StatusSet = StatusSet.of(get_parent())
	if statuses != null:
		statuses.sheet = sheet
		statuses.owner_id = combatant_id


static func of(who: Node) -> Combatant:
	if who == null:
		return null
	for child: Node in who.get_children():
		var found: Combatant = child as Combatant
		if found != null:
			return found
	return null


func can_target(other: Combatant, filter: FactionTable.Target) -> bool:
	if other == null:
		return false
	var table: FactionTable = factions if factions != null else FactionTable.new()
	return table.allows(filter, combatant_id, faction, other.combatant_id, other.faction)


## Resolves one hit on `target` and applies it. Null when there is nobody to hit.
func hit(target: Combatant, power: float, element: StringName,
		rng: RandomNumberGenerator) -> DamageResult:
	if target == null:
		return null
	var using: DamageFormula = formula if formula != null else DamageFormula.standard()
	var result: DamageResult = using.resolve(DamageRequest.of(sheet, target.sheet, power, element), rng)
	target.receive(result, combatant_id)
	return result


## Applies a resolved hit and announces it. A defeated combatant takes nothing and says nothing;
## a negative total heals (an absorbed element). Returns the pool's change.
func receive(result: DamageResult, from: StringName) -> int:
	var vitals: Vitals = Vitals.of(get_parent())
	if result == null or vitals == null or vitals.is_defeated():
		return 0
	var before: int = vitals.current(damage_pool)
	var after: int = vitals.change(damage_pool, -result.total())
	Events.combatant_damaged.emit(combatant_id, from, result.total(), result.critical)
	return after - before
