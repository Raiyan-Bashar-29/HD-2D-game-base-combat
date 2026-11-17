class_name PassiveSkill
extends ContentEntry
## One passive ability (C9.1): `data/passives/<name>.tres`, id `passive/<name>`, found by
## `PassiveDb`. See `docs/PASSIVES.md`.
##
## IN PLAIN WORDS: a passive is one file that a character, a kit or a piece of gear LISTS. It has
## two parts, and either may be empty:
## - `held`: a status the holder has for as long as it holds the passive (a stat boost, a regen,
##   a drain, a counter). Give that status duration 0, so it never runs out.
## - `triggers`: things that wait for an event and then act once (heal on a kill, a buff when
##   the fight starts).
## A new passive is a new file with other numbers. No code names one.
##
## OWNS: the data of one passive, and checking it.
## MUST NOT: know who holds it, or run. `PassiveSet` (gameplay) does.

@export var name_key: String = ""
## One line saying what it does, for menus.
@export var desc_key: String = ""
## Skill cost: what it takes from a character's loadout budget (C9.4). 0 for one never chosen
## freely.
@export var cost: int = 0
@export var held: StatusEffect
@export var triggers: Array[PassiveTrigger] = []
## Passives sharing a `group` do not add up (C9.2a): of those a fighter holds, only the one
## with the highest `rank` counts (a small and a large "attack up"). Empty means it always counts.
@export var group: StringName = &""
@export var rank: int = 0
## For filters and screens: `offence`, `defence`, `drawback` and so on.
@export var tags: Array[StringName] = []


func problems() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var where: String = "%s (%s)" % [resource_path, id]
	if id == &"":
		found.append("%s has no id" % resource_path)
	if name_key == "":
		found.append("%s has no name_key" % where)
	if cost < 0:
		found.append("%s has a cost below zero" % where)
	if held == null and triggers.is_empty():
		found.append("%s does nothing: no held status and no trigger" % where)
	if held != null:
		found.append_array(held.problems())
		if held.duration > 0.0:
			found.append("%s holds a status that runs out: give it duration 0" % where)
	for trigger: PassiveTrigger in triggers:
		if trigger == null:
			found.append("%s has an empty trigger" % where)
		else:
			found.append_array(trigger.problems(where))
	return found
