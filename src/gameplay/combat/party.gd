class_name Party
extends RefCounted
## Who fights, and how far each has grown. Every number lives in `Flags`, `Attributes`' rule:
## `party/active` and `party/reserve` (lists of ids), `level/<id>` and `exp/<id>`. So the party
## is saved, reset by a new game, and readable by a gate or a dialogue line, with no section of
## its own.
##
## THE ROSTER IS DATA, THE PARTY IS STATE. `BattleHost.roster` lists every `CombatantDef` that
## could ever fight; `Party` says which of them are in the active line-up now. Before anything
## has been set, everyone on the roster is active, so a game with a fixed party sets nothing.
##
## OWNS: the line-up, each member's level and experience, and building a member at its level.
## MUST NOT: hold a member's current hp (that is `Vitals`), or decide how much a battle gives.

const ACTIVE_FLAG: StringName = &"party/active"
const RESERVE_FLAG: StringName = &"party/reserve"
const LEVEL_PREFIX: String = "level/"
const EXP_PREFIX: String = "exp/"


## The active line-up, in order. Everyone on `roster` when nothing has been set.
static func active(roster: Array[CombatantDef]) -> Array[CombatantDef]:
	var out: Array[CombatantDef] = []
	if not Flags.has_flag(ACTIVE_FLAG):
		return roster.duplicate()
	for id: Variant in Flags.get_array(ACTIVE_FLAG):
		for def: CombatantDef in roster:
			if String(def.combatant_id) == str(id):
				out.append(def)
	return out


## Sets the active line-up and the reserve together, so a member is never in both.
static func arrange(active_ids: Array[StringName], reserve_ids: Array[StringName]) -> void:
	var on: Array[String] = []
	for id: StringName in active_ids:
		on.append(String(id))
	var off: Array[String] = []
	for id: StringName in reserve_ids:
		if not active_ids.has(id):
			off.append(String(id))
	Flags.set_flag(ACTIVE_FLAG, on)
	Flags.set_flag(RESERVE_FLAG, off)


static func level_of(id: StringName) -> int:
	return maxi(1, Flags.get_int(StringName(LEVEL_PREFIX + String(id)), 1))


static func experience_of(id: StringName) -> int:
	return Flags.get_int(StringName(EXP_PREFIX + String(id)), 0)


## Adds experience and raises the level its curve says it has reached. Returns the levels gained.
static func gain(def: CombatantDef, amount: int) -> int:
	if def.level_curve == null or amount <= 0:
		return 0
	var total: int = experience_of(def.combatant_id) + amount
	Flags.set_flag(StringName(EXP_PREFIX + String(def.combatant_id)), total)
	var before: int = level_of(def.combatant_id)
	var after: int = maxi(before, def.level_curve.level_for(total))
	if after != before:
		Flags.set_flag(StringName(LEVEL_PREFIX + String(def.combatant_id)), after)
	return after - before


## A copy of `def` whose base stats include its level's growth. Battles build from this.
static func at_level(def: CombatantDef) -> CombatantDef:
	if def.level_curve == null:
		return def
	var grown: CombatantDef = def.duplicate() as CombatantDef
	grown.base_stats = def.level_curve.grown(def.base_stats, level_of(def.combatant_id))
	return grown
