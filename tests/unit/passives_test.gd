extends TestCase
## Passives, the core (C9.1): a fighter's definition lists `PassiveSkill`s; each one's held
## status sits on the fighter, and each trigger wakes on its event (a fight starting, a turn, a
## hit dealt or taken, a kill, an ally falling, the last foe falling), with a chance, a
## cooldown and a limit, in a battle and in the field.
##
## OWNS: assertions about `PassiveSkill`, `PassiveTrigger`, `PassiveEffect`, `PassiveDb`,
## `PassiveSet`, `PassiveEffects` and `CombatantDef.passives`.
## MUST NOT: name a game's passives or fighters, or wait for frames.

const E := PassiveTrigger.Event
const K := PassiveEffect.Kind
const T := PassiveEffect.Target

var _last_hit: int = 0


func run() -> void:
	plan(14)
	SaveFixture.activate()
	Flags.clear_all()
	CombatClock.reset()
	_content()
	_catalogue()
	Events.combatant_damaged.connect(_on_damaged)
	_battle()
	Events.combatant_damaged.disconnect(_on_damaged)
	_chance()
	_field()
	Flags.clear_all()


func _content() -> void:
	var sound: PassiveSkill = _passive("sound", [_trigger(E.HIT_DEALT, [_pool(K.POOL_FROM_DAMAGE, &"hp", 0.2)])])
	var idle := PassiveSkill.new()
	idle.id = &"passive/fixture_idle"
	idle.name_key = "ui.cancel"
	var fading: PassiveSkill = _passive("fading", [])
	fading.held = _status("fading", 3.0)
	var odd: PassiveSkill = _passive("odd", [_trigger(E.FIGHT_START, [_pool(K.POOL_FROM_DAMAGE, &"hp", 0.2)]),
		_trigger(E.TURN_START, [_give(_status("x"), T.OTHER)]), _trigger(E.KILL, [])])
	var def := CombatantDef.new()
	def.combatant_id = &"fixture_passive_def"
	def.name_key = "ui.cancel"
	def.base_stats = {&"max_hp": 5.0}
	def.passives = [sound, null]
	equal("a sound passive has no problems; one that does nothing, a held status that runs out, "
			+ "damage or another fighter in an event with neither, no effects, and an empty entry "
			+ "in a fighter's list are each flagged", [sound.problems().size(), idle.problems().size(),
		fading.problems().size(), odd.problems().size(), def.problems("x").size()], [0, 1, 1, 3, 1])


func _catalogue() -> void:
	var directory: String = RunScratch.path("passives")
	DirAccess.make_dir_recursive_absolute(directory)
	var saved: PassiveSkill = _passive("saved", [_trigger(E.KILL, [_pool(K.POOL_FLAT, &"mp", 2.0)])])
	ResourceSaver.save(saved, directory.path_join("fixture_saved.tres"))
	equal("the real passives, or none in a stripped template, have no problems", PassiveDb.problems().size(), 0)
	PassiveDb.content_dir = directory
	PassiveDb.rescan()
	var found: PassiveSkill = PassiveDb.passive(&"passive/fixture_saved")
	equal("a passive file is found by its id, and an unknown id is null",
		[found != null and found.triggers.size() == 1, PassiveDb.passive(&"passive/none")], [true, null])
	PassiveDb.content_dir = PassiveDb.PASSIVE_DIR
	PassiveDb.rescan()


func _battle() -> void:
	var holder := Node.new()
	attach(holder)
	var strong: StatusEffect = _status("strong")
	strong.modifiers = [StatModifier.of(&"attack", StatModifier.Op.ADD, 5.0, &"")]
	var ticking: PassiveTrigger = _trigger(E.TURN_START, [_give(_status("tick", 0.0, 9))])
	ticking.cooldown = 2.0
	var once: PassiveTrigger = _trigger(E.HIT_DEALT, [_give(_status("once", 0.0, 9))])
	once.limit = 1
	var all: PassiveSkill = _passive("all", [
		_trigger(E.FIGHT_START, [_give(_status("brave")), _pool(K.POOL_FLAT, &"mp", -15.0)]),
		_trigger(E.HIT_DEALT, [_pool(K.POOL_FROM_DAMAGE, &"mp", 0.5)]), once, ticking,
		_trigger(E.KILL, [_give(_status("trophy", 0.0, 9))]),
		_trigger(E.ALLY_DEFEATED, [_give(_status("avenger"))]),
		_trigger(E.FIGHT_WON, [_give(_status("victor")), _pool(K.POOL_SHARE, &"mp", 1.0)])])
	all.held = strong
	var hero: CombatantDef = _def(&"fixture_passive_hero", &"side_a", 99.0, 9.0)
	hero.passives = [all]
	var thorny: CombatantDef = _def(&"fixture_passive_thorny", &"side_b", 99.0, 1.0)
	thorny.passives = [_passive("thorns", [_trigger(E.HIT_TAKEN, [_give(_status("thorn"), T.OTHER)])])]
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_passives"
	encounter.enemies = [_def(&"fixture_passive_weak", &"side_b", 3.0, 1.0), thorny]
	var battle: Battle = BattleSetup.build(encounter,
		[hero, _def(&"fixture_passive_friend", &"side_a", 99.0, 8.0)], holder, RandomNumberGenerator.new())
	_fight(battle, strong)
	BattleSetup.release(battle)
	holder.free()


