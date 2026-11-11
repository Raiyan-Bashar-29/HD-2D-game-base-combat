extends TestCase
## Rarity and drops (C7.2): a rarity tier scales a piece's stat changes and makes it rarer in
## rolled loot, a loot table is rolled with the fight's own random numbers, and a won battle
## and a fallen field enemy both give what their tables roll.
##
## OWNS: assertions about `Rarity`, `RarityDb`, `GearDefinition.rarity`, `LootTable`,
## `LootEntry`, `LootRoll`, and the rolled part of `Rewards.grant` and `ActionEnemy`.
## MUST NOT: name a game's gear, items, tiers or characters, or wait for frames. The gear and
## rarity files are written to this run's scratch directory, over the fixture items.

const HERB: StringName = FixtureContent.STACK_ITEM
const RING: StringName = FixtureContent.SPARE_ITEM
const RELIC: StringName = FixtureContent.WORN_ITEM
const FINE: StringName = &"rarity/fixture_fine"
const ONLY: StringName = &"rarity/fixture_only"
const OPEN_FLAG: StringName = &"fixture_loot_open"

var _directory: String
var _announced: Array = []


func run() -> void:
	plan(21)
	SaveFixture.activate()
	Fixtures.activate()
	Flags.clear_all()
	_write_content()
	_tiers()
	_scaled_gear()
	_rolling()
	_problems()
	_a_won_battle()
	_a_field_enemy()
	GearDb.content_dir = GearDb.GEAR_DIR
	GearDb.rescan()
	RarityDb.content_dir = RarityDb.RARITY_DIR
	RarityDb.rescan()
	_the_games_own_tiers()
	Flags.clear_all()
	Fixtures.deactivate()


func _tiers() -> void:
	var fine: Rarity = RarityDb.of(FINE)
	equal("a tier is found by its id, and an unknown or empty id finds none",
		[fine != null, RarityDb.of(&"rarity/fixture_missing"), RarityDb.of(&"")], [true, null, null])
	equal("the tiers come lowest rank first", [RarityDb.ranked()[0].id, RarityDb.ranked()[1].id], [FINE, ONLY])
	equal("the fixture tiers have no problems", RarityDb.problems().size(), 0)
	var added: StatModifier = fine.scaled(StatModifier.of(&"attack", StatModifier.Op.ADD, 4.0, &"s"))
	equal("an added amount is multiplied by the tier's scale, and keeps its stat and source",
		[added.value, added.stat, added.source], [6.0, &"attack", &"s"])
	equal("a multiplier keeps its distance from 1 multiplied",
		is_equal_approx(fine.scaled(StatModifier.of(&"speed", StatModifier.Op.MULTIPLY, 1.2, &"s")).value, 1.3), true)
	var fixed: StatModifier = StatModifier.of(&"luck", StatModifier.Op.OVERRIDE, 7.0, &"s")
	equal("an override is left as it is", fine.scaled(fixed), fixed)


func _scaled_gear() -> void:
	var ring: GearDefinition = GearDb.for_item(RING)
	equal("a piece with a rarity gives its stat changes at the tier's size", ring.all_modifiers()[0].value, 3.0)
	var body := Node3D.new()
	body.add_child(Vitals.new())
	var fighter := Combatant.new()
	fighter.combatant_id = &"fixture_looter"
	fighter.base_stats = {&"max_hp": 40.0, &"defence": 1.0}
	body.add_child(fighter)
	var gear := GearSet.new()
	gear.kept = false
	body.add_child(gear)
	attach(body)
	gear.wear(RING)
	equal("so the wearer's sheet has the scaled number, and loses it when the piece comes off",
		[fighter.sheet.value(&"defence"), gear.take_off(RING), fighter.sheet.value(&"defence")], [4.0, true, 1.0])
	body.free()
	ring.rarity = &"rarity/fixture_missing"
	equal("a piece naming a rarity that does not exist is a problem, and gives its plain numbers",
		[ring.problems().size(), ring.all_modifiers()[0].value], [1, 2.0])
	ring.rarity = FINE


func _rolling() -> void:
	var table := _table([_line(HERB, 1.0, 2, 2), _line(RING, 1.0, 1, 1), _line(RELIC, 5.0, 1, 1)], 40)
	equal("a rarity's drop weight multiplies a line's share, and weight 0 takes the piece out",
		[LootRoll.weight_of(table.entries[0]), LootRoll.weight_of(table.entries[1]), LootRoll.weight_of(table.entries[2])],
		[1.0, 0.5, 0.0])
	var first: Array[StringName] = LootRoll.roll(table, _rng(11))
	equal("the same seed rolls the same loot", LootRoll.roll(table, _rng(11)), first)
	equal("a never-dropped tier is never rolled, and both other lines turn up",
		[first.has(RELIC), first.has(HERB), first.has(RING)], [false, true, true])
	equal("a line's count gives that many of its item each time it is picked", first.count(HERB) % 2, 0)
	equal("the commoner share is picked more often", first.count(HERB) / 2 > first.count(RING), true)
	var gated := _table([_line(HERB, 1.0, 1, 1)], 3)
	gated.entries[0].needs_flag = OPEN_FLAG
	var before: int = LootRoll.roll(gated, _rng(1)).size()
	Flags.set_flag(OPEN_FLAG, true)
	equal("a line with a flag is in the table only once the flag is set",
		[before, LootRoll.roll(gated, _rng(1)).size()], [0, 3])
	var blank := _table([_line(&"", 1.0, 1, 1)], 5)
	equal("a line with no item gives nothing, and so does no table",
		[LootRoll.roll(blank, _rng(1)).size(), LootRoll.roll(null, _rng(1)).size()], [0, 0])


