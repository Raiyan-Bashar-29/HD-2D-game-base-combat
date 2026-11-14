class_name MugenKit
extends RefCounted
## Builds a starter `PowerKit` and `ActionLoadout` from converted moves and a choices file (C9.9e).
##
## IN PLAIN WORDS: the converter (`MugenCharacter`) gives every move of a character. It cannot
## know which moves are the basic chain, which are specials, or what the stances are: the
## author says so in a small choices file (JSON). This file reads those choices and builds the
## same shapes Arima's files have:
## - `name`: the word used in every id (`move/<name>_<state>`, `kit/<name>`);
## - `chain`: the state numbers of the basic chain; `dodge`: an `ActionMove`'s fields, by hand;
## - `gauge`: `pool`, `max`, `start`, `on_hit_dealt`, `on_hit_taken`;
## - `specials`: each `{state, id, cooldown, cost}`. With no `cost`, the M.U.G.E.N meter cost
##   out of 3000 becomes that share of the gauge's `max`. The power's move does the hitting;
##   its skill only pays;
## - `stances`: each `{id, chain, specials, tint: [r, g, b], stats: {attack: 1.15}}`. They
##   become one cycling `FormMechanism`; a stance's specials take a slot only while it is held;
## - `passives`: paths of `PassiveSkill` files; `stats`, `growth`, `attack_tags`,
##   `passive_budget`: the fighter's own numbers; `max_box`: the largest hitbox side, metres.
## Names are string keys only; `strings` lists every key the author must add to the CSV.
##
## OWNS: turning choices into the kit and the loadout.
## MUST NOT: write a file (`MugenStarter` does), hold a rule of the formula, or name a character.

const METER_FULL: float = 3000.0


## The kit and loadout for `choices`. `moves` is state number -> the converter's numbers. The
## result has `kit`, `loadout`, `strings` (the CSV keys to add) and `problems`.
static func build(choices: Dictionary, moves: Dictionary) -> Dictionary:
	var name: String = DictRead.get_string(choices, "name", "fighter")
	var out: Dictionary = {"strings": PackedStringArray(), "problems": PackedStringArray()}
	var kit := PowerKit.new()
	kit.kit_id = StringName("kit/" + name)
	kit.name_key = _key(out, "combat.kit.%s.name" % name)
	kit.desc_key = _key(out, "combat.kit.%s.desc" % name)
	var gauge: Dictionary = DictRead.get_dict(choices, "gauge")
	if not gauge.is_empty():
		_gauge(kit, gauge)
	var stances: Array = DictRead.get_array(choices, "stances")
	if not stances.is_empty():
		kit.powers.append(_stances(choices, moves, stances, out))
	for stance: Dictionary in stances:
		for special: Dictionary in DictRead.get_array(stance, "specials"):
			var power: Power = _special(choices, moves, special, out)
			power.requires_statuses.append(StringName("status/form_%s_%s" % [name, stance["id"]]))
			kit.powers.append(power)
	for special: Dictionary in DictRead.get_array(choices, "specials"):
		kit.powers.append(_special(choices, moves, special, out))
	for path: String in DictRead.get_array(choices, "passives"):
		var passive: PassiveSkill = load(path) as PassiveSkill
		if passive == null:
			MugenIni.note(out, "problems", "%s is not a PassiveSkill" % path)
		else:
			kit.passive_skills.append(passive)
	out["kit"] = kit
	out["loadout"] = _loadout(choices, moves, kit, out)
	return out


## The `ActionMove` of state `number`, with its hitbox kept inside `max_box` and its events
## (sounds from the `sprites` folder, shakes, pauses) from `MugenEvents`. A state the
## converter did not give is a problem and comes back as an empty move.
static func move(choices: Dictionary, moves: Dictionary, number: int, out: Dictionary) -> ActionMove:
	var id := StringName("move/%s_%d" % [DictRead.get_string(choices, "name", "fighter"), number])
	if not moves.has(number):
		MugenIni.note(out, "problems", "state %d is not in moves.json" % number)
		return MugenFormula.move({"startup": 0.0, "active": 0.1, "recovery": 0.0, "iframes_from": 0.0,
			"iframes_to": 0.0, "power": 0.0, "hits": 0, "travel_speed": 0.0}, id)
	var made: ActionMove = MugenFormula.move(moves[number] as Dictionary, id)
	var most: float = DictRead.get_float(choices, "max_box", 8.0)
	made.hitbox_size = made.hitbox_size.min(Vector3.ONE * most)
	made.hitbox_offset.y = minf(made.hitbox_offset.y, made.hitbox_size.y * 0.5)
	made.hitbox_offset.z = maxf(made.hitbox_offset.z, -most * 0.5)
	MugenEvents.fill(made, moves[number] as Dictionary, DictRead.get_string(choices, "sprites"))
	return made


static func _gauge(kit: PowerKit, gauge: Dictionary) -> void:
	var pool: String = DictRead.get_string(gauge, "pool", "focus")
	for pair: Array in [["max_", DictRead.get_float(gauge, "max", 100.0)], ["start_", DictRead.get_float(gauge, "start")]]:
		var bonus := StatModifier.new()
		bonus.stat = StringName(str(pair[0]) + pool)
		bonus.value = pair[1]
		bonus.source = kit.kit_id
		kit.stat_bonuses.append(bonus)
	var rule := GaugeRule.new()
	rule.pool = StringName(pool)
	rule.on_hit_dealt = DictRead.get_float(gauge, "on_hit_dealt")
	rule.on_hit_taken = DictRead.get_float(gauge, "on_hit_taken")
	kit.gauges.append(rule)