func _fight(battle: Battle, strong: StatusEffect) -> void:
	var me: Combatant = battle.party[0]
	var body: Node = me.get_parent()
	var held: StatusSet = StatusSet.of(body)
	var mp: Vitals = Vitals.of(body)
	equal("a fighter built from a definition with passives holds them, and one with none has no set",
		[PassiveSet.of(body) != null, PassiveSet.of(battle.party[1].get_parent()),
		PassiveSet.of(body).rng == battle.rng], [true, null, true])
	equal("the held status is on while the passive is held, and is found again for a save",
		[me.sheet.value(&"attack"), PassiveSet.held_of(body, strong.id), PassiveSet.held_of(body, &"status/none")],
		[11.0, strong, null])
	equal("the battle starting wakes FIGHT_START: its status and its pool cost",
		[held.stacks(&"status/fixture_brave"), mp.current(&"mp")], [1, 5])
	battle.next_turn()
	battle.act(BattleCommand.new(), [battle.enemies[0]])
	equal("a turn beginning wakes TURN_START, a hit landing gives a share of its damage, and a "
			+ "foe falling to it is a kill", [held.stacks(&"status/fixture_tick"), _last_hit > 0,
		mp.current(&"mp"), held.stacks(&"status/fixture_trophy")],
		[1, true, mini(20, 5 + roundi(_last_hit * 0.5)), 1])
	for turn: int in 3:
		PassiveSet.turn(body)
	me.hit(battle.enemies[1], 0.0, &"", battle.rng, true)
	equal("a cooldown of 2 wakes every second turn, a limit of 1 wakes once a battle, and a hit "
			+ "taken can answer the one who hit", [held.stacks(&"status/fixture_tick"),
		held.stacks(&"status/fixture_once"), held.stacks(&"status/fixture_thorn"),
		held.stacks(&"status/fixture_trophy")], [2, 1, 1, 1])
	Vitals.of(battle.party[1].get_parent()).set_to(&"hp", 0)
	var before: int = held.stacks(&"status/fixture_victor")
	Vitals.of(battle.enemies[1].get_parent()).set_to(&"hp", 0)
	equal("an ally falling wakes ALLY_DEFEATED, and the last foe falling wakes FIGHT_WON",
		[held.stacks(&"status/fixture_avenger"), before, held.stacks(&"status/fixture_victor"),
		mp.current(&"mp"), held.stacks(&"status/fixture_trophy")], [1, 0, 1, 20, 1])
	Vitals.of(body).set_to(&"hp", 0)
	for turn: int in 3:
		PassiveSet.turn(body)
	equal("a fallen holder's passives do nothing", held.stacks(&"status/fixture_tick"), 2)


func _chance() -> void:
	var lucky: PassiveTrigger = _trigger(E.TURN_START, [_pool(K.POOL_FLAT, &"mp", -1.0)])
	lucky.chance = 0.5
	var body: Node3D = _body(&"fixture_passive_roller", &"side_a", false, [_passive("lucky", [lucky])])
	var twin := RandomNumberGenerator.new()
	twin.seed = 11
	PassiveSet.join(body, twin)
	var expected: int = 0
	var mirror := RandomNumberGenerator.new()
	mirror.seed = 11
	for turn: int in 12:
		expected += 1 if mirror.randf() < 0.5 else 0
		PassiveSet.turn(body)
	equal("a chance is rolled with the fight's own random numbers, so a seeded fight replays",
		[Vitals.of(body).current(&"mp"), expected > 0 and expected < 12], [20 - expected, true])
	body.free()


