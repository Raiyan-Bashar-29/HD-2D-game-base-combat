extends TestCase
## The berserk status (C9.5c): a status whose `takeover` brain plays its holder. In a battle
## the brain takes the holder's turn; in the field the player's fighter swings on its own and
## loses its dodge and its commands.
##
## OWNS: assertions about `StatusEffect.takeover`, `StatusSet.takeover`, `Battle.brain_of`
## under it, and what `ActionFighter` and `FieldCommands` do while it is held.
## MUST NOT: name a game's statuses or fighters. Every name here is made up for the case.

const DT: float = 0.05

var _actors: Array[Node] = []


func run() -> void:
	plan(8)
	SaveFixture.activate()
	Flags.clear_all()
	CombatClock.reset()
	_content()
	_in_a_battle()
	_a_foe()
	_in_the_field()
	for actor: Node in _actors:
		actor.free()
	_actors.clear()
	Flags.clear_all()


func _content() -> void:
	var broken := BattleBrain.new()
	broken.entries = [BrainEntry.new()]
	equal("a berserk status with a sound brain has no problems; a brain with a broken entry is "
			+ "flagged", [_rage(BattleBrain.new()).problems().size(), _rage(broken).problems().size() > 0],
		[0, true])
	var me: Combatant = _fighter(&"fixture_rage_holder", &"side_a", {&"max_hp": 20.0})
	var statuses: StatusSet = StatusSet.of(me.get_parent())
	var brain := BattleBrain.new()
	var none: BattleBrain = statuses.takeover()
	statuses.apply(_rage(brain, 2.0))
	var held: BattleBrain = statuses.takeover()
	statuses.tick_turn()
	statuses.tick_turn()
	equal("the holder is its own until the status lands, and again when it runs out",
		[none, held == brain, statuses.takeover()], [null, true, null])


func _in_a_battle() -> void:
	var me: Combatant = _fighter(&"fixture_rage_hero", &"side_a", {&"max_hp": 50.0, &"speed": 9.0,
		&"attack": 5.0})
	var foe: Combatant = _fighter(&"fixture_rage_foe", &"side_b", {&"max_hp": 50.0, &"speed": 1.0})
	var battle := Battle.new([me], [foe])
	battle.start()
	battle.next_turn()
	var own: BattleBrain = battle.brain_of(me)
	# No entries: the brain falls back to a plain attack on the first foe.
	var brain := BattleBrain.new()
	StatusSet.of(me.get_parent()).apply(_rage(brain))
	equal("a party member the player controls is played by the status's brain while berserk",
		[own, battle.current() == me, battle.brain_of(me) == brain], [null, true, true])
	equal("that brain takes the turn: with no entries it attacks the foe",
		[BattleAi.take_turn(battle, battle.brain_of(me)), _hp(foe)], [true, 45])


func _a_foe() -> void:
	var me: Combatant = _fighter(&"fixture_rage_target", &"side_a", {&"max_hp": 50.0, &"speed": 1.0})
	var foe: Combatant = _fighter(&"fixture_rage_beast", &"side_b", {&"max_hp": 50.0, &"speed": 9.0})
	var battle := Battle.new([me], [foe])
	var own := BattleBrain.new()
	battle.brains[foe.combatant_id] = own
	battle.start()
	var wild := BattleBrain.new()
	var statuses: StatusSet = StatusSet.of(foe.get_parent())
	statuses.apply(_rage(wild))
	var during: bool = battle.brain_of(foe) == wild
	statuses.cure(_rage(wild).id)
	equal("a foe's own brain is set aside while it is berserk, and comes back after",
		[during, battle.brain_of(foe) == own], [true, true])


func _in_the_field() -> void:
	var player := build("res://scenes/characters/player.tscn") as PlayerController
	attach(player)
	_actors.append(player)
	var fighter: ActionFighter = ActionHost.equip(player, _loadout())
	var me: Combatant = Combatant.of(player)
	var statuses: StatusSet = StatusSet.of(player)
	var command := BattleCommand.new()
	command.kind = BattleCommand.Kind.SKILL
	command.skill = Skill.new()
	fighter.drive(DT, false, false)
	var calm: Array = [fighter.timeline.busy(), FieldCommands.refusal(me, command) == FieldCommands.Reason.BLOCKED]
	var rage: StatusEffect = _rage(BattleBrain.new(), 1.0)
	rage.unit = StatusEffect.Unit.SECONDS
	statuses.apply(rage)
	fighter.drive(DT, false, true)
	equal("in the field a berserk fighter swings with no button pressed, and a dodge press "
			+ "does not roll", [calm, fighter.timeline.busy(), fighter.timeline.move == fighter.moves.dodge],
		[[false, false], true, false])
	equal("and no command may be used", FieldCommands.refusal(me, command), FieldCommands.Reason.BLOCKED)
	for i: int in 40:
		fighter.drive(DT, false, false)
	var after: bool = fighter.timeline.busy()
	equal("when the status ends the fighter stops swinging and its commands come back",
		[statuses.takeover(), after, FieldCommands.refusal(me, command) == FieldCommands.Reason.BLOCKED],
		[null, false, false])


func _rage(brain: BattleBrain, lasts: float = 3.0) -> StatusEffect:
	var made := StatusEffect.new()
	made.id = &"status/fixture_rage"
	made.name_key = "ui.cancel"
	made.duration = lasts
	made.takeover = brain
	return made


func _loadout() -> ActionLoadout:
	var def := CombatantDef.new()
	def.combatant_id = &"fixture_rage_walker"
	def.faction = &"player"
	def.base_stats = {&"max_hp": 40.0, &"attack": 3.0}
	var swing := ActionMove.new()
	swing.startup = 0.1
	swing.active = 0.1
	swing.recovery = 0.1
	var roll := ActionMove.new()
	roll.active = 0.2
	var made := ActionLoadout.new()
	made.fighter = def
	made.moves = MoveSet.new()
	made.moves.attack_chain = [swing]
	made.moves.dodge = roll
	return made


func _hp(fighter: Combatant) -> int:
	return Vitals.of(fighter.get_parent()).current(&"hp")


func _fighter(id: StringName, side: StringName, stats: Dictionary[StringName, float]) -> Combatant:
	var actor := Node.new()
	actor.add_child(Vitals.new())
	var statuses := StatusSet.new()
	statuses.save_id = StringName("statuses/" + String(id))
	actor.add_child(statuses)
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = side
	combatant.base_stats = stats
	combatant.formula = DamageFormula.new()
	combatant.formula.stages = [AttackDefenceStage.new()]
	actor.add_child(combatant)
	attach(actor)
	_actors.append(actor)
	return combatant
