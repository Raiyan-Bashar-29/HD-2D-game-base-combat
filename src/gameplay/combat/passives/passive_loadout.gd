class_name PassiveLoadout
extends RefCounted
## The passives a player CHOSE for a character, and the ones the character has LEARNED (C9.4).
## See `docs/PASSIVES.md` § The loadout.
##
## IN PLAIN WORDS:
##   - A character LEARNS passives. A worn piece of gear teaches the ones it lists
##     (`GearDefinition.teaches`): each won fight with the piece on counts once, and at the
##     lesson's number the passive is learned for good. A quest or a pickup can also teach one
##     outright, with `teach`.
##   - The player CHOOSES from the learned ones. Each has a `cost`, and the costs chosen may not
##     pass the character's budget: `CombatantDef.passive_budget`, plus
##     `passive_budget_per_level` for each party level after the first.
##   - A chosen passive is held by the fighter under the source `loadout`, beside what its
##     kit and gear give.
##   - Three things are refused, each with words for the screen: a passive not learned, one
##     over the budget, and one whose `group` the fighter already holds from somewhere else.
##
## IT KEEPS NO LIST OF ITS OWN. Like worn gear, everything is a flag, so it is saved with no new
## save code and a new game clears it:
##     passive_known/<who>/<passive id>               -> true once learned
##     passive_progress/<who>/<item id>/<passive id>  -> won fights so far
##     passive_slot/<who>/<passive id>                -> true while chosen
## `<who>` is the fighter's `combatant_id`, so the field body and the battle copy share it.
##
## OWNS: what is learned, what is chosen, the budget rule and the refusals.
## MUST NOT: run a passive (`PassiveSet` does), or draw the screen (C9.7).

## Why a passive cannot be chosen. NONE means it can.
enum Refusal {
	NONE,
	## No passive has that id.
	NO_SUCH_PASSIVE,
	NOT_LEARNED,
	## It is already chosen.
	ALREADY_CHOSEN,
	OVER_BUDGET,
	## The fighter already holds a passive of the same `group`, from any source.
	SAME_GROUP,
}

const SOURCE: StringName = &"loadout"
const KNOWN_PREFIX: String = "passive_known/"
const PROGRESS_PREFIX: String = "passive_progress/"
const SLOT_PREFIX: String = "passive_slot/"
const NOT_LEARNED_KEY: String = "combat.loadout.refusal.not_learned"
const ALREADY_CHOSEN_KEY: String = "combat.loadout.refusal.already_chosen"
const OVER_BUDGET_KEY: String = "combat.loadout.refusal.over_budget"
const SAME_GROUP_KEY: String = "combat.loadout.refusal.same_group"


static func knows(who: StringName, passive_id: StringName) -> bool:
	return Flags.get_bool(_key(KNOWN_PREFIX, who, passive_id))


## Teaches `who` a passive outright (a quest, a pickup). Returns whether it was new.
static func teach(who: StringName, passive_id: StringName) -> bool:
	if who == &"" or passive_id == &"" or knows(who, passive_id):
		return false
	Flags.set_flag(_key(KNOWN_PREFIX, who, passive_id), true)
	Log.info("combat", "%s learned '%s'" % [who, passive_id])
	return true


## Every passive `who` has learned, sorted by id.
static func known(who: StringName) -> Array[StringName]:
	return _listed(KNOWN_PREFIX, who)


## Every passive `who` has chosen, sorted by id.
static func chosen(who: StringName) -> Array[StringName]:
	return _listed(SLOT_PREFIX, who)


## The skill cost `def` may choose up to, at its party level.
static func budget(def: CombatantDef) -> int:
	return def.passive_budget + def.passive_budget_per_level * (Party.level_of(def.combatant_id) - 1)


## The skill cost of what `who` has chosen.
static func spent(who: StringName) -> int:
	var total: int = 0
	for passive_id: StringName in chosen(who):
		var passive: PassiveSkill = PassiveDb.passive(passive_id)
		total += passive.cost if passive != null else 0
	return total


