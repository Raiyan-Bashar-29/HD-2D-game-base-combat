extends TestCase
## Steal, scan and capture (C8.7b). Steal: a STEAL effect takes one roll of the target's
## steal table, once, and a failed roll takes nothing. With no bag on the user the goods wait
## in `spoils` and come home with a won battle's rewards; with a bag they go straight in.
## Scan: every weakness of the kind is revealed. Capture: a fresh target never goes, a hurt
## one does, it falls, the item is given and the kind is counted; a fighter with no capture
## item cannot be taken.
##
## OWNS: assertions about `Pilfer`, `Weakness.reveal_all`, the three `SkillEffect` kinds and
## the spoils in `Rewards.grant`.
## MUST NOT: name a game's fighters or items. Every name here is made up for the case.

var _holder: Node


func run() -> void:
	plan(10)
	Fixtures.activate()
	SaveFixture.activate()
	Flags.clear_all()
	_holder = Node.new()
	attach(_holder)
	_content()
	_steal_and_scan()
	_capture()
	_in_the_field()
	_holder.free()
	Flags.clear_all()
	Fixtures.deactivate()


func _content() -> void:
	var steal: SkillEffect = _effect(SkillEffect.Kind.STEAL, 0.0)
	var scan: SkillEffect = _effect(SkillEffect.Kind.SCAN, 0.0)
	equal("a STEAL needs a chance; a SCAN needs nothing",
		[steal.problems("fixture").size(), scan.problems("fixture").size()], [1, 0])
	var foe: CombatantDef = _foe(&"fixture_mark")
	foe.steal_table = LootTable.new()
	equal("a fighter's steal table is checked as its loot table is", foe.problems("fixture").size() > 0, true)


func _steal_and_scan() -> void:
	var bag := Inventory.new()
	bag.save_id = &"fixture_pilfer_bag"
	_holder.add_child(bag)
	var battle := BattleSetup.build(_encounter(), [_member()], _holder)
	var thief: Combatant = battle.party[0]
	var mark: Combatant = battle.enemies[0]
	battle.next_turn()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	SkillUse.apply(thief, _skill(_effect(SkillEffect.Kind.STEAL, 0.0001)), [mark], rng)
	equal("a failed steal takes nothing", thief.spoils, [])
	SkillUse.apply(thief, _skill(_effect(SkillEffect.Kind.STEAL, 1.0)), [mark], rng)
	equal("a steal takes one roll of the table, and waits in the thief's spoils",
		thief.spoils, [FixtureContent.STACK_ITEM])
	SkillUse.apply(thief, _skill(_effect(SkillEffect.Kind.STEAL, 1.0)), [mark], rng)
	equal("a fighter is robbed only once", thief.spoils.size(), 1)
	var before: bool = Weakness.revealed(mark, &"fixture_fire")
	SkillUse.apply(thief, _skill(_effect(SkillEffect.Kind.SCAN, 0.0)), [mark], rng)
	equal("a scan reveals every weakness of the kind",
		[before, Weakness.revealed(mark, &"fixture_fire"), Weakness.revealed(mark, &"fixture_ice")],
		[false, true, true])
	Vitals.of(mark.get_parent()).set_to(&"hp", 1)
	battle.act(BattleCommand.new(), [mark])
	var given: Rewards = Rewards.grant(battle, battle.encounter, bag)
	equal("the spoils come home with the rewards of a won battle",
		[given.items, bag.count_of(FixtureContent.STACK_ITEM), thief.spoils], [[FixtureContent.STACK_ITEM], 1, []])
	BattleSetup.release(battle)
	bag.free()


func _capture() -> void:
	var battle := BattleSetup.build(_encounter(), [_member()], _holder)
	var hunter: Combatant = battle.party[0]
	var prey: Combatant = battle.enemies[0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var net: Skill = _skill(_effect(SkillEffect.Kind.CAPTURE, 1.0))
	SkillUse.apply(hunter, net, [prey], rng)
	var fresh: Array = [hunter.spoils.size(), Vitals.of(prey.get_parent()).is_defeated()]
	Vitals.of(prey.get_parent()).set_to(&"hp", 1)
	prey.capture_item = &""
	SkillUse.apply(hunter, net, [prey], rng)
	var guarded: bool = Vitals.of(prey.get_parent()).is_defeated()
	prey.capture_item = FixtureContent.UNIQUE_ITEM
	SkillUse.apply(hunter, net, [prey], rng)
	equal("a fresh target is never captured, nor one with no capture item",
		[fresh, guarded], [[0, false], false])
	equal("a hurt one is: it falls, its item is taken and its kind is counted",
		[Vitals.of(prey.get_parent()).is_defeated(), hunter.spoils, Flags.get_int(Pilfer.captured_flag(prey))],
		[true, [FixtureContent.UNIQUE_ITEM], 1])
	BattleSetup.release(battle)


func _in_the_field() -> void:
	var battle := BattleSetup.build(_encounter(), [_member()], _holder)
	var thief: Combatant = battle.party[0]
	var bag := Inventory.new()
	bag.save_id = &"fixture_pilfer_pocket"
	thief.get_parent().add_child(bag)
	Pilfer.steal(thief, battle.enemies[0], 1.0, RandomNumberGenerator.new())
	equal("a thief with a bag on its own body gets the goods at once",
		[bag.count_of(FixtureContent.STACK_ITEM), thief.spoils], [1, []])
	BattleSetup.release(battle)


func _effect(kind: SkillEffect.Kind, amount: float) -> SkillEffect:
	var made := SkillEffect.new()
	made.kind = kind
	made.amount = amount
	return made


func _skill(effect: SkillEffect) -> Skill:
	var made := Skill.new()
	made.effects = [effect]
	return made


func _member() -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = &"fixture_thief"
	def.name_key = "fixture.thief"
	def.faction = &"side_a"
	def.base_stats = {&"max_hp": 40.0, &"attack": 50.0, &"speed": 9.0}
	return def


func _foe(id: StringName) -> CombatantDef:
	var foe := CombatantDef.new()
	foe.combatant_id = id
	foe.name_key = "fixture.mark"
	foe.faction = &"side_b"
	foe.base_stats = {&"max_hp": 60.0, &"speed": 1.0}
	foe.weak_to = [&"fixture_fire", &"fixture_ice"]
	return foe


func _encounter() -> Encounter:
	var foe: CombatantDef = _foe(&"fixture_mark")
	var line := LootEntry.new()
	line.item_id = FixtureContent.STACK_ITEM
	foe.steal_table = LootTable.new()
	foe.steal_table.entries = [line]
	foe.capture_item = FixtureContent.UNIQUE_ITEM
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_pilfer"
	encounter.enemies = [foe]
	return encounter
