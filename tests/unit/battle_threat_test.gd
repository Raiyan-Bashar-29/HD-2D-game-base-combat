extends TestCase
## Threat in a turn battle (C10.28): the member who hurt a foe most tops its table, a THREAT entry
## aims at that member and a taunt still wins; the foe's line on the battle screen names whom it
## is after.
##
## OWNS: assertions about the battle fighters' `Aggro`, `Aggro.top`, TargetRule.THREAT and
## `BattleReadout`'s after line.
## MUST NOT: name a game's fighters or encounters.

var _holder: Node


func run() -> void:
	plan(3)
	SaveFixture.activate()
	Flags.clear_all()
	_holder = Node.new()
	attach(_holder)
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_threat"
	encounter.enemies = [_def(&"fixture_threat_foe", &"side_b", 1.0)]
	var battle: Battle = BattleSetup.build(encounter,
		[_def(&"fixture_threat_heavy", &"side_a", 9.0), _def(&"fixture_threat_light", &"side_a", 8.0)], _holder, _seeded())
	var heavy: Combatant = battle.party[0]
	var light: Combatant = battle.party[1]
	var foe: Combatant = battle.enemies[0]
	heavy.hit(foe, 6.0, &"", battle.rng, true)
	light.hit(foe, 0.2, &"", battle.rng, true)
	var entry := BrainEntry.new()
	entry.command = BattleCommand.new()
	entry.target_rule = BrainEntry.TargetRule.THREAT
	var guard := BattleCommand.new()
	guard.kind = BattleCommand.Kind.DEFEND
	for i: int in 4:
		if battle.next_turn() == foe:
			break
		battle.act(guard, [])
	var context := BattleBrainContext.new(battle)
	var aimed: Array[Combatant] = BattleAi._aim(context, entry)
	equal("the one who hurt it most tops its table, and THREAT aims there",
		[Aggro.top(foe.get_parent()), aimed[0]], [heavy.combatant_id, heavy])
	var log := BattleLog.new(battle, func(fighter: Combatant) -> String: return String(fighter.combatant_id))
	equal("its line names whom it is after", BattleReadout.line(foe, "foe", log).contains(
		tr(BattleReadout.AFTER_KEY).format({"name": String(heavy.combatant_id)})), true)
	var taunt := StatusEffect.new()
	taunt.id = &"status/fixture_threat_taunt"
	taunt.duration = 0.0
	taunt.tags = [Aggro.TAG]
	StatusSet.of(light.get_parent()).apply(taunt)
	equal("a taunt still wins", BattleAi._aim(context, entry)[0], light)
	BattleSetup.release(battle)
	_holder.free()
	Flags.clear_all()


# A fixed seed, so a critical roll never lets the light hit outrank the heavy one.
func _seeded() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	return rng


func _def(id: StringName, side: StringName, speed: float) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "fixture.name." + String(id)
	def.faction = side
	def.base_stats = {&"max_hp": 500.0, &"speed": speed, &"attack": 20.0, &"defence": 1.0}
	return def
