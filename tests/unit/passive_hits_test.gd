extends TestCase
## Passive hit effects (C9.2b): scaling a hit before it lands, surviving a lethal hit, an extra
## hit, and the conditions that ask about the hit itself.
##
## HOW IT COUNTS: a trigger built by `_waits` also takes 1 MP from the holder when it wakes, so
## the MP spent is the number of wakes. Hits are handed to `Combatant.receive` ready-made, so
## their amounts are exact.
##
## OWNS: assertions about `PassiveHits`, and the C9.2b parts of `PassiveEffect`,
## `PassiveEffects`, `PassiveTrigger`, `PassiveCondition` and `PassiveSet`.
## MUST NOT: name a game's passives or fighters, or wait for frames.

const E := PassiveTrigger.Event
const K := PassiveEffect.Kind
const FOE: StringName = &"fixture_hits_foe"
const ME: StringName = &"fixture_hits_holder"

var _me: Node3D
var _foe: Node3D


func run() -> void:
	plan(9)
	SaveFixture.activate()
	Flags.clear_all()
	CombatClock.reset()
	_content()
	_foe = _body(FOE, &"side_b", [])
	Combatant.of(_foe).traits = [&"dragon"]
	_scales()
	_hit_conditions()
	_extra_hit()
	_counters_end()
	_survives()
	_foe.free()
	Flags.clear_all()


func _content() -> void:
	var late: PassiveTrigger = _waits(E.TURN_START, [_effect(K.SCALE_HIT, 2.0)])
	var lucky: PassiveTrigger = _waits(E.HIT_TAKEN, [_effect(K.SURVIVE)])
	var empty: PassiveTrigger = _waits(E.HIT_DEALT, [_effect(K.EXTRA_HIT, 1.0)])
	var blind: PassiveTrigger = _waits(E.TURN_START, [])
	blind.conditions.append(_cond(PassiveCondition.Kind.HIT_TAG, &"blade"))
	var sound: PassiveTrigger = _waits(E.LETHAL_HIT, [_effect(K.SURVIVE)])
	sound.conditions.append(_cond(PassiveCondition.Kind.HIT_ELEMENT, &"fire"))
	equal("a sound lethal trigger has no problems; a scale with no hit to land, a survive "
			+ "outside LETHAL_HIT, an extra hit with no skill, and a hit check in an event with no "
			+ "hit are each flagged", [sound.problems("x").size(), late.problems("x").size(),
		lucky.problems("x").size(), empty.problems("x").size(), blind.problems("x").size()],
		[0, 1, 1, 1, 1])
	equal("a trigger that scales, and every LETHAL_HIT trigger, is early; a plain one is not",
		[late.early(), sound.early(), blind.early()], [true, true, false])


func _scales() -> void:
	_start([_waits(E.HIT_DEALT, [_effect(K.SCALE_HIT, 2.0)]), _waits(E.HIT_TAKEN, [_effect(K.SCALE_HIT, 0.5)]),
		_waits(E.CRIT_DEALT, [_effect(K.SCALE_HIT, 3.0)])])
	var dealt: int = _strike(5)
	var taken: int = _struck(10)
	equal("SCALE_HIT changes the hit before it lands: a hit the holder deals is doubled, one it "
			+ "takes is halved, and each trigger wakes once, not again after the hit",
		[dealt, taken, _wakes()], [10, 5, 2])
	var crit: DamageResult = _result(2)
	crit.critical = true
	Combatant.of(_foe).receive(crit, ME)
	equal("a critical hit is scaled by the HIT_DEALT and the CRIT_DEALT triggers, and no hit is "
			+ "left as the one landing afterwards", [40 - _hp(_foe), PassiveHits.now == null], [22, true])
	_me.free()


func _hit_conditions() -> void:
	var killer: PassiveTrigger = _waits(E.HIT_DEALT, [_effect(K.SCALE_HIT, 2.0)])
	killer.conditions.append(_cond(PassiveCondition.Kind.TARGET_TRAIT, &"dragon"))
	killer.conditions.append(_cond(PassiveCondition.Kind.HIT_ELEMENT, &"fire"))
	var after: PassiveTrigger = _waits(E.HIT_DEALT, [])
	after.conditions.append(_cond(PassiveCondition.Kind.HIT_TAG, &"blade"))
	_start([killer, after])
	var plain: int = _strike(5)
	var fire: DamageResult = _result(5)
	fire.element = &"fire"
	fire.tags = [&"blade"]
	var before: int = _hp(_foe)
	Combatant.of(_foe).receive(fire, ME)
	equal("HIT_ELEMENT and HIT_TAG read the hit that is landing, before it and after it: a fire "
			+ "hit on a dragon is doubled, and a blade hit wakes the tagged trigger",
		[plain, before - _hp(_foe), _wakes()], [5, 10, 2])
	_me.free()


