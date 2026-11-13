extends TestCase
## Passive moments (C9.2c): the SKILL_USED, FORM_ENTERED and FORM_LEFT events, and the
## COOLDOWN_CUT effect.
##
## HOW IT COUNTS: each trigger built by `_waits` takes its own `cost` in MP from the holder when
## it wakes (1, 10, 100, 1000), so the digits of the MP spent say how often each one woke.
##
## OWNS: assertions about `PassiveMoments`, `PowerSet.cut_cooldowns`, and the C9.2c parts of
## `PassiveTrigger`, `PassiveEffect`, `PassiveEffects`, `PassiveSet` and `FormRun`.
## MUST NOT: name a game's passives, powers or fighters, or wait for frames.

const E := PassiveTrigger.Event
const K := PassiveEffect.Kind
const NOON: float = 12.0
const MP: int = 9000
const FOE: StringName = &"fixture_moments_foe"
const ME: StringName = &"fixture_moments_holder"
const SLASH: StringName = &"power/fixture_moments_slash"
const BURST: StringName = &"power/fixture_moments_burst"

var _me: Node3D
var _foe: Node3D
var _rng := RandomNumberGenerator.new()
var _heard: Array[int] = []


func run() -> void:
	plan(10)
	SaveFixture.activate()
	Flags.clear_all()
	CombatClock.reset()
	_rng.seed = 3
	_foe = _body(FOE, &"side_b", [])
	_content()
	_skills()
	_powers()
	_forms()
	_cooldowns()
	_foe.free()
	Flags.clear_all()


func _content() -> void:
	var nothing: PassiveEffect = _effect(K.COOLDOWN_CUT, 0.0)
	var half: PassiveEffect = _effect(K.COOLDOWN_CUT, 0.0)
	half.share = 0.5
	var aimed: PassiveTrigger = _waits(E.SKILL_USED, 1)
	aimed.effects[0].target = PassiveEffect.Target.OTHER
	equal("a cooldown cut by nothing is flagged, one by a share is not, and a skill-used "
			+ "trigger has no other fighter to aim at", [nothing.problems("x").size(),
		half.problems("x").size(), aimed.problems("x").size(),
		_waits(E.FORM_LEFT, 1).problems("x").size()], [1, 0, 1, 0])


func _skills() -> void:
	var tagged: PassiveTrigger = _waits(E.SKILL_USED, 10)
	tagged.tag = &"blade"
	var pursuit: PassiveEffect = _effect(K.EXTRA_HIT, 1.0)
	pursuit.target = PassiveEffect.Target.OTHER
	pursuit.skill = _skill([&"blade"])
	var follows: PassiveTrigger = _waits(E.HIT_DEALT, 100)
	follows.effects.append(pursuit)
	_start([_waits(E.SKILL_USED, 1), tagged, follows], null)
	var plain: Skill = _skill([])
	plain.hits = 3
	SkillUse.apply(Combatant.of(_me), plain, [Combatant.of(_foe)], _rng)
	equal("a skill of three hits is one use: the plain trigger wakes once and the one "
			+ "waiting for a tag stays asleep, though each hit woke an extra hit carrying that tag",
		[_spent() % 100, _spent() >= 100], [1, true])
	SkillUse.apply(Combatant.of(_me), _skill([&"fire", &"blade"]), [Combatant.of(_foe)], _rng)
	equal("a skill carrying the tag wakes both", _spent() % 100, 12)
	_me.free()


func _powers() -> void:
	var tagged: PassiveTrigger = _waits(E.SKILL_USED, 10)
	tagged.tag = &"blade"
	_start([_waits(E.SKILL_USED, 1), tagged], _kit())
	var me: Combatant = Combatant.of(_me)
	var kit: PowerKit = PowerSet.of(_me).kit
	equal("a power with a skill is one use, and its skill's tag is seen",
		[PowerUse.use(me, kit.powers[0], [Combatant.of(_foe)], _rng, NOON), _spent()], [true, 11])
	equal("a power with no skill wakes only the trigger that asks for no tag",
		[PowerUse.use(me, kit.powers[2], [], _rng, NOON), _spent()], [true, 12])
	PowerUse.use(me, kit.powers[2], [], _rng, NOON)
	_me.free()


func _forms() -> void:
	_start([_waits(E.FORM_ENTERED, 100), _waits(E.FORM_LEFT, 1000)], _kit())
	var me: Combatant = Combatant.of(_me)
	var kit: PowerKit = PowerSet.of(_me).kit
	PowerUse.use(me, kit.powers[2], [], _rng, NOON)
	equal("entering a form wakes FORM_ENTERED once", _spent(), 100)
	PowerUse.use(me, kit.powers[2], [], _rng, NOON)
	equal("leaving it wakes FORM_LEFT once", _spent(), 1100)
	for i: int in 3:
		PowerUse.use(me, kit.powers[3], [], _rng, NOON)
	equal("a cycle is entered once; moving between its stages is neither event", _spent(), 1200)
	StatusSet.of(_me).cure(&"status/fixture_moments_stage_2")
	PowerSet.of(_me).tick_turn()
	Vitals.of(_me).set_to(&"devil", 2)
	PowerUse.use(me, kit.powers[4], [], _rng, NOON)
	PowerSet.of(_me).tick_turn()
	equal("a form cured from outside is heard as left when it is next read, and one drained "
			+ "dry is left too", _spent(), 3300)
	_me.free()