# One power for a special: its move hits, its skill (aimed at the user) only pays the cost.
static func _special(choices: Dictionary, moves: Dictionary, special: Dictionary, out: Dictionary) -> Power:
	var name: String = DictRead.get_string(choices, "name", "fighter")
	var state: int = DictRead.get_int(special, "state")
	var word: String = "%s_%s" % [name, DictRead.get_string(special, "id", str(state))]
	var gauge: Dictionary = DictRead.get_dict(choices, "gauge")
	var share: float = DictRead.get_float(moves.get(state, {}) as Dictionary, "meter") / METER_FULL
	var skill := Skill.new()
	skill.id = StringName("skill/" + word)
	skill.name_key = _key(out, "combat.power.%s.name" % word)
	skill.target = FactionTable.Target.SELF
	if not gauge.is_empty():
		skill.cost_pool = StringName(DictRead.get_string(gauge, "pool", "focus"))
		skill.cost = DictRead.get_int(special, "cost", roundi(share * DictRead.get_float(gauge, "max", 100.0)))
	var power := Power.new()
	power.power_id = StringName("power/" + word)
	power.name_key = skill.name_key
	power.desc_key = _key(out, "combat.power.%s.desc" % word)
	power.skill = skill
	power.move = move(choices, moves, state, out)
	power.cooldown = DictRead.get_float(special, "cooldown", 4.0)
	return power


# The power that steps through the stances: one cycling form, one stage per stance.
static func _stances(choices: Dictionary, moves: Dictionary, stances: Array, out: Dictionary) -> Power:
	var name: String = DictRead.get_string(choices, "name", "fighter")
	var cycle := FormMechanism.new()
	cycle.exclusive_group = StringName(name + "_stance")
	for stance: Dictionary in stances:
		var word: String = "%s_%s" % [name, stance["id"]]
		var form := FormMechanism.new()
		form.name_key = _key(out, "combat.form.%s.name" % word)
		form.status = StatusEffect.new()
		form.status.id = StringName("status/form_" + word)
		form.status.name_key = form.name_key
		form.status.duration = 0.0
		form.status.tags.append(&"form")
		var stats: Dictionary = DictRead.get_dict(stance, "stats")
		for stat: String in stats:
			var change := StatModifier.new()
			change.stat = StringName(stat)
			change.op = StatModifier.Op.MULTIPLY
			change.value = DictRead.get_float(stats, stat, 1.0)
			form.status.modifiers.append(change)
		for number: Variant in DictRead.get_array(stance, "chain"):
			form.attack_chain.append(move(choices, moves, int(DictRead.to_float(number)), out))
		form.look = LookDef.new()
		form.look.look_id = StringName("look/" + word)
		form.look.label_key = form.name_key
		var tint: Array = DictRead.get_array(stance, "tint")
		if tint.size() >= 3:
			form.look.tint = Color(DictRead.to_float(tint[0]), DictRead.to_float(tint[1]), DictRead.to_float(tint[2]))
		cycle.cycle.append(form)
	var power := Power.new()
	power.power_id = StringName("power/%s_stance" % name)
	power.name_key = _key(out, "combat.power.%s_stance.name" % name)
	power.desc_key = _key(out, "combat.power.%s_stance.desc" % name)
	power.mechanism = cycle
	power.cooldown = 1.0
	return power


static func _loadout(choices: Dictionary, moves: Dictionary, kit: PowerKit, out: Dictionary) -> ActionLoadout:
	var name: String = DictRead.get_string(choices, "name", "fighter")
	var fighter := CombatantDef.new()
	fighter.combatant_id = StringName(name)
	fighter.name_key = _key(out, "combat.member.%s.name" % name)
	fighter.faction = &"player"
	fighter.power_kit = kit
	fighter.passive_budget = DictRead.get_int(choices, "passive_budget", 4)
	fighter.passive_budget_per_level = 1
	fighter.level_curve = LevelCurve.new()
	var stats: Dictionary = DictRead.get_dict(choices, "stats")
	for stat: String in stats:
		fighter.base_stats[StringName(stat)] = DictRead.get_float(stats, stat)
	var growth: Dictionary = DictRead.get_dict(choices, "growth")
	for stat: String in growth:
		fighter.level_curve.growth[StringName(stat)] = DictRead.get_float(growth, stat)
	for tag: String in DictRead.get_array(choices, "attack_tags"):
		fighter.attack_tags.append(StringName(tag))
	var set := MoveSet.new()
	for number: Variant in DictRead.get_array(choices, "chain"):
		set.attack_chain.append(move(choices, moves, int(DictRead.to_float(number)), out))
	set.dodge = ActionMove.new()
	var dodge: Dictionary = DictRead.get_dict(choices, "dodge")
	for field: String in dodge:
		set.dodge.set(field, DictRead.get_float(dodge, field))
	var loadout := ActionLoadout.new()
	loadout.fighter = fighter
	loadout.moves = set
	loadout.atb = AtbRules.new()
	return loadout


static func _key(out: Dictionary, key: String) -> String:
	MugenIni.note(out, "strings", key)
	return key
