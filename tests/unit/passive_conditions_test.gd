extends TestCase
## Passive conditions and the second batch of events (C9.2a): a trigger's conditions, the
## crit, dodge, guard, HP-line and status-gained events, the `group` rule, and a field body
## sleeping through a turn-based battle.
##
## HOW IT COUNTS: each trigger here takes 1 MP from the holder when it wakes, so the MP spent
## is the number of wakes.
##
## OWNS: assertions about `PassiveCondition`, `PassiveConditions`, and the C9.2a parts of
## `PassiveTrigger`, `PassiveSkill` and `PassiveSet`.
## MUST NOT: name a game's passives or fighters, or wait for frames.

const E := PassiveTrigger.Event
const C := PassiveCondition.Kind
const FOE: StringName = &"fixture_cond_foe"

var _me: Node3D
var _foe: Node3D


func run() -> void:
	plan(11)
	SaveFixture.activate()
	Flags.clear_all()
	CombatClock.reset()
	_content()
	_foe = _body(FOE, &"side_b", false, [])
	Combatant.of(_foe).traits = [&"dragon"]
	_pool_share()
	_tags_and_traits()
	_sides_and_clock()
	_hit_events()
	_hp_lines()
	_status_gained()
	_groups()
	_sleeps_in_battle()
	_foe.free()
	Flags.clear_all()


func _content() -> void:
	var untagged: PassiveTrigger = _waits(E.TURN_START, [_cond(C.HOLDS_TAG)])
	var unpaired: PassiveTrigger = _waits(E.TURN_START, [_cond(C.TARGET_TRAIT, &"dragon")])
	var empty: PassiveTrigger = _waits(E.TURN_START, [null])
	var sound: PassiveTrigger = _waits(E.HIT_DEALT, [_cond(C.TARGET_TRAIT, &"dragon"), _cond(C.POOL_SHARE)])
	equal("a sound trigger has no problems; a condition with no tag, a check of the other fighter "
			+ "in an event with none, and an empty condition are each flagged",
		[sound.problems("x").size(), untagged.problems("x").size(), unpaired.problems("x").size(),
		empty.problems("x").size()], [0, 1, 1, 1])


func _pool_share() -> void:
	var low: PassiveCondition = _cond(C.POOL_SHARE)
	low.high = 0.5
	var hurt: PassiveTrigger = _waits(E.TURN_START, [low])
	hurt.cooldown = 3.0
	var healthy: PassiveCondition = _cond(C.POOL_SHARE)
	healthy.high = 0.5
	healthy.negate = true
	_start([hurt, _waits(E.TURN_START, [healthy])])
	PassiveSet.turn(_me)
	var full: int = _wakes()
	Vitals.of(_me).set_to(&"hp", 10)
	PassiveSet.turn(_me)
	equal("a pool condition holds only inside its range, `negate` flips it, and a trigger kept "
			+ "asleep by a condition spends no cooldown", [full, _wakes()], [1, 2])
	_me.free()


func _tags_and_traits() -> void:
	var marked: StatusEffect = _status("marked", &"mark")
	_start([_waits(E.HIT_DEALT, [_cond(C.HOLDS_TAG, &"mark")]),
		_waits(E.HIT_DEALT, [_cond(C.TARGET_HOLDS_TAG, &"mark")]),
		_waits(E.HIT_DEALT, [_cond(C.TARGET_TRAIT, &"dragon")]),
		_waits(E.HIT_DEALT, [_cond(C.TARGET_TRAIT, &"undead")])])
	_hit(false)
	var plain: int = _wakes()
	StatusSet.of(_me).apply(marked)
	_hit(false)
	var mine: int = _wakes()
	StatusSet.of(_foe).apply(marked)
	_hit(false)
	equal("a killer wakes on a foe with its trait and not on another; the tag checks read the "
			+ "holder's statuses and the target's", [plain, mine, _wakes()], [1, 3, 6])
	StatusSet.of(_foe).cure(marked.id)
	_me.free()


func _sides_and_clock() -> void:
	var night: PassiveCondition = _cond(C.HOUR)
	night.low = 20.0
	night.high = 5.0
	_start([_waits(E.TURN_START, [_cond(C.ALONE)]), _waits(E.TURN_START, [_cond(C.ALLIES_STANDING)]),
		_waits(E.TURN_START, [_cond(C.IN_FIELD)]), _waits(E.TURN_START, [night]),
		_waits(E.TURN_START, [_cond(C.WEARING, &"fixture_ring")])])
	var was: int = Clock.hour
	Clock.set_time(Clock.day, 12)
	PassiveSet.turn(_me)
	var alone: int = _wakes()
	var friend: Node3D = _body(&"fixture_cond_friend", &"side_a", false, [])
	Clock.set_time(Clock.day, 23)
	PassiveSet.turn(_me)
	equal("alone wakes with no ally standing, allies-standing with one; a battle fighter is not "
			+ "in the field; an hour range may cross midnight; nothing worn is not wearing",
		[alone, _wakes() - alone], [1, 2])
	Clock.set_time(Clock.day, was)
	friend.free()
	_me.free()


func _hit_events() -> void:
	_start([_waits(E.CRIT_DEALT, [])])
	_hit(false)
	var plain: int = _wakes()
	_hit(true)
	equal("CRIT_DEALT wakes on the holder's critical hit only", [plain, _wakes()], [0, 1])
	_me.free()
	_start([_waits(E.DODGE, [_cond(C.TARGET_TRAIT, &"dragon")]), _waits(E.GUARD, []), _waits(E.GUARD, [])])
	Events.attack_dodged.emit(FOE, _id())
	Events.attack_dodged.emit(_id(), FOE)
	var dodged: int = _wakes()
	Events.attack_blocked.emit(_id(), FOE)
	equal("DODGE wakes when the holder dodges, knowing who it dodged; GUARD when a hit on it "
			+ "is stopped whole", [dodged, _wakes()], [1, 3])
	_me.free()