func _field() -> void:
	var entering: PassiveTrigger = _trigger(E.FIGHT_START, [_give(_status("entered", 0.0, 9)),
		_give(_status("mark"), T.FOES)])
	entering.limit = 1
	var pulse: PassiveTrigger = _trigger(E.TURN_START, [_pool(K.POOL_FLAT, &"mp", -3.0), _cure(&"curse", T.ALLIES)])
	pulse.interval = 0.5
	var field: PassiveSkill = _passive("field", [entering, pulse])
	field.held = _status("steady")
	var body: Node3D = _body(&"fixture_passive_walker", &"side_a", true, [field])
	var near: Node3D = _body(&"fixture_passive_near", &"side_b", true, [])
	var far: Node3D = _body(&"fixture_passive_far", &"side_b", true, [])
	far.global_position = Vector3(PassiveEffects.NEAR + 5.0, 0.0, 0.0)
	var held: StatusSet = StatusSet.of(body)
	var curse: StatusEffect = _status("curse")
	curse.tags = [&"curse"]
	held.apply(curse)
	var passives: PassiveSet = PassiveSet.of(body)
	Events.battle_started.emit([] as Array[StringName])
	Events.area_entered.emit(&"fixture_area")
	Events.area_entered.emit(&"fixture_area")
	equal("in the field an area entered is the fight starting, and starts the limit again; a "
			+ "battle starting is not; FOES are the standing foes near the holder",
		[held.stacks(&"status/fixture_entered"), StatusSet.of(near).stacks(&"status/fixture_mark"),
		StatusSet.of(far).stacks(&"status/fixture_mark")], [2, 1, 0])
	passives._physics_process(0.6)
	passives._physics_process(0.6)
	equal("in the field TURN_START wakes every interval of fight time, and ALLIES includes the holder",
		[Vitals.of(body).current(&"mp"), held.stacks(curse.id)], [14, 0])
	var extra: Array[PassiveSkill] = [field]
	passives.hold(&"gear/fixture", extra)
	var counted: int = passives.passives().size()
	passives.release(PassiveSet.OWN)
	var kept: int = held.stacks(&"status/fixture_steady")
	passives.release(&"gear/fixture")
	equal("the same passive from two sources counts once, stays while one source holds it, and "
			+ "its held status goes with the last", [counted, kept, held.stacks(&"status/fixture_steady"),
		passives.passives().size()], [1, 1, 0, 0])
	for made: Node3D in [body, near, far]:
		made.free()


func _on_damaged(_who: StringName, _by: StringName, amount: int, _critical: bool) -> void:
	_last_hit = amount


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
	var def := CombatantDef.new()
	def.passives = passives
	PassiveSet.fit(body, def)
	return body


func _def(id: StringName, side: StringName, hp: float, speed: float) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "ui.cancel"
	def.faction = side
	def.base_stats = {&"max_hp": hp, &"max_mp": 20.0, &"speed": speed, &"attack": 6.0, &"defence": 1.0}
	return def


func _passive(name: String, triggers: Array[PassiveTrigger]) -> PassiveSkill:
	var made := PassiveSkill.new()
	made.id = StringName(PassiveDb.ID_PREFIX + "fixture_" + name)
	made.name_key = "ui.cancel"
	made.triggers = triggers
	return made


func _trigger(event: PassiveTrigger.Event, effects: Array[PassiveEffect]) -> PassiveTrigger:
	var made := PassiveTrigger.new()
	made.event = event
	made.effects = effects
	return made


func _pool(kind: PassiveEffect.Kind, pool: StringName, amount: float) -> PassiveEffect:
	var made := PassiveEffect.new()
	made.kind = kind
	made.pool = pool
	made.amount = amount
	return made


func _give(status: StatusEffect, target: PassiveEffect.Target = T.SELF) -> PassiveEffect:
	var made := PassiveEffect.new()
	made.kind = K.GIVE_STATUS
	made.status = status
	made.target = target
	return made


func _cure(tag: StringName, target: PassiveEffect.Target) -> PassiveEffect:
	var made := PassiveEffect.new()
	made.kind = K.CURE
	made.tag = tag
	made.target = target
	return made


func _status(name: String, duration: float = 0.0, max_stacks: int = 1) -> StatusEffect:
	var made := StatusEffect.new()
	made.id = StringName(StatusDb.ID_PREFIX + "fixture_" + name)
	made.duration = duration
	made.max_stacks = max_stacks
	made.stacking = StatusEffect.Stacking.STACK if max_stacks > 1 else StatusEffect.Stacking.REFRESH
	return made
