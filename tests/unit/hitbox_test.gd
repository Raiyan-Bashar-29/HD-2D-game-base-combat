extends TestCase
## Hitbox and hurtbox (C3.3): both sit on the C3.1 layers; a swing that is not live strikes
## nothing; a live one strikes each hurtbox once per swing, and a new swing strikes again; an
## ally, the attacker itself and a fighter already down are refused; i-frames turn a hit into a
## dodge; a hit lands through the damage formula `hits` times, chips a weakness, wears the shield
## by its poise until it breaks, and asks for a push away from the attacker; and a move wrapping
## a skill lands the skill.
##
## OWNS: assertions about `Hitbox`, `Hurtbox` and `Weakness.wear`.
## MUST NOT: name a game's fighters or moves, or wait for physics frames: `area_entered` is
## emitted by hand, the existing pattern.

var _actors: Array[Node] = []
var _dodged: int = 0
var _pushes: Array[Vector3] = []


func run() -> void:
	plan(17)
	SaveFixture.activate()
	Flags.clear_all()
	Events.attack_dodged.connect(_on_dodged)
	Events.knockback_requested.connect(_on_push)
	_layers_and_shape()
	_once_per_swing()
	_who_is_refused()
	_dodges_poise_and_knockback()
	_a_wrapped_skill()
	Events.attack_dodged.disconnect(_on_dodged)
	Events.knockback_requested.disconnect(_on_push)
	_free_all()
	Flags.clear_all()


func _actor(id: StringName, side: StringName, at: Vector3, stats: Dictionary[StringName, float]) -> Node3D:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = side
	combatant.base_stats = stats
	combatant.formula = DamageFormula.new()
	combatant.formula.stages = [AttackDefenceStage.new()]
	actor.add_child(combatant)
	actor.add_child(Hurtbox.new())
	actor.add_child(Hitbox.new())
	attach(actor)
	_actors.append(actor)
	return actor


func _free_all() -> void:
	for actor: Node in _actors:
		actor.free()
	_actors.clear()


func _hitbox(actor: Node) -> Hitbox:
	return actor.get_child(4) as Hitbox


func _hurtbox(actor: Node) -> Hurtbox:
	return actor.get_child(3) as Hurtbox


func _hp(actor: Node) -> int:
	return Vitals.of(actor).current(&"hp")


func _swing(power: float) -> ActionMove:
	var made := ActionMove.new()
	made.startup = 0.0
	made.active = 0.2
	made.recovery = 0.2
	made.power = power
	made.element = &"fixture_flame"
	made.hitbox_size = Vector3(2.0, 1.0, 1.5)
	made.hitbox_offset = Vector3(0.0, 0.5, -1.0)
	return made


## Gives `attacker` a clock playing `move`, already live.
func _arm(attacker: Node, move: ActionMove) -> MoveTimeline:
	var clock := MoveTimeline.new()
	clock.start(move)
	clock.step(0.01)
	_hitbox(attacker).timeline = clock
	_hitbox(attacker).fit(move)
	return clock


func _layers_and_shape() -> void:
	var one := _actor(&"fixture_one", &"side_a", Vector3.ZERO, {})
	equal("a hitbox is on the hitbox layer and looks for hurtboxes",
		[_hitbox(one).collision_layer, _hitbox(one).collision_mask], [CombatLayers.HITBOX, CombatLayers.HURTBOX])
	equal("a hurtbox is on the hurtbox layer and looks for nothing",
		[_hurtbox(one).collision_layer, _hurtbox(one).collision_mask], [CombatLayers.HURTBOX, 0])
	_hitbox(one).fit(_swing(1.0))
	equal("fit shapes the box to the move's size and offset", _hitbox(one).extent(),
		AABB(Vector3(-1.0, 0.0, -1.75), Vector3(2.0, 1.0, 1.5)))
	_free_all()


