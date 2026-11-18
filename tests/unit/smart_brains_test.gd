extends TestCase
## Smarter battle brains (C10.19): WEAK aims at the foe weak to the skill, else the first;
## `avoids_reflect` passes over a mirror; `above_fraction`
## gates an entry; on auto a member with no brain heals an ally under half, else aims a skill at
## a weakness it has found, else attacks.
##
## OWNS: assertions about the new `BrainEntry` rules in `BattleAi` and `AutoBattle.default_for`.
## MUST NOT: name a game's fighters or skills. Every name here is made up for the case.

var _holder: Node


func run() -> void:
	plan(4)
	SaveFixture.activate()
	Flags.clear_all()
	_holder = Node.new()
	attach(_holder)
	_rules()
	_default()
	_holder.free()
	Flags.clear_all()


func _def(id: StringName, side: StringName, stats: Dictionary[StringName, float]) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "fixture.name." + String(id)
	def.faction = side
	def.base_stats = stats
	return def


func _skill(id: StringName, power: float, element: StringName) -> BattleCommand:
	var command := BattleCommand.new()
	command.kind = BattleCommand.Kind.SKILL
	command.skill = Skill.new()
	command.skill.id = id
	command.skill.name_key = "fixture.skill"
	command.skill.power = power
	command.skill.element = element
	command.skill.sure_hit = true
	command.skill.tags = [&"magic"]
	if power < 0.0:
		command.skill.target = FactionTable.Target.ALLY
	return command


func _battle(hero: CombatantDef, foes: Array[CombatantDef]) -> Battle:
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_brains"
	encounter.enemies = foes
	var battle: Battle = BattleSetup.build(encounter, [hero], _holder, RandomNumberGenerator.new())
	battle.next_turn()
	return battle


func _rules() -> void:
	var plain := _def(&"fixture_brains_plain", &"side_b", {&"max_hp": 90.0, &"speed": 1.0})
	var weak := _def(&"fixture_brains_weak", &"side_b", {&"max_hp": 90.0, &"speed": 1.0})
	weak.weak_to = [&"fixture_frost"]
	var hero := _def(&"fixture_brains_hero", &"side_a", {&"max_hp": 90.0, &"max_mp": 40.0, &"speed": 9.0, &"attack": 5.0})
	var battle: Battle = _battle(hero, [plain, weak])
	var entry := BrainEntry.new()
	entry.command = _skill(&"skill/fixture_brains_frost", 3.0, &"fixture_frost")
	entry.target_rule = BrainEntry.TargetRule.WEAK
	var aimed: Array[Combatant] = BattleAi._aim(BattleBrainContext.new(battle), entry)
	equal("WEAK aims at the foe weak to the skill", aimed[0].combatant_id, &"fixture_brains_weak")
	var mirror := StatusEffect.new()
	mirror.id = &"status/fixture_brains_mirror"
	mirror.duration = 0.0
	mirror.reactions = [StatusEffect.Reaction.REFLECT]
	mirror.reflect_tag = &"magic"
	StatusSet.of(battle.enemies[1].get_parent()).apply(mirror)
	entry.avoids_reflect = true
	aimed = BattleAi._aim(BattleBrainContext.new(battle), entry)
	equal("a mirror is passed over while another target is left", aimed[0].combatant_id, &"fixture_brains_plain")
	var thrifty := BrainEntry.new()
	thrifty.command = entry.command
	thrifty.above_fraction = 0.5
	thrifty.below_pool = &"mp"
	var context := BattleBrainContext.new(battle)
	var full: bool = BattleAi._allowed(context, thrifty)
	Vitals.of(battle.party[0].get_parent()).set_to(&"mp", 10)
	equal("above_fraction allows the entry only while the pool is high enough", [full, BattleAi._allowed(context, thrifty)], [true, false])
	BattleSetup.release(battle)


func _default() -> void:
	var foe := _def(&"fixture_brains_target", &"side_b", {&"max_hp": 90.0, &"speed": 1.0})
	foe.weak_to = [&"fixture_frost"]
	var hero := _def(&"fixture_brains_auto", &"side_a", {&"max_hp": 90.0, &"max_mp": 40.0, &"speed": 9.0, &"attack": 5.0})
	hero.commands = [BattleCommand.new(), _skill(&"skill/fixture_brains_mend", -10.0, &""), _skill(&"skill/fixture_brains_ice", 3.0, &"fixture_frost")]
	var brain: BattleBrain = AutoBattle.default_for(hero)
	var battle: Battle = _battle(hero, [foe])
	var context := BattleBrainContext.new(battle)
	var before: Array[bool] = [BattleAi._allowed(context, brain.entries[0]), BattleAi._allowed(context, brain.entries[1])]
	Weakness.reveal_all(battle.enemies[0])
	Vitals.of(battle.party[0].get_parent()).set_to(&"hp", 20)
	equal("on auto a member with no brain heals under half, and aims a skill only at a weakness it found",
		[brain.entries.size(), before, BattleAi._allowed(context, brain.entries[0]), BattleAi._allowed(context, brain.entries[1])],
		[2, [false, false] as Array[bool], true, true])
	BattleSetup.release(battle)
