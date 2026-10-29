extends TestCase
## `LevelCurve`, `Party` and `Rewards`: the curve's thresholds and growth, the line-up defaulting
## to the whole roster, experience raising a level, a member built at its level, a win giving
## experience to the standing and loot to the bag, a flight giving nothing, the fallen standing
## back up, and the party surviving a save.
##
## OWNS: assertions about what a battle leaves behind.
## MUST NOT: name a game's fighters or items. Items are `FixtureContent`'s; the rest is made up.

var _holder: Node


func run() -> void:
	plan(18)
	Fixtures.activate()
	SaveFixture.activate()
	Flags.clear_all()
	_holder = Node.new()
	attach(_holder)
	_the_curve()
	_the_line_up_and_levels()
	_a_win_rewards()
	_a_flight_gives_nothing_and_the_fallen_stand()
	_the_party_is_saved()
	_holder.free()
	Flags.clear_all()
	Fixtures.deactivate()


func _curve() -> LevelCurve:
	var curve := LevelCurve.new()
	curve.base = 20
	curve.exponent = 1.0
	curve.max_level = 3
	curve.growth = {&"max_hp": 5.0}
	return curve


func _member(id: StringName, attack: float) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "fixture.member"
	def.faction = &"side_a"
	def.base_stats = {&"max_hp": 40.0, &"speed": 9.0, &"attack": attack}
	def.level_curve = _curve()
	return def


func _encounter() -> Encounter:
	var foe := CombatantDef.new()
	foe.combatant_id = &"fixture_prey"
	foe.name_key = "fixture.prey"
	foe.faction = &"side_b"
	foe.base_stats = {&"max_hp": 5.0, &"speed": 1.0}
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_reward"
	encounter.enemies = [foe]
	encounter.experience = 25
	encounter.loot = [FixtureContent.STACK_ITEM, FixtureContent.UNIQUE_ITEM, FixtureContent.UNIQUE_ITEM]
	return encounter


func _the_curve() -> void:
	var curve := _curve()
	equal("level 1 needs no experience, level 2 needs base", [curve.exp_for(1), curve.exp_for(2)], [0, 20])
	equal("19 is still level 1, 20 is level 2", [curve.level_for(19), curve.level_for(20)], [1, 2])
	equal("the level is capped", curve.level_for(9999), 3)
	equal("growth is added once per level above 1", curve.grown({&"max_hp": 40.0}, 3)[&"max_hp"], 50.0)


func _the_line_up_and_levels() -> void:
	Flags.clear_all()
	var first := _member(&"fixture_first", 10.0)
	var second := _member(&"fixture_second", 10.0)
	var roster: Array[CombatantDef] = [first, second]
	equal("with nothing set, the whole roster is active", Party.active(roster), roster)
	Party.arrange([&"fixture_second"], [&"fixture_first"])
	equal("arranging sets the line-up", Party.active(roster), [second])
	equal("a member gains the levels its curve gives", Party.gain(first, 45), 2)
	equal("and keeps the total", [Party.level_of(&"fixture_first"), Party.experience_of(&"fixture_first")], [3, 45])
	equal("built at its level, its stats include the growth", Party.at_level(first).base_stats[&"max_hp"], 50.0)
	var guest := CombatantDef.new()
	guest.combatant_id = &"fixture_guest"
	equal("one with no curve never levels", Party.gain(guest, 999), 0)


func _bag() -> Inventory:
	var bag := Inventory.new()
	bag.save_id = &"fixture_reward_bag"
	_holder.add_child(bag)
	return bag


func _a_win_rewards() -> void:
	Flags.clear_all()
	var bag := _bag()
	var striker := _member(&"fixture_striker", 50.0)
	var fallen := _member(&"fixture_fallen", 0.0)
	var battle := BattleSetup.build(_encounter(), [striker, fallen], _holder)
	Vitals.of(battle.party[1].get_parent()).change(&"hp", -999)
	battle.next_turn()
	battle.act(BattleCommand.new(), [battle.enemies[0]])
	var given: Rewards = Rewards.grant(battle, battle.encounter, bag)
	equal("a win gives the encounter's experience", given.experience, 25)
	equal("to the standing, who level up", [Party.experience_of(&"fixture_striker"), given.levelled], [25, [&"fixture_striker"]])
	equal("but not to the fallen", Party.experience_of(&"fixture_fallen"), 0)
	equal("loot lands in the bag", [bag.count_of(FixtureContent.STACK_ITEM), bag.count_of(FixtureContent.UNIQUE_ITEM)], [1, 1])
	equal("and what does not fit is reported", given.left_behind, [FixtureContent.UNIQUE_ITEM])
	BattleSetup.release(battle)
	bag.free()


func _a_flight_gives_nothing_and_the_fallen_stand() -> void:
	Flags.clear_all()
	var runner := _member(&"fixture_runner", 0.0)
	var battle := BattleSetup.build(_encounter(), [runner], _holder)
	battle.next_turn()
	var flee := BattleCommand.new()
	flee.kind = BattleCommand.Kind.FLEE
	battle.act(flee, [])
	equal("a flight gives nothing", Rewards.grant(battle, battle.encounter, null).experience, 0)
	Vitals.of(battle.party[0].get_parent()).set_to(&"hp", 0)
	BattleSetup.release(battle)
	equal("a member left at zero stands back up at 1", Flags.get_int(&"vital/fixture_runner/hp"), 1)


func _the_party_is_saved() -> void:
	Flags.clear_all()
	Party.arrange([&"fixture_kept"], [])
	Party.gain(_member(&"fixture_kept", 1.0), 20)
	SaveSystem.save_to_slot(3)
	Flags.clear_all()
	SaveSystem.load_from_slot(3)
	equal("the line-up and levels come back from a save",
			[Party.active([_member(&"fixture_kept", 1.0)]).size(), Party.level_of(&"fixture_kept")], [1, 2])
