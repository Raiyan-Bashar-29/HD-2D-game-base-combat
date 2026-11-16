extends TestCase
## A seal (C8.13a). A held status whose `seals` names a power's tag refuses that power (SEALED)
## and not the others, shown with its own words; one naming a power id refuses just that power;
## once the status is gone the power works again.
##
## OWNS: assertions about `StatusEffect.seals`, `Power.tags` and `PowerUse.Reason.SEALED`.
## MUST NOT: name a game's kits, powers or characters.

var _rng := RandomNumberGenerator.new()


func run() -> void:
	plan(4)
	SaveFixture.activate()
	Flags.clear_all()
	var world := Node3D.new()
	attach(world)
	var hot: Power = _power(&"power/fixture_seal_hot", [&"fixture_heat"])
	var calm: Power = _power(&"power/fixture_seal_calm", [])
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_seal"
	kit.powers = [hot, calm]
	var me: Combatant = _fighter(world, kit)
	var statuses: StatusSet = StatusSet.of(me.get_parent())
	var by_tag: StatusEffect = _seal(&"status/fixture_seal_tag", [&"fixture_heat"])
	statuses.apply(by_tag, _rng)
	equal("a seal on a tag refuses the power with that tag and not the other",
		[PowerUse.refusal(me, hot), PowerUse.refusal(me, calm)], [PowerUse.Reason.SEALED, PowerUse.Reason.NONE])
	equal("a sealed power is shown as sealed and cannot be used",
		[PowerMenu.reason_key(me, hot), PowerUse.use(me, hot, [], _rng)], [PowerMenu.SEALED_KEY, false])
	statuses.cure(by_tag.id)
	statuses.apply(_seal(&"status/fixture_seal_id", [calm.power_id]), _rng)
	equal("a seal on a power id refuses just that power",
		[PowerUse.refusal(me, hot), PowerUse.refusal(me, calm)], [PowerUse.Reason.NONE, PowerUse.Reason.SEALED])
	statuses.cure(&"status/fixture_seal_id")
	equal("with the seal gone the power works again", PowerUse.refusal(me, calm), PowerUse.Reason.NONE)
	world.free()
	Flags.clear_all()


func _seal(id: StringName, seals: Array[StringName]) -> StatusEffect:
	var effect := StatusEffect.new()
	effect.id = id
	effect.unit = StatusEffect.Unit.SECONDS
	effect.duration = 10.0
	effect.seals = seals
	return effect


func _power(id: StringName, tags: Array[StringName]) -> Power:
	var power := Power.new()
	power.power_id = id
	power.name_key = "fixture.power"
	power.tags = tags
	var refresh := RefreshMechanism.new()
	power.mechanism = refresh
	return power


func _fighter(world: Node3D, kit: PowerKit) -> Combatant:
	var actor := Node3D.new()
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = &"fixture_sealed"
	fighter.real_time = true
	fighter.base_stats = {&"max_hp": 100.0}
	actor.add_child(fighter)
	actor.add_child(PowerSet.new())
	world.add_child(actor)
	PowerSet.of(actor).equip(kit)
	return fighter
