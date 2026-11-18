extends TestCase
## The fight seen in the world (C10.14): locking on lays a ring under the target, which follows
## a new target and goes when the lock lets go; a locked fighter's sprite is turned toward its
## target; a fallen field foe fades over its linger; a standing battlefield with a place washes
## the view with its tint, and the wash goes when it comes down.
##
## OWNS: assertions about `LockOn.marker`, the lock's `turn_requested`, the fallen fade and
## `PlaceTint`.
## MUST NOT: name a game's fighters or places, or wait for frames.

var _bodies: Array[Node] = []
var _turns: Array[Vector3] = []


func run() -> void:
	plan(5)
	SaveFixture.activate()
	Flags.clear_all()
	_ring_and_facing()
	_fade()
	_tint()
	for body: Node in _bodies:
		if is_instance_valid(body):
			body.free()
	Flags.clear_all()


func _ring_and_facing() -> void:
	var player := build("res://scenes/characters/player.tscn") as PlayerController
	attach(player)
	_bodies.append(player)
	var loadout := ActionLoadout.new()
	loadout.fighter = CombatantDef.new()
	loadout.fighter.combatant_id = &"fixture_mark_hero"
	loadout.fighter.faction = &"player"
	loadout.fighter.base_stats = {&"max_hp": 40.0}
	loadout.moves = MoveSet.new()
	var fighter: ActionFighter = ActionHost.equip(player, loadout)
	var near: Node3D = _foe(&"fixture_mark_near", Vector3(0.0, 0.0, -2.0))
	var far: Node3D = _foe(&"fixture_mark_far", Vector3(1.0, 0.0, -4.0))
	var lock: LockOn = _lock_of(player)
	lock.toggle(Vector3.FORWARD)
	var first: Node = lock.marker.get_parent() if lock.marker != null else null
	lock.cycle()
	equal("a ring lies under the locked target and follows the lock to the next",
		[first == near, lock.marker.get_parent() == far], [true, true])
	Events.turn_requested.connect(_on_turn)
	fighter.drive(0.016, false, false)
	Events.turn_requested.disconnect(_on_turn)
	equal("a locked fighter's sprite is turned toward its target", _turns.has(far.global_position), true)
	var ring: MeshInstance3D = lock.marker
	lock.toggle(Vector3.FORWARD)
	equal("letting go takes the ring away", [ring.is_queued_for_deletion(), lock.marker], [true, null])


func _fade() -> void:
	var def := CombatantDef.new()
	def.combatant_id = &"fixture_mark_fading"
	def.faction = &"fixture_mark_foes"
	def.base_stats = {&"max_hp": 10.0}
	var foe := build("res://scenes/objects/action_enemy.tscn") as ActionEnemy
	foe.fighter = def
	foe.brain = ActionBrain.new()
	foe.linger = 1.0
	attach(foe)
	_bodies.append(foe)
	Vitals.of(foe).change(&"hp", -99)
	foe.act(0.01)
	foe.act(0.5)
	var visual: CharacterVisual = foe.get_node(^"Visual") as CharacterVisual
	equal("a fallen foe fades over its linger", is_equal_approx(snappedf(visual.sprite.modulate.a, 0.05), 0.5), true)


func _tint() -> void:
	var field := BattlefieldMechanism.new()
	var status := StatusEffect.new()
	status.id = &"status/fixture_mark_field"
	status.name_key = "fixture.status"
	status.duration = 0.0
	field.status = status
	field.effects = [BattlefieldEffect.new()]
	field.radius = 5.0
	field.place = PlaceLook.new()
	field.place.id = &"place/fixture_mark"
	field.place.name_key = "fixture.place"
	field.place.tint = Color(0.2, 0.4, 0.9)
	var power := Power.new()
	power.power_id = &"power/fixture_mark_field"
	power.name_key = "fixture.power"
	power.mechanism = field
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_mark"
	kit.name_key = "fixture.kit"
	kit.powers = [power]
	var me: Node3D = _foe(&"fixture_mark_caster", Vector3(20.0, 0.0, 0.0))
	var powers := PowerSet.new()
	me.add_child(powers)
	powers.equip(kit)
	var tint := PlaceTint.new()
	tint.subject = me
	attach(tint)
	_bodies.append(tint)
	PowerUse.use(Combatant.of(me), power, [], RandomNumberGenerator.new(), 12.0)
	var shown: Array = [tint.visible, tint.color]
	powers.unequip()
	equal("a standing place washes the view with its tint, and the wash goes when it falls",
		[shown, tint.visible], [[true, Color(0.2, 0.4, 0.9, PlaceTint.STRENGTH)], false])


func _foe(id: StringName, at: Vector3) -> Node3D:
	var body := Node3D.new()
	body.add_child(Vitals.new())
	body.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = id
	fighter.faction = &"fixture_mark_foes"
	fighter.real_time = true
	fighter.base_stats = {&"max_hp": 30.0}
	body.add_child(fighter)
	body.add_child(Hurtbox.new())
	attach(body)
	body.global_position = at
	_bodies.append(body)
	return body


func _lock_of(body: Node) -> LockOn:
	for child: Node in body.get_children():
		if child is LockOn:
			return child as LockOn
	return null


func _on_turn(_character: Node3D, towards: Vector3) -> void:
	_turns.append(towards)
