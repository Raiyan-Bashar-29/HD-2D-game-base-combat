extends TestCase
## Follow-ups in the field (C8.22c). A real-time hit that lands on a foe lets each ally of the
## attacker standing near that foe and holding a FOLLOW_UP status strike it at once; one too far
## away, one asleep, or a hit that never landed gives none, and a follow-up never sets off another.
## C8.24: an ally behind a wall does not follow up, a hit on a thing in the arena draws none, and a
## skill move that took no hp draws none.
##
## OWNS: assertions about `FieldFollowUps` and the follow-up step of `Hurtbox.take`.
## MUST NOT: name a game's fighters or moves, or wait for frames.

const HERO: StringName = &"fixture_field_follow_hero"
const NEAR: StringName = &"fixture_field_follow_near"
const FAR: StringName = &"fixture_field_follow_far"
const WALLED: StringName = &"fixture_field_follow_walled"
const FOE: StringName = &"fixture_field_follow_foe"

var _world: Node3D
var _followed: Array = []


func run() -> void:
	plan(8)
	_world = Node3D.new()
	attach(_world)
	var hero: Combatant = _fighter(HERO, &"side_a", Vector3.ZERO)
	var near: Combatant = _fighter(NEAR, &"side_a", Vector3(2.0, 0.0, 0.0))
	var far: Combatant = _fighter(FAR, &"side_a", Vector3(30.0, 0.0, 0.0))
	var foe: Combatant = _fighter(FOE, &"side_b", Vector3(0.0, 0.0, -1.0))
	var walled: Combatant = _fighter(WALLED, &"side_a", Vector3(0.0, 0.0, -5.0))
	_wall(Vector3(0.0, 0.0, -3.0))
	for one: Combatant in [hero, near, far, walled]:
		StatusSet.of(one.get_parent()).apply(_follow())
	Events.followed_up.connect(_on_followed)
	var rng := RandomNumberGenerator.new()
	var before: int = _hp(foe)
	var counted: bool = _hurtbox(foe).take(hero, _move(), rng, Vector3.ZERO)
	equal("a landed hit lets the near ally follow up: not the far one, not one behind a wall, not the attacker",
		[counted, _followed], [true, [[NEAR, FOE]]])
	equal("the foe loses the hero's 15 and the follow-up's 10", before - _hp(foe), 25)
	_followed.clear()
	StatusSet.of(near.get_parent()).apply(_sleep())
	equal("an asleep ally does not follow up", FieldFollowUps.after_hit(hero, foe, rng), 0)
	StatusSet.of(near.get_parent()).cure(&"status/fixture_field_follow_sleep")
	equal("a hit on an ally is refused, and nobody follows it up",
		[_hurtbox(near).take(hero, _move(), rng, Vector3.ZERO), _followed], [false, []])
	_followed.clear()
	var unhurt: bool = _hurtbox(foe).take(hero, _status_move(), rng, Vector3.ZERO)
	equal("a skill move that took no hp draws no follow-up", [unhurt, _followed], [true, []])
	foe.add_to_group(Unseen.INERT)
	equal("a hit on a thing in the arena draws none", FieldFollowUps.after_hit(hero, foe, rng), 0)
	foe.remove_from_group(Unseen.INERT)
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


# A move whose skill only gives a status: it lands but takes no hp.
func _status_move() -> ActionMove:
	var skill := Skill.new()
	skill.id = &"skill/fixture_field_follow_mark"
	skill.name_key = "fixture.skill"
	skill.target = FactionTable.Target.ENEMY
	skill.power = 0.0
	var move := ActionMove.new()
	move.skill = skill
	return move


# A wall 4 m wide and 3 m tall across the z axis at `at`, on the world layer.
func _wall(at: Vector3) -> void:
	var wall := StaticBody3D.new()
	wall.collision_layer = Layers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 3, 0.5)
	shape.shape = box
	shape.position = Vector3(0, 1.5, 0)
	wall.add_child(shape)
	wall.position = at
	_world.add_child(wall)


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
