extends TestCase
## Once per battle (C6.5f): a power marked `once_per_battle` is refused with ONCE after its first
## use, past its cooldown and through taking its kit off and on, and the menu says why; entering
## an area wipes the record in the field; in a battle the next turn refuses it and a new battle
## allows it again; a power without the mark is untouched; a passive with it is a problem.
##
## OWNS: assertions about `Power.once_per_battle`, `OnceLedger` and `PowerUse.Reason.ONCE`.
## MUST NOT: name a game's kits, powers or characters, or wait for frames.

var _actors: Array[Node] = []
var _rng := RandomNumberGenerator.new()


func run() -> void:
	plan(14)
	SaveFixture.activate()
	Flags.clear_all()
	_rng.seed = 3
	_problems()
	_field()
	_battles()
	for actor: Node in _actors:
		actor.free()
	_actors.clear()
	Flags.clear_all()


func _problems() -> void:
	var held: Power = _power(&"power/fixture_held")
	held.passive = true
	held.skill = null
	held.once_per_battle = true
	equal("a passive power marked once per battle is a problem", held.problems("fixture").size(), 1)
	var once: Power = _power(&"power/fixture_once")
	once.once_per_battle = true
	equal("a usable once-per-battle power is clean", once.problems("fixture").is_empty(), true)


func _field() -> void:
	var hero: Combatant = _fighter(&"fixture_hero", &"player", Vector3.ZERO)
	var foe: Combatant = _fighter(&"fixture_foe", &"enemy", Vector3(0, 0, -2))
	hero.real_time = true
	var kit: PowerKit = _kit()
	var powers: PowerSet = PowerSet.of(hero.get_parent())
	powers.equip(kit)
	var once: Power = kit.power(&"power/fixture_once")
	var plain: Power = kit.power(&"power/fixture_plain")
	equal("the first use lands", PowerUse.use(hero, once, [foe], _rng), true)
	equal("the second is refused as used once",
		[PowerUse.refusal(hero, once), PowerUse.use(hero, once, [foe], _rng)], [PowerUse.Reason.ONCE, false])
	powers.tick_seconds(10.0)
	equal("its cooldown running out does not bring it back", PowerUse.refusal(hero, once), PowerUse.Reason.ONCE)
	equal("the menu names the reason", PowerMenu.reason_key(hero, once), PowerMenu.ONCE_KEY)
	equal("and the reason has words", tr(PowerMenu.ONCE_KEY) != PowerMenu.ONCE_KEY, true)
	equal("a power without the mark is used again and again",
		[PowerUse.use(hero, plain, [foe], _rng), PowerUse.use(hero, plain, [foe], _rng)], [true, true])
	powers.unequip()
	powers.equip(kit)
	equal("taking the kit off and on does not bring it back", PowerUse.refusal(hero, once), PowerUse.Reason.ONCE)
	Events.area_entered.emit(&"fixture_area")
	equal("entering an area does", PowerUse.refusal(hero, once), PowerUse.Reason.NONE)


func _battles() -> void:
	var holder := Node.new()
	attach(holder)
	_actors.append(holder)
	var battle: Battle = _battle(holder)
	var hero: Combatant = battle.party[0]
	var foe: Combatant = battle.enemies[0]
	equal("the hero goes first", battle.next_turn(), hero)
	var once := BattleCommand.for_power(PowerSet.of(hero.get_parent()).kit.power(&"power/fixture_once"))
	equal("in a battle the first use lands", battle.act(once, [foe]), true)
	while battle.next_turn() != hero:
		_pass(battle)
	var hp: int = Vitals.of(foe.get_parent()).current(&"hp")
	equal("on its next turn it is refused, changing nothing",
		[battle.act(once, [foe]), Vitals.of(foe.get_parent()).current(&"hp"), battle.current()],
		[false, hp, hero])
	BattleSetup.release(battle)
	var next: Battle = _battle(holder)
	var again: Combatant = next.party[0]
	next.next_turn()
	var fresh := BattleCommand.for_power(PowerSet.of(again.get_parent()).kit.power(&"power/fixture_once"))
	equal("a new battle allows it again", next.act(fresh, [next.enemies[0]]), true)
	BattleSetup.release(next)


func _battle(holder: Node) -> Battle:
	var hero := _def(&"fixture_hero", &"side_a", 9.0)
	hero.power_kit = _kit()
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_once"
	encounter.enemies = [_def(&"fixture_foe", &"side_b", 1.0)]
	return BattleSetup.build(encounter, [hero], holder, RandomNumberGenerator.new())


func _pass(battle: Battle) -> void:
	var guard := BattleCommand.new()
	guard.kind = BattleCommand.Kind.DEFEND
	battle.act(guard, [])


func _kit() -> PowerKit:
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_once"
	kit.name_key = "fixture.kit"
	var once: Power = _power(&"power/fixture_once")
	once.once_per_battle = true
	once.cooldown = 1.0
	kit.powers = [once, _power(&"power/fixture_plain")]
	return kit


func _fighter(id: StringName, faction: StringName, at: Vector3) -> Combatant:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = id
	fighter.faction = faction
	fighter.base_stats = {&"max_hp": 60.0, &"max_mp": 40.0, &"attack": 6.0, &"defence": 1.0}
	actor.add_child(fighter)
	actor.add_child(Hurtbox.new())
	actor.add_child(PowerSet.new())
	attach(actor)
	_actors.append(actor)
	return fighter


func _def(id: StringName, side: StringName, speed: float) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "fixture.name." + String(id)
	def.faction = side
	def.base_stats = {&"max_hp": 99.0, &"max_mp": 40.0, &"speed": speed, &"attack": 2.0, &"defence": 1.0}
	return def


func _power(id: StringName) -> Power:
	var skill := Skill.new()
	skill.id = StringName(String(id).replace("power/", "skill/"))
	skill.name_key = "fixture.skill"
	skill.power = 2.0
	skill.cost_pool = &"mp"
	skill.cost = 2
	skill.sure_hit = true
	var power := Power.new()
	power.power_id = id
	power.name_key = "fixture.power"
	power.skill = skill
	return power
