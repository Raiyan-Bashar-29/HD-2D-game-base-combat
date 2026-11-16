extends TestCase
## The clone in a battle (C6.13b): after the use, each of the user's next `actions` turns is
## doubled, every hurt it deals dealt again at `power_fraction`; the turn after is plain.
##
## OWNS: assertions about `CloneRun` in a battle.
## MUST NOT: name a game's kits, powers or characters.

var _hits: Array[int] = []
var _hero_id: StringName = &""


func run() -> void:
	plan(3)
	Flags.clear_all()
	var holder := Node.new()
	attach(holder)
	var clone := CloneMechanism.new()
	clone.actions = 2
	clone.power_fraction = 0.5
	var power := Power.new()
	power.power_id = &"power/fixture_clone_battle"
	power.name_key = "fixture.power"
	power.mechanism = clone
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_clone_battle"
	kit.name_key = "fixture.kit"
	kit.powers = [power]
	var hero: CombatantDef = _def(&"fixture_clone_hero", &"side_a", 9.0)
	hero.power_kit = kit
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_clone"
	encounter.enemies = [_def(&"fixture_clone_foe", &"side_b", 1.0)]
	var battle: Battle = BattleSetup.build(encounter, [hero], holder, RandomNumberGenerator.new())
	battle.rng.seed = 5
	_hero_id = battle.party[0].combatant_id
	Events.combatant_damaged.connect(_on_damaged)
	battle.next_turn()
	equal("the clone is used on the hero's turn", battle.act(BattleCommand.for_power(power), []), true)
	var counts: Array[int] = []
	var pairs: Array[int] = []
	for turn: int in 3:
		_hits.clear()
		_hero_turn(battle)
		battle.act(BattleCommand.new(), [battle.enemies[0]])
		counts.append(_hits.size())
		if turn == 0:
			pairs = _hits.duplicate()
	equal("the next two turns hit twice, the third once", counts, [2, 2, 1])
	equal("the second hit is half the first", pairs[1], roundi(pairs[0] * 0.5))
	Events.combatant_damaged.disconnect(_on_damaged)
	BattleSetup.release(battle)
	holder.free()


# Plays the foe's turns (a plain attack on the hero) until it is the hero's turn.
func _hero_turn(battle: Battle) -> void:
	for _i: int in 6:
		if battle.next_turn() == battle.party[0]:
			return
		battle.act(BattleCommand.new(), [battle.party[0]])


func _on_damaged(_who: StringName, by: StringName, amount: int, _critical: bool) -> void:
	if by == _hero_id:
		_hits.append(amount)


func _def(id: StringName, side: StringName, speed: float) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "fixture.name." + String(id)
	def.faction = side
	def.base_stats = {&"max_hp": 999.0, &"speed": speed, &"attack": 20.0, &"defence": 1.0}
	return def
