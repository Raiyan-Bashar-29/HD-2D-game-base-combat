extends TestCase
## Follow-ups in the field (C8.22c). A real-time hit that lands on a foe lets each ally of the
## attacker standing near that foe and holding a FOLLOW_UP status strike it at once; one too far
## away, one asleep, or a hit that never landed gives none, and a follow-up never sets off another.
##
## OWNS: assertions about `FieldFollowUps` and the follow-up step of `Hurtbox.take`.
## MUST NOT: name a game's fighters or moves, or wait for frames.

const HERO: StringName = &"fixture_field_follow_hero"
const NEAR: StringName = &"fixture_field_follow_near"
const FAR: StringName = &"fixture_field_follow_far"
const FOE: StringName = &"fixture_field_follow_foe"

var _world: Node3D
var _followed: Array = []


func run() -> void:
	plan(5)
	_world = Node3D.new()
	attach(_world)
	var hero: Combatant = _fighter(HERO, &"side_a", Vector3.ZERO)
	var near: Combatant = _fighter(NEAR, &"side_a", Vector3(2.0, 0.0, 0.0))
	var far: Combatant = _fighter(FAR, &"side_a", Vector3(30.0, 0.0, 0.0))
	var foe: Combatant = _fighter(FOE, &"side_b", Vector3(0.0, 0.0, -1.0))
	for one: Combatant in [hero, near, far]:
		StatusSet.of(one.get_parent()).apply(_follow())
	Events.followed_up.connect(_on_followed)
	var rng := RandomNumberGenerator.new()
	var before: int = _hp(foe)
	var counted: bool = _hurtbox(foe).take(hero, _move(), rng, Vector3.ZERO)
	equal("a landed hit lets the near ally follow up, not the far one, and not the attacker again",
		[counted, _followed, _hp(foe) < before - 1], [true, [[NEAR, FOE]], true])
	_followed.clear()
	StatusSet.of(near.get_parent()).apply(_sleep())
	equal("an asleep ally does not follow up", FieldFollowUps.after_hit(hero, foe, rng), 0)
	StatusSet.of(near.get_parent()).cure(&"status/fixture_field_follow_sleep")
	equal("a hit on an ally is refused, and nobody follows it up",
		[_hurtbox(near).take(hero, _move(), rng, Vector3.ZERO), _followed], [false, []])
	Vitals.of(foe.get_parent()).change(&"hp", -9999)
	equal("a fallen foe draws no follow-up", FieldFollowUps.after_hit(hero, foe, rng), 0)
	var loose := Combatant.new()
	equal("an attacker outside the tree draws none", FieldFollowUps.after_hit(loose, hero, rng), 0)
	loose.free()
	Events.followed_up.disconnect(_on_followed)
	_world.free()


func _on_followed(who: StringName, against: StringName) -> void:
	_followed.append([who, against])


func _fighter(id: StringName, side: StringName, at: Vector3) -> Combatant:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = side
	combatant.base_stats = {&"max_hp": 500.0, &"attack": 10.0}
	combatant.formula = DamageFormula.new()
	combatant.formula.stages = [AttackDefenceStage.new()]
	actor.add_child(combatant)
	actor.add_child(Hurtbox.new())
	_world.add_child(actor)
	return combatant


func _hurtbox(fighter: Combatant) -> Hurtbox:
	for child: Node in fighter.get_parent().get_children():
		if child is Hurtbox:
			return child as Hurtbox
	return null


func _move() -> ActionMove:
	var move := ActionMove.new()
	move.power = 5.0
	return move


func _follow() -> StatusEffect:
	var follow := StatusEffect.new()
	follow.id = &"status/fixture_field_follow"
	follow.reactions = [StatusEffect.Reaction.FOLLOW_UP]
	return follow


func _sleep() -> StatusEffect:
	var sleep := StatusEffect.new()
	sleep.id = &"status/fixture_field_follow_sleep"
	sleep.duration = 2.0
	sleep.blocks = [StatusEffect.Block.SKIP_TURN]
	return sleep


func _hp(fighter: Combatant) -> int:
	return Vitals.of(fighter.get_parent()).current(&"hp")
