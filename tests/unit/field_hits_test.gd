extends TestCase
## Field hits (C10.16): a move that wraps a skill reports a blocked hit and a miss, so neither
## counts as landed, and a timed press grows the skill; a several-hit move with `hit_gap` lands
## one hit a strike, that far apart, never more than its hits; with no gap all land at once.
##
## OWNS: assertions about the skill path of `Hurtbox._resolve` and `Hitbox`'s spaced hits.
## MUST NOT: name a game's fighters or moves, or wait for frames.

var _world: Node3D
var _rng := RandomNumberGenerator.new()


func run() -> void:
	plan(5)
	SaveFixture.activate()
	Flags.clear_all()
	_world = Node3D.new()
	attach(_world)
	_wrapped_skills()
	_spaced()
	_world.free()
	Flags.clear_all()


func _wrapped_skills() -> void:
	var me: Combatant = _fighter(&"fixture_fh_me", Vector3.ZERO, {})
	var shining: Combatant = _fighter(&"fixture_fh_shining", Vector3(3, 0, 0), {})
	var guard := StatusEffect.new()
	guard.id = &"status/fixture_fh_guard"
	guard.duration = 0.0
	guard.invincible = true
	StatusSet.of(shining.get_parent()).apply(guard)
	var spark: ActionMove = _move(1, 0.0)
	spark.skill = Skill.new()
	spark.skill.id = &"skill/fixture_fh_spark"
	spark.skill.power = 10.0
	spark.skill.sure_hit = true
	_hurtbox(shining).take(me, spark, _rng, Vector3.ZERO)
	equal("a wrapped skill stopped by invincibility is not landed", _hurtbox(shining).landed, false)
	var slippery: Combatant = _fighter(&"fixture_fh_slippery", Vector3(6, 0, 0), {&"evasion": 5.0})
	var wide := spark.duplicate() as ActionMove
	wide.skill = spark.skill.duplicate() as Skill
	wide.skill.sure_hit = false
	_hurtbox(slippery).take(me, wide, _rng, Vector3.ZERO)
	equal("a wrapped skill that misses is not landed either", _hurtbox(slippery).landed, false)
	var plain: Combatant = _fighter(&"fixture_fh_plain", Vector3(9, 0, 0), {})
	var boosted: Combatant = _fighter(&"fixture_fh_boosted", Vector3(12, 0, 0), {})
	_hurtbox(plain).take(me, spark, _rng, Vector3.ZERO)
	_hurtbox(boosted).take(me, spark, _rng, Vector3.ZERO, 1.5)
	equal("a timed press grows the wrapped skill", [_lost(boosted) > _lost(plain), _hurtbox(plain).landed], [true, true])


func _spaced() -> void:
	var me: Combatant = _fighter(&"fixture_fh_swinger", Vector3(30, 0, 0), {})
	var foe: Combatant = _fighter(&"fixture_fh_foe", Vector3(30, 0, 0.5), {})
	var hitbox := Hitbox.new()
	hitbox.attacker = me
	hitbox.rng = _rng
	hitbox.timeline = MoveTimeline.new()
	me.get_parent().add_child(hitbox)
	var flurry: ActionMove = _move(3, 0.1)
	flurry.power = 5.0
	hitbox.timeline.start(flurry)
	hitbox.timeline.step(0.01)
	var landed: Array[bool] = [hitbox.strike(_hurtbox(foe)), hitbox.strike(_hurtbox(foe))]
	for i: int in 3:
		hitbox.timeline.step(0.1)
		landed.append(hitbox.strike(_hurtbox(foe)))
	equal("with a gap, one hit a strike, that far apart, and no more than its hits",
		landed, [true, false, true, true, false] as Array[bool])
	var other: Combatant = _fighter(&"fixture_fh_other", Vector3(40, 0, 0), {})
	var before: int = Vitals.of(other.get_parent()).current(&"hp")
	var burst: ActionMove = _move(3, 0.0)
	burst.power = 5.0
	_hurtbox(other).take(me, burst, _rng, Vector3.ZERO)
	equal("with no gap all its hits land at once", before - Vitals.of(other.get_parent()).current(&"hp") >= 3 * 9, true)


func _lost(fighter: Combatant) -> int:
	return 100 - Vitals.of(fighter.get_parent()).current(&"hp")


func _move(hits: int, gap: float) -> ActionMove:
	var move := ActionMove.new()
	move.startup = 0.0
	move.active = 1.0
	move.recovery = 0.1
	move.power = 0.0
	move.hits = hits
	move.hit_gap = gap
	move.hitbox_size = Vector3(1, 1, 1)
	return move


func _hurtbox(fighter: Combatant) -> Hurtbox:
	for child: Node in fighter.get_parent().get_children():
		if child is Hurtbox:
			return child as Hurtbox
	return null


func _fighter(id: StringName, at: Vector3, extra: Dictionary[StringName, float]) -> Combatant:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = id
	fighter.faction = StringName("side_" + String(id))
	fighter.real_time = true
	var stats: Dictionary[StringName, float] = {&"max_hp": 100.0, &"attack": 10.0, &"defence": 1.0}
	stats.merge(extra, true)
	fighter.base_stats = stats
	fighter.formula = DamageFormula.new()
	var aim := AccuracyStage.new()
	fighter.formula.stages = [aim, AttackDefenceStage.new()]
	actor.add_child(fighter)
	actor.add_child(Hurtbox.new())
	_world.add_child(actor)
	Vitals.of(actor).set_to(&"hp", 100)
	return fighter
