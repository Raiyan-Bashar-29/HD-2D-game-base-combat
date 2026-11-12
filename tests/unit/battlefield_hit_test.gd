extends TestCase
## The hit side of a battlefield (C6.9c): a caster's hits become sure hits and carry tags while
## its battlefield stands; a foe holding the cancelling status is only rolled for; and a landed
## hit whose tag a battlefield names brings it down, with no aftermath. The clash rules are C6.9d.
##
## OWNS: assertions about `HitFlags`, the granted copy of a battlefield's status, and
## `BattlefieldRun.breaks`.
## MUST NOT: name a game's kits, powers or characters, or wait for frames.

const NOON: float = 12.0
const DOMAIN: StringName = &"status/fixture_hit_domain"
const MARBLE: StringName = &"status/fixture_hit_marble"
const CANCEL: StringName = &"status/fixture_hit_cancel"
const WARD: StringName = &"status/fixture_hit_ward"
const TAG: StringName = &"fixture_hit_domain_tag"
const ANTI: StringName = &"fixture_hit_anti"
const FIRE: StringName = &"fixture_hit_fire"

var _world: Node3D
var _rng := RandomNumberGenerator.new()
var _me: Combatant
var _foe: Combatant
var _powers: Dictionary[String, Power] = {}


func run() -> void:
	plan(12)
	Flags.clear_all()
	_rng.seed = 5
	_world = Node3D.new()
	attach(_world)
	_me = _fighter(&"fixture_hit_me", &"player", Vector3.ZERO, _kit())
	_foe = _fighter(&"fixture_hit_foe", &"enemy", Vector3(0.0, 0.0, -3.0), null)
	_granted()
	_sure_while_standing()
	_cancelled()
	_sure_ends_with_the_field()
	_broken()
	_world.free()
	Flags.clear_all()


# The copy a battlefield's status is raised as carries the flags; the shared status does not.
func _granted() -> void:
	var base: StatusEffect = _status(DOMAIN, 0.0)
	var field: BattlefieldMechanism = _domain_field()
	var copy: StatusEffect = HitFlags.granted(base, field)
	equal("the copy grants sure hits", copy.grants_sure_hit, true)
	equal("the copy keeps the status id", copy.id, DOMAIN)
	equal("the shared status is left alone", base.grants_sure_hit, false)


# While the domain stands, the caster's hits are sure and carry its tag.
func _sure_while_standing() -> void:
	_use("domain")
	var result: DamageResult = _me.hit(_foe, 5.0, &"", _rng)
	equal("a caster's hit inside is a sure hit", result.tags.has(&"sure_hit"), true)
	equal("a caster's hit carries the domain tag", result.tags.has(TAG), true)


# A foe holding the cancelling status is rolled for, as usual; cured, it is sure again.
func _cancelled() -> void:
	var cancel: StatusEffect = _status(CANCEL, 0.0)
	var statuses: StatusSet = StatusSet.of(_foe.get_parent())
	statuses.apply(cancel)
	var held: DamageResult = _me.hit(_foe, 5.0, &"", _rng)
	equal("a cancelled foe is not sure-hit", held.tags.has(&"sure_hit"), false)
	statuses.cure(CANCEL)
	var freed: DamageResult = _me.hit(_foe, 5.0, &"", _rng)
	equal("a foe that lost the cancel is sure-hit again", freed.tags.has(&"sure_hit"), true)


# Leaving the domain ends its sure hits: the caster is ordinary again.
func _sure_ends_with_the_field() -> void:
	_use("domain")
	var result: DamageResult = _me.hit(_foe, 5.0, &"", _rng)
	equal("leaving the domain ends its sure hits", result.tags.has(&"sure_hit"), false)


# A hit tagged with a breaking tag brings the marble down at once, with no aftermath; a hit with
# another tag leaves it standing.
func _broken() -> void:
	_use("marble")
	var run_of: BattlefieldRun = _run("marble")
	BattlefieldRun.breaks(_me, [FIRE])
	equal("another tag leaves the marble standing", run_of.standing(), true)
	BattlefieldRun.breaks(_me, [ANTI])
	equal("a breaking tag brings the marble down", run_of.standing(), false)
	equal("the caster's marble status is gone", StatusSet.of(_me.get_parent()).stacks(MARBLE), 0)
	equal("no aftermath when a hit breaks it", StatusSet.of(_me.get_parent()).stacks(WARD), 0)


# --- fixtures -----------------------------------------------------------------------------------

func _domain_field() -> BattlefieldMechanism:
	var field := BattlefieldMechanism.new()
	field.status = _status(DOMAIN, 0.0)
	field.effects = [BattlefieldEffect.new()]
	field.sure_hit = true
	field.hit_tags = [TAG]
	field.cancelled_by = CANCEL
	return field


func _kit() -> PowerKit:
	var domain: BattlefieldMechanism = _domain_field()
	var marble := BattlefieldMechanism.new()
	marble.status = _status(MARBLE, 0.0)
	marble.effects = [BattlefieldEffect.new()]
	marble.broken_by_tags = [ANTI]
	marble.aftermath = _status(WARD, 5.0)
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_hit"
	kit.powers = [_power("domain", domain), _power("marble", marble)]
	return kit


func _power(short: String, mechanism: PowerMechanism) -> Power:
	var power := Power.new()
	power.power_id = StringName("power/fixture_hit_" + short)
	power.name_key = "fixture.power"
	power.mechanism = mechanism
	_powers[short] = power
	return power


func _status(id: StringName, duration: float) -> StatusEffect:
	var status := StatusEffect.new()
	status.id = id
	status.name_key = "fixture.status"
	status.duration = duration
	return status


func _fighter(id: StringName, faction: StringName, at: Vector3, kit: PowerKit) -> Combatant:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = id
	fighter.faction = faction
	fighter.real_time = true
	fighter.base_stats = {&"max_hp": 100.0, &"max_mp": 10.0, &"attack": 6.0, &"defence": 1.0}
	fighter.formula = DamageFormula.new()
	fighter.formula.stages = [AttackDefenceStage.new()]
	actor.add_child(fighter)
	actor.add_child(PowerSet.new())
	_world.add_child(actor)
	if kit != null:
		PowerSet.of(actor).equip(kit)
	return fighter


func _use(short: String) -> bool:
	return PowerUse.use(_me, _powers[short], [], _rng, NOON)


func _run(short: String) -> BattlefieldRun:
	return PowerSet.of(_me.get_parent()).executor(_powers[short].power_id) as BattlefieldRun
