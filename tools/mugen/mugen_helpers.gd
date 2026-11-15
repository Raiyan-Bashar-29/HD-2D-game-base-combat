class_name MugenHelpers
extends RefCounted
## Turns a converted character's helpers into owned fighters a special summons (C8.10b).
##
## IN PLAIN WORDS: a M.U.G.E.N character may call helpers, other fighters with their own state
## files that fight beside it. The choices file lists them under `helpers`, each:
## - `id`: the word in its ids (`<name>_<id>`);
## - `sprites`: the folder `tools/mugen_sprites.gd` unpacked it into (its stand and walk as the
##   sheet, its moves as strips, its moves' sounds);
## - `moves`: `[{state, weight}]`, the states its own brain picks from (the weights are the
##   `random` chances in its stand state);
## - `stats`: its numbers; `brain`: any `ActionBrain` field by name (`attack_range`, ...).
## A special with `summons: ["<helper id>", ...]` becomes a `SummonMechanism` power, with
## `lifetime`, `cap`, `untouchable` and `moves_each` from the special. Every summon of one kit shares one status,
## `status/<name>_helpers_out`, held while any helper is out; a special with `alone: true`
## forbids it, for "only while no helper is out".
##
## OWNS: turning `helpers` and a special's `summons` into a `SummonMechanism`.
## MUST NOT: write a file (`MugenStarter` does), or name a character.


## The summon for `special`, or null when it summons nobody.
static func summon(choices: Dictionary, moves: Dictionary, special: Dictionary, out: Dictionary) -> SummonMechanism:
	var wanted: Array = DictRead.get_array(special, "summons")
	if wanted.is_empty():
		return null
	var made := SummonMechanism.new()
	made.lifetime = DictRead.get_float(special, "lifetime")
	made.cap = DictRead.get_int(special, "cap", wanted.size())
	made.untouchable = DictRead.get_bool(special, "untouchable")
	made.moves_each = DictRead.get_int(special, "moves_each")
	made.owner_status = out_status(choices, out)
	for helper_id: Variant in wanted:
		var helper: Dictionary = _helper(choices, str(helper_id))
		if helper.is_empty():
			MugenIni.note(out, "problems", "summons names %s, which is not under helpers" % helper_id)
			continue
		made.fighters.append(_fighter(choices, moves, helper, out))
		made.brains.append(_brain(choices, moves, helper, out))
	return made


## The one status every summon of this kit holds on the user while any helper is out.
static func out_status(choices: Dictionary, out: Dictionary) -> StatusEffect:
	if out.has("helpers_out"):
		return out["helpers_out"]
	var name: String = DictRead.get_string(choices, "name", "fighter")
	var status := StatusEffect.new()
	status.id = StringName("status/%s_helpers_out" % name)
	status.name_key = MugenKit.key(out, "combat.status.%s_helpers_out.name" % name)
	status.unit = StatusEffect.Unit.SECONDS
	status.duration = 9999.0
	out["helpers_out"] = status
	return status


static func _helper(choices: Dictionary, helper_id: String) -> Dictionary:
	for helper: Dictionary in DictRead.get_array(choices, "helpers"):
		if DictRead.get_string(helper, "id") == helper_id:
			return helper
	return {}


static func _fighter(choices: Dictionary, moves: Dictionary, helper: Dictionary, out: Dictionary) -> CombatantDef:
	var word: String = "%s_%s" % [DictRead.get_string(choices, "name", "fighter"), DictRead.get_string(helper, "id")]
	var fighter := CombatantDef.new()
	fighter.combatant_id = StringName(word)
	fighter.name_key = MugenKit.key(out, "combat.member.%s.name" % word)
	var stats: Dictionary = DictRead.get_dict(helper, "stats")
	for stat: String in stats:
		fighter.base_stats[StringName(stat)] = DictRead.get_float(stats, stat)
	for tag: String in DictRead.get_array(choices, "attack_tags"):
		fighter.attack_tags.append(StringName(tag))
	var folder: String = DictRead.get_string(helper, "sprites")
	if folder != "":
		var drawn: Dictionary = MugenArt.build(choices, moves, _states(helper), folder)
		for problem: String in drawn["problems"]:
			MugenIni.note(out, "problems", problem)
		fighter.art = drawn["art"]
	return fighter


static func _brain(choices: Dictionary, moves: Dictionary, helper: Dictionary, out: Dictionary) -> ActionBrain:
	var brain := ActionBrain.new()
	var fields: Dictionary = DictRead.get_dict(helper, "brain")
	for field: String in fields:
		brain.set(field, DictRead.get_float(fields, field))
	# Its moves' sounds are in its own folder.
	var own: Dictionary = choices.duplicate()
	own["sprites"] = DictRead.get_string(helper, "sprites", DictRead.get_string(choices, "sprites"))
	for picked: Dictionary in DictRead.get_array(helper, "moves"):
		var entry := ActionBrainEntry.new()
		entry.move = MugenKit.move(own, moves, DictRead.get_int(picked, "state"), out)
		entry.weight = DictRead.get_float(picked, "weight", 1.0)
		brain.moves.append(entry)
	return brain


static func _states(helper: Dictionary) -> PackedInt32Array:
	var states := PackedInt32Array()
	for picked: Dictionary in DictRead.get_array(helper, "moves"):
		states.append(DictRead.get_int(picked, "state"))
	return states
