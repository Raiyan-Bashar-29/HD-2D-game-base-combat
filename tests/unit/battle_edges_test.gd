extends TestCase
## Battle edge rules (C10.6): a battle won with no last fall still wakes FIGHT_WON, once; a miss
## in a battle is the target's dodge; an invincible fighter refuses a harmful status but takes a
## buff; a skill that hits everyone spares a foe's untouchable guest and still finds an unseen foe.
##
## OWNS: assertions about the four rules.
## MUST NOT: name a game's fighters, statuses or passives. Every name here is made up.

const E := PassiveTrigger.Event

var _holder: Node
var _dodged: int = 0


func run() -> void:
	plan(4)
	SaveFixture.activate()
	Flags.clear_all()
	_holder = Node.new()
	attach(_holder)
	_won_with_no_fall()
	Events.attack_dodged.connect(_on_dodged)
	_a_battle_miss_is_a_dodge()
	Events.attack_dodged.disconnect(_on_dodged)
	_invincible_refuses_harm()
	_wide_skills_and_guests()
	_holder.free()
	Flags.clear_all()


func _def(id: StringName, side: StringName, stats: Dictionary[StringName, float]) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "fixture.name." + String(id)
	def.faction = side
	def.base_stats = stats
	return def


func _status(name: String, tags: Array[StringName] = []) -> StatusEffect:
	var made := StatusEffect.new()
	made.id = StringName("status/fixture_" + name)
	made.max_stacks = 9
	made.stacking = StatusEffect.Stacking.STACK
	made.tags = tags
	return made


func _passive(event: PassiveTrigger.Event, gives: StatusEffect) -> PassiveSkill:
	var effect := PassiveEffect.new()
	effect.kind = PassiveEffect.Kind.GIVE_STATUS
	effect.status = gives
	var trigger := PassiveTrigger.new()
	trigger.event = event
	trigger.effects = [effect]
	var made := PassiveSkill.new()
	made.id = StringName(PassiveDb.ID_PREFIX + "fixture_edge_" + String(gives.id).get_file())
	made.name_key = "ui.cancel"
	made.triggers = [trigger]
	return made


func _battle(hero: CombatantDef, foe: CombatantDef) -> Battle:
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_edges"
	encounter.enemies = [foe]
	return BattleSetup.build(encounter, [hero], _holder, RandomNumberGenerator.new())


func _won_with_no_fall() -> void:
	Flags.clear_all()
	var victor: StatusEffect = _status("victor")
	var hero := _def(&"fixture_edge_hero", &"side_a", {&"max_hp": 40.0, &"speed": 9.0})
	hero.passives = [_passive(E.FIGHT_WON, victor)]
	var battle: Battle = _battle(hero, _def(&"fixture_edge_foe", &"side_b", {&"max_hp": 40.0, &"speed": 1.0}))
	var gone := StatusEffect.new()
	gone.id = &"status/fixture_gone"
	gone.counts_as_fallen = true
	StatusSet.of(battle.enemies[0].get_parent()).apply(gone)
	battle.next_turn()
	var guard := BattleCommand.new()
	guard.kind = BattleCommand.Kind.DEFEND
	battle.act(guard, [])
	equal("a battle won with no last fall wakes FIGHT_WON once",
		[battle.outcome(), StatusSet.of(battle.party[0].get_parent()).stacks(victor.id)], [Battle.Outcome.WON, 1])
	BattleSetup.release(battle)


func _a_battle_miss_is_a_dodge() -> void:
	Flags.clear_all()
	var dodger: StatusEffect = _status("dodger")
	var foe := _def(&"fixture_edge_slippery", &"side_b", {&"max_hp": 40.0, &"speed": 1.0, &"evasion": 5.0})
	foe.passives = [_passive(E.DODGE, dodger)]
	var battle: Battle = _battle(_def(&"fixture_edge_swinger", &"side_a", {&"max_hp": 40.0, &"speed": 9.0, &"attack": 5.0}), foe)
	battle.next_turn()
	_dodged = 0
	battle.act(BattleCommand.new(), [battle.enemies[0]])
	equal("a miss in a battle is announced as the target's dodge and wakes its DODGE passive",
		[_dodged, StatusSet.of(battle.enemies[0].get_parent()).stacks(dodger.id)], [1, 1])
	BattleSetup.release(battle)


func _invincible_refuses_harm() -> void:
	var actor := Node.new()
	var statuses := StatusSet.new()
	actor.add_child(statuses)
	var fighter := Combatant.new()
	fighter.combatant_id = &"fixture_edge_shining"
	actor.add_child(fighter)
	attach(actor)
	var shine: StatusEffect = _status("shine")
	shine.invincible = true
	statuses.apply(shine)
	equal("while invincible, a harmful status is refused and a buff still lands",
		[statuses.apply(_status("poison", [&"ailment"])), statuses.apply(_status("hex", [&"debuff"])),
			statuses.apply(_status("cheer", [&"buff"]))], [false, false, true])
	actor.free()


func _wide_skills_and_guests() -> void:
	var user: Combatant = _plain(&"fixture_edge_caster", &"side_a")
	var guest: Combatant = _plain(&"fixture_edge_guest", &"side_b")
	guest.add_to_group(Unseen.INERT)
	var hidden: Combatant = _plain(&"fixture_edge_hidden", &"side_b")
	var veil: StatusEffect = _status("veil")
	veil.unseen = true
	StatusSet.of(hidden.get_parent()).apply(veil)
	var friend: Combatant = _plain(&"fixture_edge_friend", &"side_a")
	friend.add_to_group(Unseen.INERT)
	var wide := Skill.new()
	wide.scope = Skill.Scope.ALL
	var mend := Skill.new()
	mend.scope = Skill.Scope.ALL
	mend.target = FactionTable.Target.ALLY
	equal("a wide skill spares a foe's untouchable guest, finds an unseen foe, and a wide heal still reaches a guest ally",
		[Unseen.open(user, guest, FactionTable.Target.ENEMY, wide), Unseen.open(user, hidden, FactionTable.Target.ENEMY, wide),
			Unseen.open(user, friend, FactionTable.Target.ALLY, mend)], [false, true, true])
	for each: Combatant in [user, guest, hidden, friend]:
		each.get_parent().free()


func _plain(id: StringName, side: StringName) -> Combatant:
	var actor := Node.new()
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = id
	fighter.faction = side
	fighter.base_stats = {&"max_hp": 10.0}
	actor.add_child(fighter)
	attach(actor)
	return fighter


func _on_dodged(_who: StringName, _by: StringName) -> void:
	_dodged += 1