func _problems() -> void:
	var bad := _table([_line(HERB, -1.0, 3, 1), null], 0)
	equal("a table that never rolls, an empty line, a negative weight and a backwards count are problems",
		bad.problems("fixture").size(), 4)
	var foe := _def(&"fixture_loot_bad", &"side_b", 5.0, 0.0)
	foe.loot_table = LootTable.new()
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_loot_bad"
	encounter.enemies = [foe]
	encounter.loot_table = LootTable.new()
	equal("an encounter reports its own table's problems and each enemy's", encounter.problems().size(), 2)


func _a_won_battle() -> void:
	Flags.clear_all()
	var holder := Node.new()
	attach(holder)
	var bag := Inventory.new()
	bag.save_id = &"fixture_loot_bag"
	holder.add_child(bag)
	var foe := _def(&"fixture_loot_prey", &"side_b", 5.0, 0.0)
	foe.loot_table = _table([_line(RING, 1.0, 1, 1)], 1)
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_loot"
	encounter.enemies = [foe]
	encounter.loot = [HERB]
	encounter.loot_table = _table([_line(HERB, 1.0, 2, 2)], 1)
	var battle := BattleSetup.build(encounter, [_def(&"fixture_loot_hero", &"side_a", 40.0, 50.0)], holder, _rng(3))
	battle.next_turn()
	battle.act(BattleCommand.new(), [battle.enemies[0]])
	var given: Rewards = Rewards.grant(battle, encounter, bag)
	equal("a win gives the guaranteed loot, then the encounter's roll, then each enemy's",
		[given.items, bag.count_of(HERB), bag.count_of(RING)], [[HERB, HERB, HERB, RING], 3, 1])
	BattleSetup.release(battle)
	for actor: Node in holder.get_children():
		actor.free()
	holder.free()


func _a_field_enemy() -> void:
	Events.field_enemy_defeated.connect(_on_enemy_defeated)
	var def := _def(&"fixture_loot_brute", &"side_b", 10.0, 0.0)
	def.loot_table = _table([_line(RING, 1.0, 2, 2)], 1)
	var enemy := build("res://scenes/objects/action_enemy.tscn") as ActionEnemy
	enemy.name = "FixtureLootBrute"
	enemy.fighter = def
	enemy.brain = ActionBrain.new()
	enemy.loot = [HERB]
	attach(enemy)
	Vitals.of(enemy).change(&"hp", -100)
	enemy.act(0.1)
	Events.field_enemy_defeated.disconnect(_on_enemy_defeated)
	equal("a fallen field enemy announces its own loot and what its fighter's table rolled",
		_announced, [[HERB, RING, RING]])
	enemy.free()


# The game's real rarity files, whatever they are: each must be sound and have a name the
# CSV translates. A game with none passes.
func _the_games_own_tiers() -> void:
	var unnamed: Array[StringName] = []
	for tier: Rarity in RarityDb.ranked():
		if tr(tier.name_key) == tier.name_key:
			unnamed.append(tier.id)
	equal("the game's own tiers have no problems and every one has a translated name",
		[RarityDb.problems().size(), unnamed], [0, []])


func _on_enemy_defeated(_who: StringName, _experience: int, loot: Array[StringName]) -> void:
	_announced.append(loot)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _line(item_id: StringName, weight: float, low: int, high: int) -> LootEntry:
	var line := LootEntry.new()
	line.item_id = item_id
	line.weight = weight
	line.min_count = low
	line.max_count = high
	return line


func _table(lines: Array, rolls: int) -> LootTable:
	var table := LootTable.new()
	table.entries.assign(lines)
	table.rolls = rolls
	return table


func _def(id: StringName, side: StringName, hp: float, attack: float) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "ui.cancel"
	def.faction = side
	def.base_stats = {&"max_hp": hp, &"speed": attack + 1.0, &"attack": attack}
	return def


func _write_content() -> void:
	_directory = RunScratch.path("loot")
	var gear_dir: String = _directory.path_join("gear")
	var tier_dir: String = _directory.path_join("rarities")
	DirAccess.make_dir_recursive_absolute(gear_dir)
	DirAccess.make_dir_recursive_absolute(tier_dir)
	_tier(tier_dir, "fixture_fine", 1, 1.5, 0.5)
	_tier(tier_dir, "fixture_only", 2, 1.0, 0.0)
	_piece(gear_dir, "fixture_ring", RING, FINE)
	_piece(gear_dir, "fixture_relic", RELIC, ONLY)
	RarityDb.content_dir = tier_dir
	RarityDb.rescan()
	GearDb.content_dir = gear_dir
	GearDb.rescan()


func _tier(directory: String, name: String, rank: int, scale: float, weight: float) -> void:
	var made := Rarity.new()
	made.id = StringName(RarityDb.ID_PREFIX + name)
	made.name_key = "ui.cancel"
	made.rank = rank
	made.stat_scale = scale
	made.drop_weight = weight
	ResourceSaver.save(made, directory.path_join(name + ".tres"))


func _piece(directory: String, name: String, item_id: StringName, tier: StringName) -> void:
	var kind := GearType.new()
	kind.type_id = StringName("gear_type/" + name)
	kind.name_key = "ui.cancel"
	kind.slots = [&"accessory_1"]
	var made := GearDefinition.new()
	made.id = StringName(GearDb.ID_PREFIX + name)
	made.item_id = item_id
	made.type = kind
	made.rarity = tier
	made.modifiers = [StatModifier.of(&"defence", StatModifier.Op.ADD, 2.0, &"")]
	ResourceSaver.save(made, directory.path_join(name + ".tres"))
