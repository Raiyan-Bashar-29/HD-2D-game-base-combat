class_name Combatant
extends Node
## Makes any actor combat-capable by composition: one id, one faction, one sheet shared by its
## `Vitals` and `StatusSet` siblings, and the formula its own hits resolve through.
##
## ADD IT BESIDE A `Vitals` (and a `StatusSet`, if statuses apply) under the actor. On ready it
## hands both its sheet and its id, so a status's modifier changes the same maximum that `Vitals`
## clamps to, and every signal names the same `who`. Nothing about the actor itself changes.
##
## A BARRIER STEPS IN BEFORE THE HIT LANDS (C6.6a). `receive` hands the resolved hit to
## `PowerGuard.incoming`, the one hook the hero powers have in the damage path: a barrier may bring
## it to nothing, make it smaller, or drink its element. A hit stopped whole is announced as
## `attack_blocked` and changes nothing (C6.6b).
##
## THE ATTACKER'S FORMULA RESOLVES THE HIT. `hit` builds the request from both sheets, resolves it
## through this combatant's `formula` with the caller's seeded `rng`, and hands the RESULT to the
## target's `receive`. A defender never re-resolves, so a preview and the real hit agree.
##
## WHAT WORN GEAR LENDS (C7.1c). A worn weapon can give the plain attack an element and extra
## weakness tags. The worn set writes them into `lent_element` and `lent_tags`; this node does
## not know what gear is. Whoever resolves a plain attack asks `strike_element` and `strike_tags`.
## A worn weapon's field chain (C7.3b) is written into `lent_moves`; `field_moves` lays it over the
## fighter's own: the weapon's chain, its dodge if it has one, and the fighter's own skills.
##
## EVERY COMBATANT IS IN THE GROUP `GROUP`, so `find` can turn an id from an event back into
## its fighter (C6.4b: a kit gauge asks whether the one who fell was an ally).
##
## OWNS: the combatant id, the faction, the shared sheet, and applying a resolved hit.
## MUST NOT: choose targets, decide turns or timing, or decide what defeat means.

## The group every combatant joins, for `find`.
const GROUP: StringName = &"combatants"

@export var combatant_id: StringName = &"player"
@export var faction: StringName = &"player"
## Null means `DamageFormula.standard()`.
@export var formula: DamageFormula
## Null means the default rule: the same faction allied, different factions hostile.
@export var factions: FactionTable
## The pool a hit lowers.
@export var damage_pool: StringName = &"hp"
## The sheet's base values, authored on the actor: `max_hp`, `attack`, `defence` and the rest.
## Copied into the sheet on ready, so an actor scene is combat-ready with no code. Modifiers from
## equipment and statuses still layer on top.
@export var base_stats: Dictionary[StringName, float] = {}
## WEAKNESS AND BREAK (C2.17). What this fighter is weak to: elements or skill tags. A landed
## hit matching one takes a point from its `shield` pool (`Weakness`).
@export var weak_to: Array[StringName] = []
## What this fighter's plain ATTACK counts as for weaknesses, such as `sword`.
@export var attack_tags: Array[StringName] = []
## Which kind of fighter this is, shared by every copy (two wisps are both `wisp`), so a
## revealed weakness shows on all of them. Empty means the combatant id.
@export var kind: StringName = &""

## True when this fighter lives in real time, so its statuses count in seconds (C4.6). Set by
## whoever builds a field fighter (`ActionHost.equip`, `ActionEnemy`); a battle builds fresh
## combatants, which stay false. `Weakness` reads it to choose a break in turns or in seconds.
var real_time: bool = false
## The element worn gear gives this fighter's plain attack. Written by `GearSet`.
var lent_element: StringName = &""
## The weakness tags worn gear adds to this fighter's plain attack. Written by `GearSet`.
var lent_tags: Array[StringName] = []
## The field moves worn gear gives this fighter, or null. Written by `GearSet` (C7.3b).
var lent_moves: MoveSet
var sheet: StatSheet = StatSheet.new()
# The last `field_moves` built, and what it was built from.
var _merged: MoveSet
var _merged_own: MoveSet
var _merged_lent: MoveSet


func _ready() -> void:
	add_to_group(GROUP)
	for stat: StringName in base_stats:
		sheet.set_base(stat, base_stats[stat])
	var vitals: Vitals = Vitals.of(get_parent())
	if vitals != null:
		vitals.sheet = sheet
		vitals.owner_id = combatant_id
	var statuses: StatusSet = StatusSet.of(get_parent())
	if statuses != null:
		statuses.sheet = sheet
		statuses.owner_id = combatant_id
		# A set left at the default save id would collide with every other fighter left at it,
		# so it is given one named after this combatant instead (C2.12).
		if statuses.save_id == StatusSet.DEFAULT_SAVE_ID and combatant_id != &"player":
			statuses.rename_save(StringName("statuses/" + String(combatant_id)))


