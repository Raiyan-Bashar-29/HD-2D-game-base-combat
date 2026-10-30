extends TestCase
## A party in the field (C4.7): which companions follow, how a follower walks, and switching
## which member the player controls, carrying hp, statuses, moves and commands with the member.
##
## OWNS: assertions about `FieldParty` and `PartyFollower`.
## MUST NOT: name a game's fighters. Every member here is made up for the case.

const DT: float = 0.1

var _player: PlayerController
var _lead: ActionLoadout
var _first: ActionLoadout
var _second: ActionLoadout
var _locks: Array[StringName] = []


func run() -> void:
	plan(19)
	SaveFixture.activate()
	Flags.clear_all()
	_lead = _loadout(&"fixture_lead")
	_first = _loadout(&"fixture_first")
	_second = _loadout(&"fixture_second")
	_lead.companions = [_first, _second]
	# Only the second member has a gauge and something to use, so the menu follows the switch.
	_second.atb = AtbRules.new()
	var command := BattleCommand.new()
	command.kind = BattleCommand.Kind.SKILL
	command.skill = Skill.new()
	_second.commands = [command]
	_who_comes_along()
	_player = build("res://scenes/characters/player.tscn") as PlayerController
	attach(_player)
	var fighter: ActionFighter = ActionHost.equip(_player, _lead)
	var line: Array[PartyFollower] = FieldParty.spawn(_player, _lead)
	equal("each companion gets a follower, in line, as itself",
		[line.size(), line[0].slot, line[1].slot, Combatant.of(line[0]).combatant_id,
			Combatant.of(line[1]).real_time, FieldParty.followers(_player) == line],
		[2, 1, 2, &"fixture_first", true, true])
	_followers_walk(line[0])
	Events.lock_on_changed.connect(_on_lock)
	_switching(fighter, line)
	Events.lock_on_changed.disconnect(_on_lock)
	_rewards_and_commands()
	for follower: PartyFollower in FieldParty.followers(_player):
		follower.free()
	_player.free()
	Flags.clear_all()


func _who_comes_along() -> void:
	equal("before a line-up is set, every companion comes along",
		FieldParty.members(_lead), [_first, _second])
	Party.arrange([&"fixture_lead", &"fixture_second"], [&"fixture_first"])
	equal("once it is set, a member in reserve stays behind", FieldParty.members(_lead), [_second])
	Flags.clear_all()
	var broken := _loadout(&"fixture_broken")
	var clean: int = broken.problems("x").size()
	broken.companions = [null, broken]
	equal("an empty or self-naming companion is a problem", broken.problems("x").size() - clean, 2)


func _followers_walk(follower: PartyFollower) -> void:
	_player.global_position = Vector3.ZERO
	follower.global_position = Vector3(0.0, 0.0, 4.0)
	follower.follow(DT)
	equal("a follower walks towards its place behind the leader",
		[follower.velocity.z < 0.0, follower.place().is_equal_approx(Vector3(0.0, 0.0, 1.4))], [true, true])
	CombatClock.set_scale(0.0)
	follower.follow(DT)
	equal("and stands still while the fight is stopped", follower.velocity.z, 0.0)
	CombatClock.reset()
	follower.global_position = Vector3(0.0, 0.0, 30.0)
	follower.follow(DT)
	equal("left far behind, it is set down on the leader's feet at once", follower.global_position, Vector3.ZERO)
	follower.global_position = Vector3(0.0, -40.0, 2.0)
	follower.follow(DT)
	equal("and so is one that fell through the world, though it is near on the flat",
		follower.global_position, Vector3.ZERO)
	Vitals.of(follower).change(&"hp", -999)
	follower.global_position = Vector3(0.0, 0.0, 4.0)
	follower.follow(DT)
	equal("a fallen follower does not walk", follower.velocity.z, 0.0)
	Vitals.of(follower).revive(30)


func _switching(fighter: ActionFighter, line: Array[PartyFollower]) -> void:
	var first: PartyFollower = line[0]
	Vitals.of(_player).change(&"hp", -7)
	var sting := StatusEffect.new()
	sting.id = &"status/fixture_sting"
	sting.unit = StatusEffect.Unit.SECONDS
	sting.duration = 10.0
	StatusSet.of(_player).apply(sting)
	_player.global_position = Vector3(1.0, 0.0, 0.0)
	first.global_position = Vector3(5.0, 0.0, 0.0)
	equal("switching hands the body to the first follower", FieldParty.switch(_player), true)
	equal("the player is now that member, with their moves and loadout",
		[Combatant.of(_player).combatant_id, fighter.moves == _first.moves, FieldParty.lead(_player) == _first],
		[&"fixture_first", true, true])
	equal("the leader who stepped back keeps their hp and statuses",
		[Combatant.of(first).combatant_id, Vitals.of(first).current(&"hp"),
			StatusSet.of(first).stacks(&"status/fixture_sting"), first.loadout == _lead],
		[&"fixture_lead", 33, 1, true])
	equal("the two swap places, so you take over where the member stood",
		[_player.global_position.x, first.global_position.x], [5.0, 1.0])
	equal("the hitbox now strikes as the new member, and the HUD hears of it",
		[_hitbox().attacker == Combatant.of(_player), _locks.back()], [true, &"fixture_first"])
	equal("the member handed over goes to the back of the line",
		[FieldParty.followers(_player)[0].loadout, FieldParty.followers(_player)[1].loadout], [_second, _lead])
	FieldParty.switch(_player)
	FieldParty.switch(_player)
	equal("so pressing again walks through the whole party, back to the start",
		Combatant.of(_player).combatant_id, &"fixture_lead")
	Vitals.of(FieldParty.followers(_player)[0]).change(&"hp", -999)
	FieldParty.switch(_player)
	equal("a fallen member is passed over", Combatant.of(_player).combatant_id, &"fixture_second")


func _rewards_and_commands() -> void:
	# fixture_second leads now; fixture_first is down and fixture_lead stands behind.
	ActionHost.reward(10, [], _player, FieldParty.lead(_player))
	equal("a field kill teaches the leader and every standing follower, not a fallen one",
		[Party.experience_of(&"fixture_second"), Party.experience_of(&"fixture_lead"),
			Party.experience_of(&"fixture_first")], [10, 10, 0])
	var host := CommandHost.new()
	equal("the command menu offers the controlled member's commands, not the first leader's",
		host.can_open(_player), true)
	host.free()


func _loadout(id: StringName) -> ActionLoadout:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.faction = &"player"
	def.base_stats = {&"max_hp": 40.0, &"max_mp": 10.0}
	var loadout := ActionLoadout.new()
	def.level_curve = LevelCurve.new()
	loadout.fighter = def
	loadout.moves = MoveSet.new()
	return loadout


func _hitbox() -> Hitbox:
	for child: Node in _player.get_children():
		if child is Hitbox:
			return child as Hitbox
	return null


func _on_lock(who: StringName, _target: StringName) -> void:
	_locks.append(who)
