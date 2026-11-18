extends TestCase
## Losing (C10.2): a lost turn-based battle stands the party up with its encounter's
## `defeat_rule` and carries the rule out, or at 1 hp with none; the lead's fall inside a battle
## is not a fall in the field; and in the field a fallen lead hands the body to a standing member
## before the rule runs. Everyone asleep for good ends the battle lost (`status_behaviour_test`).
##
## OWNS: assertions about `Encounter.defeat_rule`, `FieldDefeat.after_battle`, `switch_first`.
## MUST NOT: name a game's fighters or encounters, or change areas (no area is loaded here).

const HERO: StringName = &"fixture_defeat_hero"

var _holder: Node


func run() -> void:
	plan(6)
	SaveFixture.activate()
	Flags.clear_all()
	_holder = Node.new()
	attach(_holder)
	_a_lost_battle_runs_its_rule()
	_the_lead_hands_over()
	_holder.free()
	Flags.clear_all()


func _a_lost_battle_runs_its_rule() -> void:
	var player := build("res://scenes/characters/player.tscn") as PlayerController
	attach(player)
	ActionHost.equip(player, _loadout(HERO))
	var defeat: FieldDefeat = _defeat(player)
	var was: Node3D = Director.player
	Director.player = player
	var rule := DefeatRule.new()
	rule.kind = DefeatRule.Kind.REVIVE_IN_PLACE
	rule.revive_fraction = 0.5
	var battle: Battle = _lose(rule)
	defeat.tick(5.0)
	equal("the lead falling inside a battle is not a fall in the field",
		[player.input_holders().has(FieldDefeat.LOCK), defeat.applied], [false, -1])
	equal("the battle is lost", battle.outcome(), Battle.Outcome.LOST)
	BattleSetup.release(battle)
	equal("a lost battle stands the party up by its rule and carries it out",
		[Vitals.of(player).current(&"hp"), defeat.applied], [20, DefeatRule.Kind.REVIVE_IN_PLACE])
	BattleSetup.release(_lose(null))
	equal("with no rule, they stand up at 1 hp", Vitals.of(player).current(&"hp"), 1)
	Director.player = was
	player.free()
	Flags.clear_all()


# A battle the hero has just lost: one foe, the hero brought to 0, the turn order settled.
func _lose(rule: DefeatRule) -> Battle:
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_defeat"
	encounter.enemies = [_def(&"fixture_defeat_foe", &"enemy")]
	encounter.defeat_rule = rule
	var battle: Battle = BattleSetup.build(encounter, [_def(HERO, &"player")], _holder, RandomNumberGenerator.new())
	Vitals.of(battle.party[0].get_parent()).change(&"hp", -100)
	battle.next_turn()
	return battle


func _the_lead_hands_over() -> void:
	var lead: ActionLoadout = _loadout(&"fixture_defeat_lead")
	lead.companions = [_loadout(&"fixture_defeat_mate")]
	var player := build("res://scenes/characters/player.tscn") as PlayerController
	attach(player)
	ActionHost.equip(player, lead)
	var line: Array[PartyFollower] = FieldParty.spawn(player, lead)
	var defeat: FieldDefeat = _defeat(player)
	Vitals.of(player).change(&"hp", -100)
	defeat.tick(0.1)
	equal("a fallen lead hands the body to the member still standing",
		[Combatant.of(player).combatant_id, player.input_holders().has(FieldDefeat.LOCK), defeat.applied],
		[&"fixture_defeat_mate", false, -1])
	Vitals.of(player).change(&"hp", -100)
	defeat.tick(0.1)
	equal("with nobody left standing, the rule's wait begins",
		[player.input_holders().has(FieldDefeat.LOCK), Combatant.of(player).combatant_id],
		[true, &"fixture_defeat_mate"])
	for follower: PartyFollower in line:
		follower.free()
	player.free()


func _defeat(player: Node) -> FieldDefeat:
	for child: Node in player.get_children():
		if child is FieldDefeat:
			return child as FieldDefeat
	return null


func _loadout(id: StringName) -> ActionLoadout:
	var loadout := ActionLoadout.new()
	loadout.fighter = _def(id, &"player")
	loadout.moves = MoveSet.new()
	return loadout


func _def(id: StringName, faction: StringName) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.faction = faction
	def.base_stats = {&"max_hp": 40.0, &"speed": 5.0 if faction == &"player" else 1.0, &"attack": 1.0}
	def.level_curve = LevelCurve.new()
	return def
