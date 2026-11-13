class_name PassiveLending
extends RefCounted
## Hands a fighter the passives of what it is, has on and wears (C9.3). See `docs/PASSIVES.md`
## § Who holds what.
##
## IN PLAIN WORDS: a passive is listed by the character, by a kit, by a piece of gear, by a
## gear-set tier, by a gem or by an upgrade level. Each of those is a SOURCE, and this file
## gives each source's list to the fighter's `PassiveSet` under the source's own name:
##   - `own`: the character's own (`CombatantDef.passives`);
##   - `kit/<the kit's source>`: a kit on the fighter (`PowerKit.passive_skills`);
##   - `gear/<item id>`: a worn piece (`GearDefinition.passives`);
##   - `set/<set id>/<pieces>`: a reached set tier (`GearSetTier.passives`);
##   - `gems`: every gem in the worn pieces (`GemDefinition.passives`);
##   - `upgrades`: every reached upgrade level of the worn pieces (`UpgradeLevel.passives`).
## When a kit comes off or a piece is taken off, its source is released, and only its passives
## go. A fighter with no passives has no `PassiveSet`; the first source with one makes it.
##
## OWNS: which source gives which passives.
## MUST NOT: run a passive (`PassiveSet` does), or decide what is worn (`GearSet` does).

const KIT_PREFIX: String = "kit/"
const GEAR_PREFIX: String = "gear/"
const GEMS: StringName = &"gems"
const UPGRADES: StringName = &"upgrades"


## Gives the fighter under `body` its definition's own passives. Call it after the `Combatant`
## is added.
static func own(body: Node, def: CombatantDef) -> void:
	if def != null:
		_give(body, PassiveSet.OWN, def.passives)


## The kit put on under `source` gives `given`. An empty list takes them back.
static func kit(body: Node, source: StringName, given: Array[PassiveSkill]) -> void:
	_give(body, StringName(KIT_PREFIX + String(source)), given)


## Brings the passives of what `gear`'s wearer has on in step with what `gear` has on.
static func gear(worn: GearSet) -> void:
	var body: Node = worn.get_parent()
	var wanted: Dictionary[StringName, Array] = {GEMS: [], UPGRADES: []}
	for piece_id: StringName in worn.worn_ids():
		var piece: GearDefinition = GearDb.for_item(piece_id)
		if piece == null:
			continue
		wanted[StringName(GEAR_PREFIX + String(piece_id))] = piece.passives
		for gem_id: StringName in GearSockets.gems(piece_id):
			var gem: GemDefinition = GemDb.for_item(gem_id)
			if gem != null:
				wanted[GEMS].append_array(gem.passives)
		for step: UpgradeLevel in GearUpgrades.reached(piece):
			wanted[UPGRADES].append_array(step.passives)
	var tiers: Dictionary[StringName, GearSetTier] = GearSetBonuses.reached(worn)
	for key: StringName in tiers:
		wanted[key] = tiers[key].passives
	var passives: PassiveSet = PassiveSet.of(body)
	if passives != null:
		for source: StringName in passives.sources():
			if _from_gear(source) and not wanted.has(source):
				passives.release(source)
	for source: StringName in wanted:
		var given: Array[PassiveSkill] = []
		given.assign(wanted[source])
		_give(body, source, given)


static func _from_gear(source: StringName) -> bool:
	var text: String = String(source)
	return text.begins_with(GEAR_PREFIX) or text.begins_with(GearSetBonuses.SOURCE_PREFIX)


# Holds `given` under `source`, making the set when the fighter has none yet. An empty list
# releases the source, and makes nothing.
static func _give(body: Node, source: StringName, given: Array[PassiveSkill]) -> void:
	var passives: PassiveSet = PassiveSet.of(body)
	if given.is_empty():
		if passives != null:
			passives.release(source)
		return
	if passives == null and body != null:
		passives = PassiveSet.new()
		body.add_child(passives)
	if passives != null:
		passives.hold(source, given)