func _once_per_swing() -> void:
	Flags.clear_all()
	var hero := _actor(&"fixture_hero", &"side_a", Vector3.ZERO, {&"attack": 2.0})
	var foe := _actor(&"fixture_foe", &"side_b", Vector3(0, 0, -1), {&"max_hp": 50.0})
	var clock := MoveTimeline.new()
	_hitbox(hero).timeline = clock
	clock.start(_swing(3.0))
	_hitbox(hero).area_entered.emit(_hurtbox(foe))
	equal("a swing still winding up strikes nothing", _hp(foe), 50)
	clock.step(0.01)
	_hitbox(hero).area_entered.emit(_hurtbox(foe))
	equal("a live swing strikes for power plus attack, 3 + 2", _hp(foe), 45)
	_hitbox(hero).area_entered.emit(_hurtbox(foe))
	equal("but only once per swing", _hp(foe), 45)
	clock.start(_swing(3.0))
	clock.step(0.01)
	_hitbox(hero).area_entered.emit(_hurtbox(foe))
	equal("a new swing strikes again", _hp(foe), 40)
	_free_all()


func _who_is_refused() -> void:
	Flags.clear_all()
	var hero := _actor(&"fixture_hero", &"side_a", Vector3.ZERO, {&"attack": 2.0})
	var friend := _actor(&"fixture_friend", &"side_a", Vector3.ZERO, {&"max_hp": 20.0})
	var fallen := _actor(&"fixture_fallen", &"side_b", Vector3.ZERO, {&"max_hp": 20.0})
	Vitals.of(fallen).change(&"hp", -20)
	_arm(hero, _swing(3.0))
	equal("an ally is not struck", _hitbox(hero).strike(_hurtbox(friend)), false)
	equal("nor the attacker's own hurtbox", _hitbox(hero).strike(_hurtbox(hero)), false)
	equal("nor a fighter already down", _hitbox(hero).strike(_hurtbox(fallen)), false)
	_free_all()


func _dodges_poise_and_knockback() -> void:
	Flags.clear_all()
	var hero := _actor(&"fixture_hero", &"side_a", Vector3.ZERO, {&"attack": 2.0})
	var foe := _actor(&"fixture_foe", &"side_b", Vector3(3, 1, 0),
		{&"max_hp": 50.0, &"max_shield": 3.0})
	Combatant.of(foe).weak_to = [&"fixture_flame"]
	var roll := ActionMove.new()
	roll.iframes_to = 1.0
	var dodger := MoveTimeline.new()
	dodger.start(roll)
	dodger.step(0.1)
	_hurtbox(foe).timeline = dodger
	var move := _swing(3.0)
	move.hits = 2
	move.poise = 1
	move.knockback = 2.0
	_arm(hero, move)
	_dodged = 0
	_hitbox(hero).strike(_hurtbox(foe))
	equal("a hit during i-frames passes through as a dodge", [_hp(foe), _dodged], [50, 1])
	_hurtbox(foe).timeline = null
	_pushes.clear()
	_arm(hero, move)
	_hitbox(hero).strike(_hurtbox(foe))
	equal("two hits land through the formula", _hp(foe), 40)
	equal("two weakness chips and one poise point empty a 3-point shield: broken",
		StatusSet.of(foe).stacks(Weakness.broken_status().id), 1)
	equal("the weakness is revealed", Weakness.revealed(Combatant.of(foe), &"fixture_flame"), true)
	equal("one push, 2 m, flat and straight away from the attacker", _pushes, [Vector3(2, 0, 0)])
	_free_all()


func _a_wrapped_skill() -> void:
	Flags.clear_all()
	var hero := _actor(&"fixture_hero", &"side_a", Vector3.ZERO, {&"attack": 1.0})
	var foe := _actor(&"fixture_foe", &"side_b", Vector3.ZERO, {&"max_hp": 30.0})
	var spell := Skill.new()
	spell.id = &"skill/fixture_spark"
	spell.power = 4.0
	spell.hits = 2
	var move := _swing(0.0)
	move.skill = spell
	_arm(hero, move)
	equal("a move wrapping a skill strikes", move.strikes(), true)
	_hitbox(hero).strike(_hurtbox(foe))
	equal("and lands the skill: two hits of 4 + 1", _hp(foe), 20)
	_free_all()


func _on_dodged(_who: StringName, _by: StringName) -> void:
	_dodged += 1


func _on_push(_who: StringName, push: Vector3) -> void:
	_pushes.append(push)
