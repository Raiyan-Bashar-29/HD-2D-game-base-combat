extends TestCase
## Followers dodge (C10.26): a follower whose brain has `dodge_chance` 1 rolls away with its
## loadout's dodge from a foe's swing winding up at it, once a swing; with chance 0 it never does.
##
## OWNS: assertions about `ActionBrain.dodge_chance` through `PartyFollower` and
## `DefenceWatch.swings_at`.
## MUST NOT: name a game's fighters or moves, or wait for frames.

var _player: PlayerController
var _bodies: Array[Node] = []


func run() -> void:
	plan(3)
	SaveFixture.activate()
	Flags.clear_all()
	var roll := ActionMove.new()
	roll.startup = 0.0
	roll.active = 0.3
	roll.recovery = 0.1
	roll.iframes_from = 0.0
	roll.iframes_to = 0.3
	var lead: ActionLoadout = _loadout(&"fixture_fdodge_lead", null, 0.0)
	lead.companions = [_loadout(&"fixture_fdodge_mate", roll, 1.0)]
	_player = build("res://scenes/characters/player.tscn") as PlayerController
	attach(_player)
	_player.global_position = Vector3(0, 0, 0)
	ActionHost.equip(_player, lead)
	var follower: PartyFollower = FieldParty.spawn(_player, lead)[0]
	follower.global_position = Vector3(0, 0, 1)
	var foe: Node3D = _winding_foe(Vector3(0, 0, 2))
	equal("a swing winding up at the follower is seen", DefenceWatch.swings_at(follower, Combatant.of(follower)).size(), 1)
	follower.follow(0.016)
	var dodged: bool = follower.timeline.move == roll
	follower.timeline.cancel()
	follower.follow(0.016)
	equal("with dodge_chance 1 it rolls away, once a swing", [dodged, follower.timeline.move == roll], [true, false])
	follower.loadout.field_brain.dodge_chance = 0.0
	var other: Node3D = _winding_foe(Vector3(1, 0, 1))
	follower.follow(0.016)
	equal("with chance 0 it never does", follower.timeline.move == roll, false)
	for body: Node in _bodies:
		body.free()
	for each: PartyFollower in FieldParty.followers(_player):
		each.free()
	_player.free()
	Flags.clear_all()


func _winding_foe(at: Vector3) -> Node3D:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	var fighter := Combatant.new()
	fighter.combatant_id = StringName("fixture_fdodge_foe_%d" % _bodies.size())
	fighter.faction = &"fixture_fdodge_foes"
	fighter.real_time = true
	fighter.base_stats = {&"max_hp": 30.0}
	actor.add_child(fighter)
	var hurtbox := Hurtbox.new()
	hurtbox.timeline = MoveTimeline.new()
	actor.add_child(hurtbox)
	attach(actor)
	_bodies.append(actor)
	var swing := ActionMove.new()
	swing.startup = 1.0
	swing.active = 0.1
	swing.power = 1.0
	swing.hitbox_size = Vector3(1, 1, 3)
	hurtbox.timeline.start(swing)
	return actor


func _loadout(id: StringName, roll: ActionMove, chance: float) -> ActionLoadout:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.faction = &"player"
	def.base_stats = {&"max_hp": 40.0}
	def.level_curve = LevelCurve.new()
	var loadout := ActionLoadout.new()
	loadout.fighter = def
	loadout.moves = MoveSet.new()
	loadout.moves.dodge = roll
	loadout.field_brain = ActionBrain.new()
	loadout.field_brain.dodge_chance = chance
	return loadout
