class_name PowerKit
extends Resource
## One character's set of powers (C6.1a): what the hero equips. See `docs/POWERS.md`.
##
## IN PLAIN WORDS: a kit is one data file, `data/powers/<kit>.tres`. It holds the powers the
## player can use, the `passives` (statuses held for as long as the kit is equipped), and
## `stat_bonuses` (stat changes held the same way). Adding a character is adding a kit; no
## other kit and no code changes.
##
## OWNS: the shape of a kit, and finding a power in it by id.
## Its `gauges` are pools that fill by rule (C6.4a), such as a Devil Trigger gauge.
##
## MUST NOT: equip itself or hold cooldowns. `PowerSet` (C6.1b) does that on a fighter.

@export var kit_id: StringName = &""
@export var name_key: String = ""
@export var desc_key: String = ""
@export var powers: Array[Power] = []
## Statuses held while the kit is equipped. Give them duration 0 so they never run out.
@export var passives: Array[StatusEffect] = []
## Passives (C9.3) the fighter holds while the kit is on: `PassiveSkill` files, with triggers.
@export var passive_skills: Array[PassiveSkill] = []
## Stat changes held while the kit is equipped. Their `source` should be the kit id, so taking
## the kit off removes exactly them.
@export var stat_bonuses: Array[StatModifier] = []
## How the kit's gauges fill and drain (C6.4a). Each gauge is a pool: give it a `max_<pool>`
## stat bonus, and `start_<pool>` 0 to start it empty.
@export var gauges: Array[GaugeRule] = []


## The power with `id`, or null.
func power(id: StringName) -> Power:
	for entry: Power in powers:
		if entry != null and entry.power_id == id:
			return entry
	return null


## The status `id` that this kit itself grants, or null: one of its passives, or one a power's
## mechanism puts on (a form's, C6.5c). Such a status lives only in the kit file, so a save
## finds it here, and the quick slots ask here whether a needed status is a form of this kit.
func status(id: StringName) -> StatusEffect:
	for passive: StatusEffect in passives:
		if passive != null and passive.id == id:
			return passive
	for entry: Power in powers:
		if entry == null or entry.mechanism == null:
			continue
		for granted: StatusEffect in entry.mechanism.statuses():
			if granted.id == id:
				return granted
	return null


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var where: String = "%s kit %s" % [context, kit_id]
	if kit_id == &"":
		found.append("%s has no kit_id" % where)
	if name_key == "":
		found.append("%s has no name_key" % where)
	var seen: Array[StringName] = []
	for entry: Power in powers:
		if entry == null:
			found.append("%s lists an empty power" % where)
			continue
		if seen.has(entry.power_id):
			found.append("%s lists power %s twice" % [where, entry.power_id])
		seen.append(entry.power_id)
		found.append_array(entry.problems(where))
	for status: StatusEffect in passives:
		if status == null:
			found.append("%s lists an empty passive" % where)
		else:
			found.append_array(status.problems())
	for bonus: StatModifier in stat_bonuses:
		if bonus == null:
			found.append("%s lists an empty stat bonus" % where)
			continue
		for problem: String in bonus.problems():
			found.append("%s stat bonus %s" % [where, problem])
	for rule: GaugeRule in gauges:
		if rule == null:
			found.append("%s lists an empty gauge" % where)
		else:
			found.append_array(rule.problems(where))
	return found
