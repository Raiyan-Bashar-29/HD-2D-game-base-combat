extends TestCase
## Refuse before paying, and battle hits that break battlefields (C10.7): an order the foe will
## not take costs nothing and starts no cooldown; a form that drains a pool cannot be entered on
## an empty one; a power with no skill wakes SKILL_DONE; a battle skill or hit carrying a tag
## a battlefield is broken by brings it down.
##
## OWNS: assertions about `PowerExecutor.refuses`, `PowerUse`'s drained-form refusal, its
## SKILL_DONE for a skill-less power, and `Combatant.hit` breaking battlefields.
## MUST NOT: name a game's kits, powers or characters.

const DOMAIN: StringName = &"status/fixture_pay_domain"
const DONE: StringName = &"status/fixture_pay_done"
const HOLY: StringName = &"fixture_holy"

var _holder: Node
var _field: Power
var _order: Power
var _form: Power
var _broken: int = 0


func run() -> void:
	plan(5)
	Flags.clear_all()
	_holder = Node.new()
	attach(_holder)
	var hero: CombatantDef = _def(&"fixture_pay_hero", &"side_a", 9.0)
	hero.power_kit = _kit()
	hero.passives = [_done_passive()]
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_pay"
	encounter.enemies = [_def(&"fixture_pay_foe", &"side_b", 1.0)]
	var battle: Battle = BattleSetup.build(encounter, [hero], _holder, RandomNumberGenerator.new())
	battle.next_turn()
	Events.battlefield_lowered.connect(_on_lowered)
	_checks(battle, battle.party[0], battle.enemies[0])
	Events.battlefield_lowered.disconnect(_on_lowered)
	BattleSetup.release(battle)
	_holder.free()
	Flags.clear_all()


func _checks(battle: Battle, hero: Combatant, foe: Combatant) -> void:
	var vitals: Vitals = Vitals.of(hero.get_parent())
	vitals.set_to(&"mp", 0)
	var empty: PowerUse.Reason = PowerUse.refusal(hero, _form)
	vitals.set_to(&"mp", 20)
	equal("a form that drains mp is refused on an empty pool, and allowed with some",
		[empty, PowerUse.refusal(hero, _form)], [PowerUse.Reason.POOL, PowerUse.Reason.NONE])
	foe.traits.append(&"fixture_proud")
	equal("an order the foe will not take is refused before paying: mp kept, no cooldown",
		[PowerUse.use(hero, _order, [foe], battle.rng), vitals.current(&"mp"),
			PowerSet.of(hero.get_parent()).cooldown_left(_order.power_id)], [false, 20, 0.0])
	battle.act(BattleCommand.for_power(_field), [])
	equal("a power with no skill wakes SKILL_DONE, and the battlefield stands",
		[_stacks(hero, DONE), _stacks(hero, DOMAIN)], [1, 1])
	var smite := Skill.new()
	smite.id = &"skill/fixture_pay_smite"
	smite.power = 1.0
	smite.sure_hit = true
	smite.tags = [HOLY]
	SkillUse.apply(foe, smite, [hero], battle.rng)
	equal("a battle skill tagged as its breaker brings it down, broken", [_stacks(hero, DOMAIN), _broken], [0, 1])
	PowerUse.use(hero, _field, [], battle.rng)
	var raised: int = _stacks(hero, DOMAIN)
	foe.hit(hero, 1.0, HOLY, battle.rng, true)
	equal("and so does a plain battle hit of that element", [raised, _stacks(hero, DOMAIN), _broken], [1, 0, 2])


func _stacks(fighter: Combatant, id: StringName) -> int:
	return StatusSet.of(fighter.get_parent()).stacks(id)


func _kit() -> PowerKit:
	var field := BattlefieldMechanism.new()
	field.status = _status(DOMAIN)
	field.turns = 5
	field.broken_by_tags = [HOLY]
	var lift := BattlefieldEffect.new()
	lift.who = BattlefieldEffect.Who.CASTER_SIDE
	lift.modifiers = [StatModifier.of(&"attack", StatModifier.Op.ADD, 1.0, &"")]
	field.effects = [lift]
	_field = _power(&"power/fixture_pay_field", field, null)
	var order := CommandMechanism.new()
	order.order = CommandMechanism.Order.FORGET
	order.immune_tag = &"fixture_proud"
	var fee := Skill.new()
	fee.id = &"skill/fixture_pay_fee"
	fee.name_key = "fixture.skill"
	fee.cost_pool = &"mp"
	fee.cost = 3
	_order = _power(&"power/fixture_pay_order", order, fee)
	_order.cooldown = 5.0
	var form := FormMechanism.new()
	form.status = _status(&"status/fixture_pay_form")
	form.drain_pool = &"mp"
	form.drain_per_turn = 1.0
	_form = _power(&"power/fixture_pay_form", form, null)
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_pay"
	kit.name_key = "fixture.kit"
	kit.powers = [_field, _order, _form]
	return kit


func _power(id: StringName, mechanism: PowerMechanism, skill: Skill) -> Power:
	var made := Power.new()
	made.power_id = id
	made.name_key = "fixture.power"
	made.mechanism = mechanism
	made.skill = skill
	return made


func _done_passive() -> PassiveSkill:
	var effect := PassiveEffect.new()
	effect.kind = PassiveEffect.Kind.GIVE_STATUS
	effect.status = _status(DONE)
	var trigger := PassiveTrigger.new()
	trigger.event = PassiveTrigger.Event.SKILL_DONE
	trigger.effects = [effect]
	var made := PassiveSkill.new()
	made.id = StringName(PassiveDb.ID_PREFIX + "fixture_pay_done")
	made.name_key = "ui.cancel"
	made.triggers = [trigger]
	return made


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
	def.base_stats = {&"max_hp": 99.0, &"max_mp": 20.0, &"speed": speed, &"attack": 6.0, &"defence": 1.0}
	return def


func _on_lowered(_who: StringName, _power_id: StringName, broken: bool) -> void:
	if broken:
		_broken += 1
