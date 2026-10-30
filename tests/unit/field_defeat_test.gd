extends TestCase
## Defeat, rewards and respawn in the field (C3.8): `Rewards.give` rewards with no battle; a
## field kill's reward skips a fallen player; a fallen enemy announces its defeat once with its
## experience and loot, lies there `linger` seconds and is removed; one that remembers its
## defeat stays gone; and the player's `FieldDefeat` holds them still on the ground, then gets
## them up by the loadout's rule.
##
## OWNS: assertions about `Rewards.give`, `ActionHost.reward`, `ActionEnemy`'s defeat and
## `FieldDefeat`.
## MUST NOT: name a game's items, enemies or areas. Items come from `FixtureContent`.

var _announced: Array = []


func run() -> void:
	plan(12)
	Fixtures.activate()
	SaveFixture.activate()
	Flags.clear_all()
	Events.field_enemy_defeated.connect(_on_enemy_defeated)
	_rewards()
	_a_fallen_enemy()
	_the_player_falls()
	Events.field_enemy_defeated.disconnect(_on_enemy_defeated)
	Flags.clear_all()
	Fixtures.deactivate()


func _member(id: StringName) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.faction = &"player"
	def.base_stats = {&"max_hp": 40.0}
	def.level_curve = LevelCurve.new()
	return def


func _rewards() -> void:
	var holder := Node.new()
	holder.add_child(Vitals.new())
	var bag := Inventory.new()
	bag.save_id = &"fixture_field_bag"
	holder.add_child(bag)
	var combatant := Combatant.new()
	combatant.base_stats = {&"max_hp": 10.0}
	holder.add_child(combatant)
	attach(holder)
	var given: Rewards = Rewards.give(50, [FixtureContent.STACK_ITEM], [_member(&"fixture_victor")], bag)
	equal("give needs no battle: experience levels the member, loot lands in the bag",
		[given.levelled, bag.count_of(FixtureContent.STACK_ITEM)], [[&"fixture_victor"], 1])
	var loadout := ActionLoadout.new()
	loadout.fighter = _member(&"fixture_runner")
	equal("a field kill rewards the loadout's fighter",
		ActionHost.reward(50, [], holder, loadout).levelled, [&"fixture_runner"])
	Vitals.of(holder).change(&"hp", -100)
	var late: Rewards = ActionHost.reward(50, [FixtureContent.STACK_ITEM], holder, loadout)
	equal("a fallen player gets no experience, but the loot still lands",
		[late.levelled, bag.count_of(FixtureContent.STACK_ITEM)], [[], 2])
	holder.free()


func _enemy(remember: bool) -> ActionEnemy:
	var def := CombatantDef.new()
	def.combatant_id = &"fixture_brute"
	def.faction = &"side_b"
	def.base_stats = {&"max_hp": 10.0}
	var made := build("res://scenes/objects/action_enemy.tscn") as ActionEnemy
	made.name = "FixtureBrute"
	made.fighter = def
	made.brain = ActionBrain.new()
	made.experience = 7
	made.loot = [FixtureContent.STACK_ITEM]
	made.linger = 0.5
	made.remember_defeat = remember
	attach(made)
	return made


func _a_fallen_enemy() -> void:
	var enemy := _enemy(false)
	Vitals.of(enemy).change(&"hp", -100)
	_announced.clear()
	enemy.act(0.1)
	enemy.act(0.1)
	equal("a fallen enemy announces its defeat once, with its experience and loot",
		_announced, [[7, [FixtureContent.STACK_ITEM]]])
	equal("and lies there a while", enemy.is_queued_for_deletion(), false)
	enemy.act(0.4)
	equal("then is removed", enemy.is_queued_for_deletion(), true)
	equal("an ordinary enemy leaves no flag, so re-entry brings it back", Flags.get_bool(enemy.defeat_flag()), false)
	enemy.free()
	var boss := _enemy(true)
	Vitals.of(boss).change(&"hp", -100)
	boss.act(0.1)
	equal("one that remembers its defeat sets its flag", Flags.get_bool(boss.defeat_flag()), true)
	boss.free()
	var again := _enemy(true)
	equal("and is gone the moment it is built again", again.is_queued_for_deletion(), true)
	again.free()


func _the_player_falls() -> void:
	var player := build("res://scenes/characters/player.tscn") as PlayerController
	attach(player)
	var loadout := ActionLoadout.new()
	loadout.fighter = _member(&"fixture_hero")
	loadout.moves = MoveSet.new()
	loadout.defeat_rule = DefeatRule.new()
	loadout.defeat_rule.kind = DefeatRule.Kind.REVIVE_IN_PLACE
	loadout.defeat_rule.delay = 1.0
	ActionHost.equip(player, loadout)
	var defeat: FieldDefeat = null
	for child: Node in player.get_children():
		if child is FieldDefeat:
			defeat = child as FieldDefeat
	equal("with no rule named, a fall respawns at the entry", FieldDefeat.new().rule.kind, DefeatRule.Kind.RESPAWN_AT_ENTRY)
	Vitals.of(player).change(&"hp", -100)
	defeat.tick(0.5)
	equal("fallen, the player is held on the ground for the delay",
		[player.input_holders().has(FieldDefeat.LOCK), Vitals.of(player).is_defeated()], [true, true])
	defeat.tick(0.6)
	equal("then gets up where they fell with half their hp, and is let go",
		[Vitals.of(player).current(&"hp"), player.input_holders().has(FieldDefeat.LOCK), defeat.applied],
		[20, false, DefeatRule.Kind.REVIVE_IN_PLACE])
	player.free()


func _on_enemy_defeated(_who: StringName, experience: int, loot: Array[StringName]) -> void:
	_announced.append([experience, loot])
