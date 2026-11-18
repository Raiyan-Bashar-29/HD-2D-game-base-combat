extends TestCase
## The held finisher (C10.32): with `hold`, letting go before `min_charge` cancels it and nothing
## lands; letting go later strikes, grown by the charge reached; held to the end it strikes in
## full. A LINE strike reaches a foe ahead and not one beside; `holds_still` halts the user while
## it charges.
##
## OWNS: assertions about `FinisherMechanism.hold`, `min_charge`, `hold_scale`, `shape` and
## `holds_still` through `FinisherRun`.
## MUST NOT: name a game's kits, powers or characters, or wait for frames.

var _world: Node3D
var _rng := RandomNumberGenerator.new()


func run() -> void:
	plan(4)
	SaveFixture.activate()
	Flags.clear_all()
	_world = Node3D.new()
	attach(_world)
	var power: Power = _power()
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_fhold"
	kit.name_key = "fixture.kit"
	kit.powers = [power]
	var me: Combatant = _fighter(&"fixture_fhold_me", &"side_a", Vector3.ZERO)
	var powers := PowerSet.new()
	me.get_parent().add_child(powers)
	powers.equip(kit)
	var ahead: Combatant = _fighter(&"fixture_fhold_ahead", &"side_b", Vector3(0, 0, -4))
	var beside: Combatant = _fighter(&"fixture_fhold_beside", &"side_b", Vector3(3, 0, -1))
	var run: FinisherRun = powers.executor(power.power_id) as FinisherRun
	PowerUse.use(me, power, [], _rng)
	var still: bool = StatusSet.of(me.get_parent()).halts()
	run.tick(0.2)
	run.let_go()
	equal("it holds the user still while charging; let go early, it is cancelled with nothing landed",
		[still, run.charging(), _hp(ahead), StatusSet.of(me.get_parent()).halts()], [true, false, 1000, false])
	PowerUse.use(me, power, [], _rng)
	run.tick(1.25)
	run.let_go()
	var partial: int = 1000 - _hp(ahead)
	equal("a LINE strike reaches the foe ahead and not the one beside", [partial > 0, _hp(beside)], [true, 1000])
	Vitals.of(ahead.get_parent()).set_to(&"hp", 1000)
	PowerUse.use(me, power, [], _rng)
	run.tick(2.1)
	var full: int = 1000 - _hp(ahead)
	equal("held to the end it strikes on its own, harder than one let go early", full > partial, true)
	equal("a hold finisher with no key let go does not strike before its time", run.charging(), false)
	_world.free()
	Flags.clear_all()


func _power() -> Power:
	var strike := ActionMove.new()
	strike.power = 10.0
	strike.active = 0.1
	strike.hitbox_size = Vector3.ONE
	var finisher := FinisherMechanism.new()
	finisher.strike = strike
	finisher.charge_time = 2.0
	finisher.hold = true
	finisher.min_charge = 0.5
	finisher.hold_scale = 0.5
	finisher.all_foes = true
	finisher.shape = FinisherMechanism.Shape.LINE
	finisher.reach = 6.0
	finisher.width = 2.0
	finisher.holds_still = true
	var made := Power.new()
	made.power_id = &"power/fixture_fhold"
	made.name_key = "fixture.power"
	made.mechanism = finisher
	return made


func _hp(fighter: Combatant) -> int:
	return Vitals.of(fighter.get_parent()).current(&"hp")


func _fighter(id: StringName, side: StringName, at: Vector3) -> Combatant:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = id
	fighter.faction = side
	fighter.real_time = true
	fighter.base_stats = {&"max_hp": 1000.0, &"attack": 10.0, &"defence": 0.0}
	fighter.formula = DamageFormula.new()
	fighter.formula.stages = [AttackDefenceStage.new()]
	actor.add_child(fighter)
	actor.add_child(Hurtbox.new())
	_world.add_child(actor)
	Vitals.of(actor).set_to(&"hp", 1000)
	return fighter