## Why the fighter under `body`, whose definition is `def`, cannot choose `passive_id`.
static func refusal(body: Node, def: CombatantDef, passive_id: StringName) -> Refusal:
	var passive: PassiveSkill = PassiveDb.passive(passive_id)
	if passive == null:
		return Refusal.NO_SUCH_PASSIVE
	var who: StringName = def.combatant_id
	if not knows(who, passive_id):
		return Refusal.NOT_LEARNED
	if chosen(who).has(passive_id):
		return Refusal.ALREADY_CHOSEN
	var held: PassiveSet = PassiveSet.of(body)
	if passive.group != &"" and held != null:
		for source: StringName in held.sources():
			for other: PassiveSkill in held.given_by(source):
				if other.group == passive.group:
					return Refusal.SAME_GROUP
	if spent(who) + passive.cost > budget(def):
		return Refusal.OVER_BUDGET
	return Refusal.NONE


## The words for a refusal, as a localization key. Empty for NONE and for a missing passive.
static func refusal_key(why: Refusal) -> String:
	match why:
		Refusal.NOT_LEARNED:
			return NOT_LEARNED_KEY
		Refusal.ALREADY_CHOSEN:
			return ALREADY_CHOSEN_KEY
		Refusal.OVER_BUDGET:
			return OVER_BUDGET_KEY
		Refusal.SAME_GROUP:
			return SAME_GROUP_KEY
	return ""


## Chooses a passive for the fighter under `body`. Returns whether anything changed.
static func choose(body: Node, def: CombatantDef, passive_id: StringName) -> bool:
	if refusal(body, def, passive_id) != Refusal.NONE:
		return false
	Flags.set_flag(_key(SLOT_PREFIX, def.combatant_id, passive_id), true)
	fit(body)
	return true


## Takes a chosen passive out. The flag is erased, so nothing of it stays in a save.
static func drop(body: Node, passive_id: StringName) -> bool:
	var who: StringName = _who(body)
	if not chosen(who).has(passive_id):
		return false
	Flags.erase_flag(_key(SLOT_PREFIX, who, passive_id))
	fit(body)
	return true


## Brings what the fighter under `body` holds under `loadout` in step with the flags. A chosen
## passive whose file is gone, or that is no longer learned, gives nothing.
static func fit(body: Node) -> void:
	var who: StringName = _who(body)
	var given: Array[PassiveSkill] = []
	for passive_id: StringName in chosen(who):
		var passive: PassiveSkill = PassiveDb.passive(passive_id)
		if passive != null and knows(who, passive_id):
			given.append(passive)
	PassiveLending.give(body, SOURCE, given)


## Won fights counted so far towards the lesson of `passive_id` on the piece `item_id`.
static func progress(who: StringName, item_id: StringName, passive_id: StringName) -> int:
	return Flags.get_int(_progress_key(who, item_id, passive_id))


## One won fight for `who`: every lesson of every piece it wears moves one step, and a lesson
## that reaches its number is learned. Returns the passives learned just now. `Rewards` calls
## this for each member it rewards, after a battle and after a field kill alike.
static func practise(who: StringName) -> Array[StringName]:
	var learned: Array[StringName] = []
	var scope: String = "%s%s/" % [GearSet.PREFIX, who]
	for flag: StringName in Flags.with_prefix(scope):
		var item_id: StringName = StringName(String(flag).trim_prefix(scope))
		var piece: GearDefinition = GearDb.for_item(item_id)
		if piece == null or Flags.get_string(flag) == "":
			continue
		for lesson: PassiveLesson in piece.teaches:
			if lesson == null or lesson.passive == null or knows(who, lesson.passive.id):
				continue
			var count: int = progress(who, item_id, lesson.passive.id) + 1
			Flags.set_flag(_progress_key(who, item_id, lesson.passive.id), count)
			if count >= lesson.fights and teach(who, lesson.passive.id):
				learned.append(lesson.passive.id)
	return learned


static func _who(body: Node) -> StringName:
	var fighter: Combatant = Combatant.of(body)
	return fighter.combatant_id if fighter != null else &""


static func _key(prefix: String, who: StringName, passive_id: StringName) -> StringName:
	return StringName("%s%s/%s" % [prefix, who, passive_id])


static func _progress_key(who: StringName, item_id: StringName, passive_id: StringName) -> StringName:
	return StringName("%s%s/%s/%s" % [PROGRESS_PREFIX, who, item_id, passive_id])


static func _listed(prefix: String, who: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	var scope: String = "%s%s/" % [prefix, who]
	for flag: StringName in Flags.with_prefix(scope):
		if Flags.get_bool(flag):
			out.append(StringName(String(flag).trim_prefix(scope)))
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out