func _survives() -> void:
	var guts: PassiveTrigger = _waits(E.LETHAL_HIT, [_effect(K.SURVIVE)])
	guts.limit = 1
	_start([guts])
	_struck(10)
	var hurt: int = _wakes()
	_struck(500)
	var left: Array = [_hp(_me), _wakes()]
	_struck(500)
	equal("LETHAL_HIT sleeps through a hit that does not fell; SURVIVE cuts a lethal one to "
			+ "leave 1 HP; with its limit spent the next lethal hit fells the holder",
		[hurt, left, _hp(_me)], [0, [1, 1], 0])
	_me.free()


func _extra_hit() -> void:
	var pursuit: PassiveEffect = _effect(K.EXTRA_HIT, 1.0)
	pursuit.target = PassiveEffect.Target.OTHER
	pursuit.skill = _skill()
	_start([_waits(E.HIT_DEALT, [pursuit]), _waits(E.HIT_DEALT, [_effect(K.SCALE_HIT, 2.0)])])
	var lost: int = _strike(5)
	equal("EXTRA_HIT lands a second hit on the target, and that hit wakes none of the holder's "
			+ "own dealt-hit triggers (no loop, no second scaling)", [lost > 10, _wakes()], [true, 2])
	_me.free()


func _counters_end() -> void:
	var counter: PassiveEffect = _effect(K.EXTRA_HIT, 1.0)
	counter.target = PassiveEffect.Target.OTHER
	counter.skill = _skill()
	_foe.free()
	_foe = _body(FOE, &"side_b", [_passive("riposte", [_waits(E.HIT_TAKEN, [counter])])])
	_start([_waits(E.HIT_TAKEN, [counter])])
	_strike(5)
	equal("two fighters who each answer a hit with a hit stop after one answer each: a "
			+ "trigger never wakes inside itself", [_wakes(), 20 - Vitals.of(_foe).current(&"mp")], [1, 1])
	equal("and both are hurt by the other's answer", [_hp(_me) < 40, _hp(_foe) < 35], [true, true])
	_me.free()


func _start(triggers: Array[PassiveTrigger]) -> void:
	_me = _body(ME, &"side_a", [_passive("held", triggers)])
	Vitals.of(_foe).set_to(&"hp", 40)


func _wakes() -> int:
	return 20 - Vitals.of(_me).current(&"mp")


func _hp(body: Node3D) -> int:
	return Vitals.of(body).current(&"hp")


# The holder hits the foe for `amount`; returns the HP the foe lost.
func _strike(amount: int) -> int:
	var before: int = _hp(_foe)
	Combatant.of(_foe).receive(_result(amount), ME)
	return before - _hp(_foe)


# The foe hits the holder for `amount`; returns the HP the holder lost.
func _struck(amount: int) -> int:
	var before: int = _hp(_me)
	Combatant.of(_me).receive(_result(amount), FOE)
	return before - _hp(_me)


func _result(amount: int) -> DamageResult:
	var made := DamageResult.new()
	made.amount = float(amount)
	return made


func _skill() -> Skill:
	var made := Skill.new()
	made.power = 10.0
	made.sure_hit = true
	return made


func _body(id: StringName, side: StringName, passives: Array[PassiveSkill]) -> Node3D:
	var body := Node3D.new()
	body.add_child(Vitals.new())
	body.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = id
	fighter.faction = side
	fighter.base_stats = {&"max_hp": 40.0, &"max_mp": 20.0, &"attack": 2.0, &"defence": 1.0}
	body.add_child(fighter)
	attach(body)
	Vitals.of(body).set_to(&"hp", 40)
	Vitals.of(body).set_to(&"mp", 20)
	var def := CombatantDef.new()
	def.passives = passives
	PassiveSet.fit(body, def)
	return body


func _passive(name: String, triggers: Array[PassiveTrigger]) -> PassiveSkill:
	var made := PassiveSkill.new()
	made.id = StringName(PassiveDb.ID_PREFIX + "fixture_hits_" + name)
	made.name_key = "ui.cancel"
	made.triggers = triggers
	return made


# A trigger that takes 1 MP from the holder each time it wakes, then runs `effects`.
func _waits(event: PassiveTrigger.Event, effects: Array) -> PassiveTrigger:
	var made := PassiveTrigger.new()
	made.event = event
	var spend := PassiveEffect.new()
	spend.pool = &"mp"
	spend.amount = -1.0
	made.effects = [spend]
	for effect: PassiveEffect in effects:
		made.effects.append(effect)
	return made


func _effect(kind: PassiveEffect.Kind, amount: float = 0.0) -> PassiveEffect:
	var made := PassiveEffect.new()
	made.kind = kind
	made.amount = amount
	return made


func _cond(kind: PassiveCondition.Kind, tag: StringName) -> PassiveCondition:
	var made := PassiveCondition.new()
	made.kind = kind
	made.tag = tag
	return made
