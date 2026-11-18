extends TestCase
## A power's move in a turn-based battle (C10.25): a power whose skill only pays lands its move's
## hits on a foe, with the move's element finding a weakness; a power whose skill deals damage
## keeps to the skill, so nothing lands twice; a move-only power is not "doing nothing".
##
## OWNS: assertions about `MoveInBattle` through `PowerUse` and `Power.problems`.
## MUST NOT: name a game's kits, powers or characters.

var _holder: Node
var _hits: Array[StringName] = []


func run() -> void:
	plan(3)
	SaveFixture.activate()
	Flags.clear_all()
	_holder = Node.new()
	attach(_holder)
	var special: Power = _power(&"power/fixture_mib_special", 0.0)
	var blast: Power = _power(&"power/fixture_mib_blast", 4.0)
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_mib"
	kit.name_key = "fixture.kit"
	kit.powers = [special, blast]
	var hero := _def(&"fixture_mib_hero", &"side_a", 9.0)
	hero.power_kit = kit
	var foe := _def(&"fixture_mib_foe", &"side_b", 1.0)
	foe.weak_to = [&"fixture_fire"]
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_mib"
	encounter.enemies = [foe]
	var battle: Battle = BattleSetup.build(encounter, [hero], _holder, RandomNumberGenerator.new())
	var me: Combatant = battle.party[0]
	var them: Combatant = battle.enemies[0]
	Events.combatant_damaged.connect(_on_damaged)
	PowerUse.use(me, special, [me], battle.rng)
	var from_move: int = _hits.count(them.combatant_id)
	equal("a pay-only special lands its move's three hits on a foe, and its element finds the weakness",
		[from_move, Weakness.revealed(them, &"fixture_fire")], [3, true])
	_hits.clear()
	PowerUse.use(me, blast, [them], battle.rng)
	equal("a power whose skill deals damage keeps to the skill", _hits.count(them.combatant_id), 1)
	Events.combatant_damaged.disconnect(_on_damaged)
	var bare := Power.new()
	bare.power_id = &"power/fixture_mib_bare"
	bare.name_key = "fixture.power"
	bare.move = special.move
	equal("a move-only power is not doing nothing", Array(bare.problems("x")).any(
		func(line: String) -> bool: return line.contains("does nothing")), false)
	BattleSetup.release(battle)
	_holder.free()
	Flags.clear_all()


func _power(id: StringName, skill_power: float) -> Power:
	var move := ActionMove.new()
	move.startup = 0.1
	move.active = 0.1
	move.recovery = 0.1
	move.power = 1.2
	move.hits = 3
	move.element = &"fixture_fire"
	move.hitbox_size = Vector3(1, 1, 1)
	var skill := Skill.new()
	skill.id = StringName("skill/" + String(id).get_file())
	skill.power = skill_power
	skill.sure_hit = true
	if skill_power <= 0.0:
		skill.target = FactionTable.Target.SELF
		var resolve := StatusEffect.new()
		resolve.id = &"status/fixture_mib_resolve"
		skill.statuses = [resolve]
	var made := Power.new()
	made.power_id = id
	made.name_key = "fixture.power"
	made.skill = skill
	made.move = move
	return made


func _def(id: StringName, side: StringName, speed: float) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "fixture.name." + String(id)
	def.faction = side
	def.base_stats = {&"max_hp": 300.0, &"speed": speed, &"attack": 10.0, &"defence": 1.0}
	return def


func _on_damaged(who: StringName, _by: StringName, _amount: int, _critical: bool) -> void:
	_hits.append(who)