func _cooldowns() -> void:
	var cut: PassiveEffect = _effect(K.COOLDOWN_CUT, 1.0)
	cut.share = 0.5
	var hasty: PassiveTrigger = _waits(E.TURN_START, 1)
	hasty.effects.append(cut)
	_start([hasty], _kit())
	var me: Combatant = Combatant.of(_me)
	var powers: PowerSet = PowerSet.of(_me)
	PowerUse.use(me, powers.kit.powers[0], [Combatant.of(_foe)], _rng, NOON)
	PowerUse.use(me, powers.kit.powers[1], [Combatant.of(_foe)], _rng, NOON)
	Events.power_cooldown_changed.connect(_on_cooldown)
	PassiveSet.turn(_me)
	var once: Array[float] = [powers.cooldown_left(SLASH), powers.cooldown_left(BURST)]
	PassiveSet.turn(_me)
	Events.power_cooldown_changed.disconnect(_on_cooldown)
	equal("COOLDOWN_CUT takes its share off each cooldown, then its amount; a cooldown cut to "
			+ "nothing is over, the power can be used again, and each change is announced",
		[once, powers.cooldown_left(SLASH), powers.cooldown_left(BURST),
		PowerUse.refusal(me, powers.kit.powers[0], NOON) == PowerUse.Reason.NONE, _heard],
		[[1.0, 4.0], 0.0, 1.0, true, [1, 4, 0, 1]])
	_me.free()


func _on_cooldown(_who: StringName, _power_id: StringName, left: int) -> void:
	_heard.append(left)


func _start(triggers: Array[PassiveTrigger], kit: PowerKit) -> void:
	var passive := PassiveSkill.new()
	passive.id = StringName(PassiveDb.ID_PREFIX + "fixture_moments_held")
	passive.name_key = "ui.cancel"
	passive.triggers = triggers
	_me = _body(ME, &"side_a", [passive])
	if kit != null:
		_me.add_child(PowerSet.new())
		PowerSet.of(_me).equip(kit)
	Vitals.of(_foe).set_to(&"hp", 4000)


func _spent() -> int:
	return MP - Vitals.of(_me).current(&"mp")


func _body(id: StringName, side: StringName, passives: Array[PassiveSkill]) -> Node3D:
	var body := Node3D.new()
	body.add_child(Vitals.new())
	body.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = id
	fighter.faction = side
	fighter.base_stats = {&"max_hp": 4000.0, &"max_mp": float(MP), &"max_devil": 10.0,
		&"attack": 2.0, &"defence": 1.0}
	body.add_child(fighter)
	attach(body)
	Vitals.of(body).set_to(&"hp", 4000)
	Vitals.of(body).set_to(&"mp", MP)
	var def := CombatantDef.new()
	def.passives = passives
	PassiveLending.own(body, def)
	return body


# Two powers with a skill and a cooldown (4 and 10 turns), a plain form, a cycle of three
# stages, and a form that drains a pool.
func _kit() -> PowerKit:
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_moments"
	kit.name_key = "fixture.kit"
	kit.powers = [_power(SLASH, 4.0, null), _power(BURST, 10.0, null),
		_power(&"power/fixture_moments_form", 0.0, _form(&"status/fixture_moments_form"))]
	var cycle := FormMechanism.new()
	for i: int in 3:
		cycle.cycle.append(_form(StringName("status/fixture_moments_stage_%d" % i)))
	kit.powers.append(_power(&"power/fixture_moments_cycle", 0.0, cycle))
	var hungry: FormMechanism = _form(&"status/fixture_moments_hungry")
	hungry.drain_pool = &"devil"
	hungry.drain_per_turn = 2.0
	kit.powers.append(_power(&"power/fixture_moments_hungry", 0.0, hungry))
	return kit


func _form(status_id: StringName) -> FormMechanism:
	var form := FormMechanism.new()
	form.status = StatusEffect.new()
	form.status.id = status_id
	form.status.name_key = "fixture.status"
	return form


# A power with a mechanism runs it alone; one without lands a skill tagged `blade`.
func _power(id: StringName, cooldown: float, mechanism: FormMechanism) -> Power:
	var power := Power.new()
	power.power_id = id
	power.name_key = "fixture.power"
	power.cooldown = cooldown
	power.mechanism = mechanism
	if mechanism == null:
		power.skill = _skill([&"blade"])
	return power


func _skill(tags: Array[StringName]) -> Skill:
	var made := Skill.new()
	made.power = 1.0
	made.sure_hit = true
	made.tags = tags
	return made


# A trigger that takes `cost` MP from the holder each time it wakes.
func _waits(event: PassiveTrigger.Event, cost: int) -> PassiveTrigger:
	var made := PassiveTrigger.new()
	made.event = event
	made.effects = [_effect(K.POOL_FLAT, -float(cost))]
	made.effects[0].pool = &"mp"
	return made


func _effect(kind: PassiveEffect.Kind, amount: float) -> PassiveEffect:
	var made := PassiveEffect.new()
	made.kind = kind
	made.amount = amount
	return made
