extends TestCase
## A summon's links to its user (C8.10f). With `linked_hp`, a hurt summon takes that share of
## the hurt from its user, and a stranger's hurt takes nothing. With `saved`, the count out is a
## flag; leaving the area keeps it and brings them back once the next area is entered; a count
## set with none out (a load) brings them on the next tick; the user falling erases it.
##
## OWNS: assertions about `SummonLink` and the C8.10f parts of `SummonRun`.
## MUST NOT: name a game's kits, powers or characters.

var _world: Node3D
var _rng := RandomNumberGenerator.new()
var _summon := SummonMechanism.new()
var _call: Power


func run() -> void:
	plan(6)
	SaveFixture.activate()
	Flags.clear_all()
	_world = Node3D.new()
	attach(_world)
	_summon = _mechanism()
	_call = Power.new()
	_call.power_id = &"power/fixture_link_call"
	_call.name_key = "fixture.power"
	_call.mechanism = _summon
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_link"
	kit.powers = [_call]
	var me: Combatant = _fighter(kit)
	var left_over: Battle = Battle.running
	Battle.running = null
	_linked(me)
	_saved(me)
	Battle.running = left_over
	_world.free()
	Flags.clear_all()


func _linked(me: Combatant) -> void:
	PowerUse.use(me, _call, [], _rng, 12.0)
	var one: Combatant = Combatant.of(_out()[0])
	Events.combatant_damaged.emit(one.combatant_id, &"fixture_x", 10, false)
	Events.combatant_damaged.emit(&"fixture_stranger", &"fixture_x", 10, false)
	equal("a hurt summon takes its linked share from the user, a stranger's hurt nothing",
		Vitals.of(me.get_parent()).current(&"hp"), 95)


func _saved(me: Combatant) -> void:
	var run: SummonRun = PowerSet.of(me.get_parent()).executor(_call.power_id) as SummonRun
	var key: StringName = SummonLink.key(PowerSet.of(me.get_parent()), _call, _summon)
	equal("the count out is saved", Flags.get_int(key), 2)
	Events.area_unloading.emit(&"fixture_area")
	run.tick(0.1)
	equal("leaving the area sends them away but keeps the count", [_out().size(), Flags.get_int(key)], [0, 2])
	Events.area_entered.emit(&"fixture_area")
	run.tick(0.1)
	equal("in the next area they come back", [_out().size(), Flags.get_int(key)], [2, 2])
	Events.combatant_defeated.emit(me.combatant_id)
	equal("the user falling erases the count", [_out().size(), Flags.has_flag(key)], [0, false])
	Flags.set_flag(key, 1)
	run.tick(0.1)
	equal("a count with none out, as after a load, brings that many", _out().size(), 1)
	run.end()


func _out() -> Array[OwnedFighter]:
	var out: Array[OwnedFighter] = []
	for node: Node in _world.get_tree().get_nodes_in_group(OwnedFighter.GROUP):
		if not node.is_queued_for_deletion():
			out.append(node as OwnedFighter)
	return out


func _mechanism() -> SummonMechanism:
	var made := SummonMechanism.new()
	var def := CombatantDef.new()
	def.combatant_id = &"fixture_link_helper"
	def.faction = &"side_z"
	def.base_stats = {&"max_hp": 20.0, &"attack": 4.0, &"defence": 1.0}
	var brain := ActionBrain.new()
	brain.wander_radius = 0.0
	made.fighters = [def, def]
	made.brains = [brain, brain]
	made.linked_hp = 0.5
	made.saved = true
	return made


func _fighter(kit: PowerKit) -> Combatant:
	var actor := Node3D.new()
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = &"fixture_linker"
	fighter.faction = &"side_a"
	fighter.real_time = true
	fighter.base_stats = {&"max_hp": 100.0, &"attack": 6.0, &"defence": 1.0}
	fighter.formula = DamageFormula.new()
	fighter.formula.stages = [AttackDefenceStage.new()]
	actor.add_child(fighter)
	var hurtbox := Hurtbox.new()
	hurtbox.timeline = MoveTimeline.new()
	actor.add_child(hurtbox)
	actor.add_child(PowerSet.new())
	_world.add_child(actor)
	Vitals.of(actor).set_to(&"hp", 100)
	PowerSet.of(actor).equip(kit)
	return fighter