func _hp_lines() -> void:
	var above: PassiveTrigger = _waits(E.HP_ABOVE, [])
	above.threshold = 0.75
	_start([_waits(E.HP_BELOW, []), above])
	var hp: Vitals = Vitals.of(_me)
	hp.set_to(&"hp", 30)
	var before: int = _wakes()
	hp.set_to(&"hp", 15)
	hp.set_to(&"hp", 5)
	var below: int = _wakes()
	hp.set_to(&"hp", 25)
	hp.set_to(&"hp", 35)
	hp.set_to(&"hp", 15)
	equal("HP_BELOW and HP_ABOVE wake once as the HP share crosses the line, not while it stays",
		[before, below, _wakes()], [0, 1, 3])
	_me.free()


func _status_gained() -> void:
	var burn: StatusEffect = _status("burn", &"fire")
	var echo: PassiveTrigger = _waits(E.STATUS_GAINED, [])
	echo.tag = &"fire"
	var again := PassiveEffect.new()
	again.kind = PassiveEffect.Kind.GIVE_STATUS
	again.status = _status("singe", &"fire")
	echo.effects.append(again)
	_start([echo, _waits(E.STATUS_GAINED, [])])
	StatusSet.of(_me).apply(_status("chill", &"ice"))
	var other: int = _wakes()
	StatusSet.of(_me).apply(burn)
	equal("STATUS_GAINED wakes for its tag, or for any status with no tag; a status one of the "
			+ "set's own effects gives wakes nothing", [other, _wakes(),
		StatusSet.of(_me).stacks(again.status.id)], [1, 3, 1])
	_me.free()


func _groups() -> void:
	var small: PassiveSkill = _passive("small", [_waits(E.TURN_START, [])])
	small.group = &"might"
	small.rank = 1
	small.held = _status("small")
	var large: PassiveSkill = _passive("large", [])
	large.group = &"might"
	large.rank = 2
	large.held = _status("large")
	_me = _body(&"fixture_cond_holder", &"side_a", false, [small, _passive("free", [_waits(E.TURN_START, [])])])
	var passives: PassiveSet = PassiveSet.of(_me)
	var held: StatusSet = StatusSet.of(_me)
	var lone: Array = [passives.passives().size(), held.stacks(small.held.id)]
	var extra: Array[PassiveSkill] = [large]
	passives.hold(&"gear/fixture", extra)
	PassiveSet.turn(_me)
	equal("of passives sharing a group only the highest rank counts: the lower one's status "
			+ "comes off and its triggers sleep", [lone, passives.passives().size(),
		held.stacks(small.held.id), held.stacks(large.held.id), _wakes()], [[2, 1], 2, 0, 1, 1])
	passives.release(&"gear/fixture")
	equal("when the higher one goes, the lower counts again", held.stacks(small.held.id), 1)
	_me.free()


func _sleeps_in_battle() -> void:
	_me = _body(&"fixture_cond_holder", &"side_a", true, [_passive("walker", [_waits(E.HIT_TAKEN, [])])])
	_foe.free()
	_foe = _body(FOE, &"side_b", true, [])
	Events.battle_started.emit([] as Array[StringName])
	Events.combatant_damaged.emit(_id(), FOE, 4, false)
	var during: int = _wakes()
	Events.battle_ended.emit(0)
	Events.combatant_damaged.emit(_id(), FOE, 4, false)
	equal("a field body's passives sleep through a turn-based battle (its battle copy answers), "
			+ "and wake again after it", [during, _wakes()], [0, 1])
	_me.free()


func _start(triggers: Array[PassiveTrigger]) -> void:
	_me = _body(&"fixture_cond_holder", &"side_a", false, [_passive("held", triggers)])


func _id() -> StringName:
	return Combatant.of(_me).combatant_id


func _wakes() -> int:
	return 20 - Vitals.of(_me).current(&"mp")


func _hit(critical: bool) -> void:
	Events.combatant_damaged.emit(FOE, _id(), 5, critical)


func _body(id: StringName, side: StringName, real_time: bool, passives: Array[PassiveSkill]) -> Node3D:
	var body := Node3D.new()
	body.add_child(Vitals.new())
	body.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = id
	fighter.faction = side
	fighter.real_time = real_time
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
	made.id = StringName(PassiveDb.ID_PREFIX + "fixture_cond_" + name)
	made.name_key = "ui.cancel"
	made.triggers = triggers
	return made


# A trigger that takes 1 MP from the holder each time it wakes.
func _waits(event: PassiveTrigger.Event, conditions: Array) -> PassiveTrigger:
	var made := PassiveTrigger.new()
	made.event = event
	for condition: PassiveCondition in conditions:
		made.conditions.append(condition)
	var spend := PassiveEffect.new()
	spend.pool = &"mp"
	spend.amount = -1.0
	made.effects = [spend]
	return made


func _cond(kind: PassiveCondition.Kind, tag: StringName = &"") -> PassiveCondition:
	var made := PassiveCondition.new()
	made.kind = kind
	made.tag = tag
	return made


func _status(name: String, tag: StringName = &"") -> StatusEffect:
	var made := StatusEffect.new()
	made.id = StringName(StatusDb.ID_PREFIX + "fixture_cond_" + name)
	if tag != &"":
		made.tags = [tag]
	return made
