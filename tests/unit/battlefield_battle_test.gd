extends TestCase
## Battlefields in a battle (C6.9a): raising one from the battle menu puts its effects on the
## battle's fighters and not on the field's, which wait outside on another clock; it stands for
## its turns, counted at the start of the caster's own, then ends with its aftermath; and the
## caster falling ends it. C6.9b: its on_enter skill lands as it rises, its tick on the caster's
## own turns, and its on_exit skill as it ends.
##
## OWNS: assertions about `BattlefieldRun`'s battle reading.
## MUST NOT: name a game's kits, powers or characters.

const DOMAIN: StringName = &"status/fixture_battle_field_domain"
const SLOWED: StringName = &"status/fixture_battle_field_slowed"
const BURNOUT: StringName = &"status/fixture_battle_field_burnout"

var _holder: Node
var _battle: Battle
var _power: Power
var _outside: Node


func run() -> void:
	plan(5)
	Flags.clear_all()
	_holder = Node.new()
	attach(_holder)
	_outside = _field_fighter()
	_raising_and_turns()
	_caster_falls()
	_outside.free()
	_holder.free()
	Flags.clear_all()


func _raising_and_turns() -> void:
	_start()
	var hero: Combatant = _battle.party[0]
	_battle.act(BattleCommand.for_power(_power), [])
	equal("raised in a battle, the caster's side has the modifier and every foe the status",
		[_stacks(hero, DOMAIN), hero.sheet.value(&"attack"), _stacks(_battle.enemies[0], SLOWED),
			_stacks(_battle.enemies[1], SLOWED)], [1, 10.0, 1, 1])
	equal("a fighter in the field, on the other clock, is not inside",
		StatusSet.of(_outside).stacks(SLOWED), 0)
	var risen: int = _hp(_battle.enemies[0])
	_hero_turn()
	var first: int = _stacks(_battle.enemies[0], SLOWED)
	var ticked: int = _hp(_battle.enemies[0])
	Vitals.of(_battle.enemies[0].get_parent()).set_to(&"mp", 0)
	_hero_turn()
	equal("its on_enter skill lands as it rises, its tick on the caster's turn, its on_exit as it ends",
		[risen < 99, ticked < risen, Vitals.of(_battle.enemies[0].get_parent()).current(&"mp")],
		[true, true, 2])
	equal("it stands for its turns, then ends with its aftermath and takes its effects off",
		[first, _stacks(_battle.enemies[0], SLOWED), _stacks(hero, DOMAIN), _stacks(hero, BURNOUT),
			hero.sheet.value(&"attack")], [1, 0, 0, 1, 6.0])
	_end()


func _caster_falls() -> void:
	_start()
	var hero: Combatant = _battle.party[0]
	_battle.act(BattleCommand.for_power(_power), [])
	Vitals.of(hero.get_parent()).set_to(&"hp", 0)
	equal("the caster falling ends it at once, with no aftermath",
		[_stacks(_battle.enemies[0], SLOWED), _stacks(_battle.enemies[1], SLOWED), _stacks(hero, BURNOUT)],
		[0, 0, 0])
	_end()


func _start() -> void:
	var hero: CombatantDef = _def(&"fixture_battle_field_hero", &"side_a", 9.0)
	hero.power_kit = _kit()
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_battle_field"
	encounter.enemies = [_def(&"fixture_battle_field_one", &"side_b", 1.0),
		_def(&"fixture_battle_field_two", &"side_b", 1.0)]
	_battle = BattleSetup.build(encounter, [hero], _holder, RandomNumberGenerator.new())
	_battle.rng.seed = 4
	_battle.next_turn()


func _end() -> void:
	BattleSetup.release(_battle)
	for child: Node in _holder.get_children():
		child.free()


# Plays turns until it is the hero's again, the foes waiting.
func _hero_turn() -> void:
	for turn: int in 6:
		if _battle.next_turn() == _battle.party[0]:
			return
		_battle.act(BattleCommand.new(), [_battle.party[0]])


func _hp(fighter: Combatant) -> int:
	return Vitals.of(fighter.get_parent()).current(&"hp")


func _stacks(fighter: Combatant, id: StringName) -> int:
	return StatusSet.of(fighter.get_parent()).stacks(id)


# A real-time fighter of the other side, standing in the field while the battle runs.
func _field_fighter() -> Node:
	var actor := Node3D.new()
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = &"fixture_battle_field_wanderer"
	fighter.faction = &"side_b"
	fighter.real_time = true
	fighter.base_stats = {&"max_hp": 10.0}
	actor.add_child(fighter)
	attach(actor)
	return actor


func _kit() -> PowerKit:
	var field := BattlefieldMechanism.new()
	field.status = _status(DOMAIN)
	field.turns = 2
	field.aftermath = _status(BURNOUT)
	var lift := BattlefieldEffect.new()
	lift.who = BattlefieldEffect.Who.CASTER_SIDE
	lift.modifiers = [StatModifier.of(&"attack", StatModifier.Op.ADD, 4.0, &"")]
	var slow := BattlefieldEffect.new()
	slow.who = BattlefieldEffect.Who.OTHER_SIDE
	slow.statuses = [_status(SLOWED)]
	slow.on_enter = _skill(&"fixture_battle_field_blast", 5.0, null)
	slow.tick = _skill(&"fixture_battle_field_rain", 5.0, null)
	slow.tick_turns = 1
	var gift := SkillEffect.new()
	gift.kind = SkillEffect.Kind.RESTORE
	gift.amount = 2.0
	slow.on_exit = _skill(&"fixture_battle_field_after", 0.0, gift)
	field.effects = [lift, slow]
	_power = Power.new()
	_power.power_id = &"power/fixture_battle_field"
	_power.name_key = "fixture.power"
	_power.mechanism = field
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_battle_field"
	kit.name_key = "fixture.kit"
	kit.powers = [_power]
	return kit


# A sure hit of `power`, or, with `effect`, a skill that only does that effect.
func _skill(id: StringName, power: float, effect: SkillEffect) -> Skill:
	var skill := Skill.new()
	skill.id = id
	skill.name_key = "fixture.skill"
	skill.power = power
	skill.sure_hit = true
	if effect != null:
		skill.target = FactionTable.Target.ALLY
		skill.effects = [effect]
	return skill


func _status(id: StringName) -> StatusEffect:
	var status := StatusEffect.new()
	status.id = id
	status.name_key = "fixture.status"
	return status


func _def(id: StringName, side: StringName, speed: float) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "fixture.name." + String(id)
	def.faction = side
	def.base_stats = {&"max_hp": 99.0, &"max_mp": 20.0, &"speed": speed, &"attack": 6.0,
		&"defence": 1.0, &"evasion": 0.0}
	return def
