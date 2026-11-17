extends TestCase
## Owned fighters in a turn-based battle (C8.10d). Helpers out in the field join the party's
## side as guests: the field's standing ones only, same id and so the same hp, the party's
## faction, played by a brain. An untouchable one is never offered to a foe. The party loses
## when everyone but the guests is down. A guest earns nothing and is not stood back up.
##
## OWNS: assertions about `OwnedFighter.standing`, `BattleSetup.build`'s helpers,
## `Battle.guests`, and the guest rules in `Rewards` and `BattleSetup.release`.
## MUST NOT: name a game's kits, powers or characters.

var _world: Node3D
var _holder: Node


func run() -> void:
	plan(6)
	SaveFixture.activate()
	Flags.clear_all()
	_world = Node3D.new()
	attach(_world)
	_holder = Node.new()
	attach(_holder)
	var lord := Node3D.new()
	var mark := Combatant.new()
	mark.combatant_id = &"fixture_guest_lord"
	mark.faction = &"side_field"
	lord.add_child(mark)
	_world.add_child(lord)
	var plain: OwnedFighter = _helper(lord, &"fixture_guest_plain", false)
	var ghost: OwnedFighter = _helper(lord, &"fixture_guest_ghost", true)
	var fallen: OwnedFighter = _helper(lord, &"fixture_guest_fallen", false)
	Vitals.of(fallen).change(&"hp", -999)
	Vitals.of(plain).set_to(&"hp", 7)
	var out: Array[OwnedFighter] = OwnedFighter.standing(_world.get_tree())
	equal("only the standing helpers are taken along", [out.size(), out.has(fallen)], [2, false])
	var battle: Battle = _build(out)
	_joined(battle, plain)
	_turns(battle, plain, ghost)
	_lost(battle, plain)
	BattleSetup.release(battle)
	equal("released: the hero stands back up, the fallen guest does not, and its field body is down too",
		[Vitals.of(battle.party[0].get_parent()).is_defeated(), Vitals.of(plain).is_defeated()], [false, true])
	_rewarded()
	_world.free()
	_holder.free()
	Flags.clear_all()


func _joined(battle: Battle, plain: OwnedFighter) -> void:
	var guest: Combatant = battle.party[1]
	var screen: BattleScreen = BattleScreen.for_battle(battle)
	var shown: String = screen.name_of(guest)
	screen.free()
	equal("a guest keeps its field id and hp, takes the party's side, plays itself and shows its plain name",
		[battle.party.size(), guest.combatant_id, Vitals.of(guest.get_parent()).current(&"hp"), guest.side(),
			battle.guests.size(), battle.brain_of(guest) != null, battle.brain_of(battle.party[0]), shown],
		[3, Combatant.of(plain).combatant_id, 7, &"side_party", 2, true, null, "fixture.name.fixture_guest_plain"])


func _turns(battle: Battle, plain: OwnedFighter, ghost: OwnedFighter) -> void:
	var offered: Array[Combatant] = []
	var hurt: bool = false
	for turn: int in 12:
		var actor: Combatant = battle.next_turn()
		if actor == null:
			break
		if battle.enemies.has(actor) and offered.is_empty():
			offered = battle.targets_for(BattleCommand.new())
			battle.act(_guard(), [])
		elif actor.combatant_id == Combatant.of(plain).combatant_id:
			var foe: Combatant = battle.enemies[0]
			var before: int = Vitals.of(foe.get_parent()).current(&"hp")
			BattleAi.take_turn(battle, battle.brain_of(actor))
			hurt = Vitals.of(foe.get_parent()).current(&"hp") < before
		else:
			battle.act(_guard(), [])
	var ids: Array[StringName] = []
	for one: Combatant in offered:
		ids.append(one.combatant_id)
	equal("a foe is offered the hero and the plain guest, never the untouchable one; a guest's own turn hits a foe",
		[ids.has(Combatant.of(plain).combatant_id), ids.has(Combatant.of(ghost).combatant_id), ids.size(), hurt],
		[true, false, 2, true])


func _lost(battle: Battle, plain: OwnedFighter) -> void:
	Vitals.of(battle.party[1].get_parent()).change(&"hp", -999)
	_finish(battle, battle.party[0])
	equal("the hero down is a loss though the untouchable guest stands; the fallen guest's field body reads 0 hp",
		[battle.outcome(), Vitals.of(plain).current(&"hp")], [Battle.Outcome.LOST, 0])


func _rewarded() -> void:
	var lord: Node3D = _world.get_child(0) as Node3D
	var helper: OwnedFighter = _helper(lord, &"fixture_guest_paid", false)
	var battle: Battle = _build([helper])
	_finish(battle, battle.enemies[0])
	Rewards.grant(battle, battle.encounter, null)
	BattleSetup.release(battle)
	equal("a won fight pays the hero and not the guest",
		[Party.experience_of(&"fixture_guest_hero") > 0, Party.experience_of(&"fixture_guest_paid")], [true, 0])


# Leaves `victim` at 1 hp and plays turns, guarding, until one of its foes strikes it down.
func _finish(battle: Battle, victim: Combatant) -> void:
	Vitals.of(victim.get_parent()).set_to(&"hp", 1)
	for turn: int in 12:
		var actor: Combatant = battle.next_turn()
		if actor == null:
			return
		if actor.can_target(victim, FactionTable.Target.ENEMY):
			battle.act(BattleCommand.new(), [victim])
			return
		battle.act(_guard(), [])


func _build(helpers: Array[OwnedFighter]) -> Battle:
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_guest"
	encounter.experience = 10
	encounter.enemies = [_def(&"fixture_guest_foe", &"side_foe", 1.0)]
	var hero: CombatantDef = _def(&"fixture_guest_hero", &"side_party", 9.0)
	var battle: Battle = BattleSetup.build(encounter, [hero], _holder, RandomNumberGenerator.new(), helpers)
	battle.rng.seed = 5
	return battle


func _helper(lord: Node3D, id: StringName, untouchable: bool) -> OwnedFighter:
	var one: OwnedFighter = SummonRun.SCENE.instantiate() as OwnedFighter
	var def: CombatantDef = _def(id, &"side_z", 5.0)
	one.fighter = def
	var brain := ActionBrain.new()
	brain.wander_radius = 0.0
	one.brain = brain
	one.owner_body = lord
	one.untouchable = untouchable
	one.name = String(id).trim_prefix("fixture_")
	_world.add_child(one)
	return one


func _guard() -> BattleCommand:
	var guard := BattleCommand.new()
	guard.kind = BattleCommand.Kind.DEFEND
	return guard


func _def(id: StringName, side: StringName, speed: float) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "fixture.name." + String(id)
	def.faction = side
	def.base_stats = {&"max_hp": 30.0, &"speed": speed, &"attack": 6.0, &"defence": 1.0}
	def.level_curve = LevelCurve.new()
	return def