## The first combatant in `tree` with the id `id`, or null. A party member's field body and its
## battle copy share an id and a faction, so the first is as good as any (C6.4b).
static func find(tree: SceneTree, id: StringName) -> Combatant:
	if tree == null or id == &"":
		return null
	for node: Node in tree.get_nodes_in_group(GROUP):
		var found: Combatant = node as Combatant
		if found != null and found.combatant_id == id:
			return found
	return null


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


## The formula this combatant's hits resolve through: its own, or the standard one.
func resolving_formula() -> DamageFormula:
	return formula if formula != null else DamageFormula.standard()


## The element a plain attack has: its `own` when it names one, else what worn gear lends.
func strike_element(own: StringName) -> StringName:
	return own if own != &"" else lent_element


## What a plain attack counts as for a weakness: this fighter's own tags, then worn gear's.
func strike_tags() -> Array[StringName]:
	var out: Array[StringName] = attack_tags.duplicate()
	for tag: StringName in lent_tags:
		if not out.has(tag):
			out.append(tag)
	return out


## The moves this fighter plays in the field before any power (C7.3b): `own`, with a worn
## weapon's chain, and its dodge when it has one, in their place. The same set comes back until
## `own` or the weapon changes, so a form's cache keyed on it stays small.
func field_moves(own: MoveSet) -> MoveSet:
	if lent_moves == null or own == null:
		return own
	if _merged == null or _merged_own != own or _merged_lent != lent_moves:
		_merged_own = own
		_merged_lent = lent_moves
		_merged = MoveSet.new()
		_merged.attack_chain = own.attack_chain if lent_moves.attack_chain.is_empty() else lent_moves.attack_chain
		_merged.dodge = lent_moves.dodge if lent_moves.dodge != null else own.dodge
		_merged.skills = own.skills
	return _merged


## Resolves one hit on `target` and applies it. Null when there is nobody to hit.
## `sure_hit` skips the accuracy roll, for a skill that cannot miss (C2.15). `tags` say what kind
## of hit it is (a skill's tags), for a barrier to read (C6.6a).
func hit(target: Combatant, power: float, element: StringName, rng: RandomNumberGenerator,
		sure_hit: bool = false, tags: Array[StringName] = []) -> DamageResult:
	if target == null:
		return null
	# A battlefield this attacker stands in may make its hits sure, and tag them (C6.9c).
	var flags := HitFlags.of(self)
	var sure: bool = sure_hit or flags.sure_against(target)
	var request := DamageRequest.of(sheet, target.sheet, power, element)
	request.sure_hit = sure
	var result: DamageResult = resolving_formula().resolve(request, rng)
	result.tags.assign(tags)
	for flag: StringName in flags.tags:
		if not result.tags.has(flag):
			result.tags.append(flag)
	if sure:
		result.tags.append(&"sure_hit")
	target.receive(result, combatant_id)
	return result


## Applies a resolved hit and announces it. A defeated combatant takes nothing and says nothing;
## a negative total heals (an absorbed element). Returns the pool's change.
func receive(result: DamageResult, from: StringName) -> int:
	var vitals: Vitals = Vitals.of(get_parent())
	if result == null or vitals == null or vitals.is_defeated():
		return 0
	# A miss changes nothing and wakes nobody; it is announced as a miss, not as 0 damage.
	if result.missed:
		Events.attack_missed.emit(combatant_id, from)
		return 0
	# A barrier of this fighter's kit, or of an ally's, may stop or soften the hit first (C6.6a).
	PowerGuard.incoming(self, result, from)
	# A hit stopped whole is announced as blocked, not as 0 damage (C6.6b).
	if result.blocked:
		Events.attack_blocked.emit(combatant_id, from)
		return 0
	var before: int = vitals.current(damage_pool)
	var after: int = vitals.change(damage_pool, -result.total())
	# A hit that really hurt wakes a sleeper (a status with breaks_on_hit) (C2.14).
	var statuses: StatusSet = StatusSet.of(get_parent())
	if statuses != null and after < before:
		statuses.wake()
	# Damage taken feeds any `fill_on_hit_<pool>` meter, such as a limit gauge (C2.16).
	Meters.fill_on_hit(self, before - after)
	Events.combatant_damaged.emit(combatant_id, from, result.total(), result.critical)
	return after - before
