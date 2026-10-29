class_name BattleScreen
extends MenuScreen
## The turn-based battle, drawn as a menu over the frozen field (C2.0): every fighter's pools,
## the turn order, and the command menu of whoever the player controls.
##
## IT ONLY DRIVES THE BATTLE. Turns come from `Battle.next_turn`, enemies play through
## `BattleAi.take_turn`, and a row calls `Battle.act`; this screen holds no rule of its own, so
## the test that plays a battle headless and this screen cannot disagree.
##
## A COMMAND THAT NEEDS ONE TARGET ASKS FOR IT; an ALL skill, DEFEND and FLEE act at once. A
## refused command (an unaffordable skill) leaves the menu up with a line saying so.
##
## CANCEL CANNOT LEAVE A BATTLE. `closes_on_cancel` is false: FLEE is the way out, when allowed.
## When it ends, the outcome is shown with one row that closes the screen, and closing releases
## the fighters (`BattleSetup.release`), which erases every enemy flag.
##
## OWNS: which menu is up, the pending command, and drawing the battle's state.
## MUST NOT: decide what a command does, who wins, or what winning gives (C2.8).

const SCREEN_ID: StringName = &"battle"
const TITLE_KEY: String = "ui.battle.title"
const ATTACK_KEY: String = "ui.battle.attack"
const DEFEND_KEY: String = "ui.battle.defend"
const FLEE_KEY: String = "ui.battle.flee"
const BACK_KEY: String = "ui.battle.back"
const POOLS_KEY: String = "ui.battle.pools"
const ORDER_KEY: String = "ui.battle.order"
const REFUSED_KEY: String = "ui.battle.refused"
const CONTINUE_KEY: String = "ui.battle.continue"
const WON_KEY: String = "ui.battle.won"
const LOST_KEY: String = "ui.battle.lost"
const FLED_KEY: String = "ui.battle.fled"
## How many upcoming turns the order line shows.
const ORDER_LENGTH: int = 5

var battle: Battle
var _pending: BattleCommand
var _refused: bool = false


func _init() -> void:
	screen_id = SCREEN_ID
	pauses_world = true
	closes_on_cancel = false
	title_key = TITLE_KEY
	opaque = false


## The one way to build the screen: around a battle `BattleSetup` already started.
static func for_battle(running: Battle) -> BattleScreen:
	var screen := BattleScreen.new()
	screen.battle = running
	return screen


func _ready() -> void:
	super()
	advance()


## Plays every turn nobody controls, until the player's turn or the end, then redraws.
func advance() -> void:
	if battle == null:
		return
	while battle.outcome() == Battle.Outcome.ONGOING:
		var actor: Combatant = battle.current()
		if actor == null:
			actor = battle.next_turn()
		if actor == null or battle.brain_of(actor) == null:
			break
		BattleAi.take_turn(battle, battle.brain_of(actor))
	refresh()


func _fill() -> void:
	if battle == null:
		return
	for fighter: Combatant in battle.party + battle.enemies:
		add_note(_pools_line(fighter))
	if battle.outcome() != Battle.Outcome.ONGOING:
		add_note(tr(_outcome_key()))
		add_row(tr(CONTINUE_KEY), request_close)
		return
	add_note(tr(ORDER_KEY).format({"names": ", ".join(_upcoming())}))
	if _refused:
		add_note(tr(REFUSED_KEY))
	if battle.current() == null:
		return
	if _pending != null:
		for target: Combatant in battle.targets_for(_pending):
			add_row(name_of(target), _aim.bind(target))
		add_row(tr(BACK_KEY), _back)
		return
	for command: BattleCommand in _menu():
		add_row(_label(command), _choose.bind(command))


func _closed() -> void:
	if battle != null:
		BattleSetup.release(battle)


## The fighter's name: its definition's key, with the number `BattleSetup` gave a duplicate.
func name_of(fighter: Combatant) -> String:
	var id: String = String(fighter.combatant_id)
	var def: CombatantDef = battle.defs.get(fighter.combatant_id, null)
	if def == null or def.name_key == "":
		return id
	var suffix: String = id.trim_prefix(String(def.combatant_id))
	return tr(def.name_key) + suffix.replace("_", " ")


func _menu() -> Array[BattleCommand]:
	var def: CombatantDef = battle.defs.get(battle.current().combatant_id, null)
	if def != null and not def.commands.is_empty():
		return def.commands
	var basic: Array[BattleCommand] = []
	for kind: BattleCommand.Kind in [BattleCommand.Kind.ATTACK, BattleCommand.Kind.DEFEND, BattleCommand.Kind.FLEE]:
		var command := BattleCommand.new()
		command.kind = kind
		basic.append(command)
	return basic


func _label(command: BattleCommand) -> String:
	if command.label_key != "":
		return tr(command.label_key)
	match command.kind:
		BattleCommand.Kind.ATTACK:
			return tr(ATTACK_KEY)
		BattleCommand.Kind.DEFEND:
			return tr(DEFEND_KEY)
		BattleCommand.Kind.FLEE:
			return tr(FLEE_KEY)
	return tr(command.skill.name_key)


func _choose(command: BattleCommand) -> void:
	var single: bool = command.kind == BattleCommand.Kind.ATTACK or (command.skill != null
			and command.skill.scope == Skill.Scope.ONE and command.kind != BattleCommand.Kind.DEFEND
			and command.kind != BattleCommand.Kind.FLEE)
	if single:
		_pending = command
		_refused = false
		refresh()
		return
	_act(command, [])


func _aim(target: Combatant) -> void:
	var command: BattleCommand = _pending
	_pending = null
	_act(command, [target])


func _back() -> void:
	_pending = null
	refresh()


func _act(command: BattleCommand, targets: Array[Combatant]) -> void:
	_refused = not battle.act(command, targets)
	advance()


func _pools_line(fighter: Combatant) -> String:
	var vitals: Vitals = Vitals.of(fighter.get_parent())
	return tr(POOLS_KEY).format({"name": name_of(fighter),
			"hp": vitals.current(&"hp"), "max": vitals.maximum(&"hp")})


func _upcoming() -> Array[String]:
	var names: Array[String] = []
	for id: StringName in battle.scheduler.preview(ORDER_LENGTH):
		for fighter: Combatant in battle.party + battle.enemies:
			if fighter.combatant_id == id:
				names.append(name_of(fighter))
	return names


func _outcome_key() -> String:
	match battle.outcome():
		Battle.Outcome.WON:
			return WON_KEY
		Battle.Outcome.LOST:
			return LOST_KEY
	return FLED_KEY
