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
## THE MENU HAS DEPTH (C2.18). Commands with a `category` sit in a submenu behind one row. Every
## skill row shows its cost, a stance shows On or Off, and a row the fighter cannot use right now
## is greyed out with the reason beside it (`BattleMenu.refusal`). A fighter with Boost points
## gets a Boost row that cycles the level the next action spends.
##
## CANCEL CANNOT LEAVE A BATTLE. `closes_on_cancel` is false: FLEE is the way out, when allowed.
## When it ends, the outcome is shown with one row that closes the screen, and closing releases
## the fighters (`BattleSetup.release`), which erases every enemy flag.
##
## A WIN IS REWARDED ONCE, through `Rewards.grant`, when the screen first sees the outcome, and
## its summary is drawn above Continue: experience, each level gained, each item found.
##
## IN PLAIN WORDS: the battle menu you see. It lists everyone's HP, who moves next, and the
## buttons for the current party member. Enemy turns are played automatically by `advance()`.
## Pressing a button only asks `Battle` to act; the rules all live in `battle.gd`.
##
## OWNS: which menu is up, the pending command, and drawing the battle's state.
## MUST NOT: decide what a command does, who wins, or what winning gives; `Rewards` does.

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
const EXPERIENCE_KEY: String = "ui.battle.experience"
const LEVEL_UP_KEY: String = "ui.battle.level_up"
const FOUND_KEY: String = "ui.battle.found"
const LEFT_KEY: String = "ui.battle.left_behind"
const COST_KEY: String = "ui.battle.cost"
const UNAVAILABLE_KEY: String = "ui.battle.unavailable"
const STANCE_ON_KEY: String = "ui.battle.stance_on"
const STANCE_OFF_KEY: String = "ui.battle.stance_off"
const BOOST_KEY: String = "ui.battle.boost"
## How many upcoming turns the order line shows.
const ORDER_LENGTH: int = 5

## The fight being shown. `_pending` is a command chosen but still waiting for a target.
var battle: Battle
var _pending: BattleCommand
var _refused: bool = false
## The open submenu's category key; empty on the first menu. And the Boost level chosen for the
## next action, back to 0 after every action.
var _category: String = ""
var _boost: int = 0
## What the win gave, asked for once when the screen first sees the outcome.
var rewards: Rewards


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
	# Keep playing AI turns until a player-controlled fighter is up, or the fight ends.
	while battle.outcome() == Battle.Outcome.ONGOING:
		var actor: Combatant = battle.current()
		if actor == null:
			actor = battle.next_turn()
		if actor == null or battle.brain_of(actor) == null:
			break
		BattleAi.take_turn(battle, battle.brain_of(actor))
	# The fight just ended: hand out rewards exactly once (Rewards only gives on a win).
	if battle.outcome() != Battle.Outcome.ONGOING and rewards == null:
		rewards = Rewards.grant(battle, battle.encounter, battle.inventory)
	refresh()


# Rebuilds the menu's rows from scratch. MenuScreen calls this on every refresh().
func _fill() -> void:
	if battle == null:
		return
	for fighter: Combatant in battle.party + battle.enemies:
		add_note(_pools_line(fighter))
	# Over: show the result, the rewards, and one Continue button.
	if battle.outcome() != Battle.Outcome.ONGOING:
		add_note(tr(_outcome_key()))
		_reward_notes()
		add_row(tr(CONTINUE_KEY), request_close)
		return
	add_note(tr(ORDER_KEY).format({"names": ", ".join(_upcoming())}))
	if _refused:
		add_note(tr(REFUSED_KEY))
	if battle.current() == null:
		return
	# A command is waiting for a target: list the targets, plus Back.
	if _pending != null:
		for target: Combatant in battle.targets_for(_pending):
			add_row(name_of(target), _aim.bind(target))
		add_row(tr(BACK_KEY), _back)
		return
	# An open submenu: its commands, plus Back.
	if _category != "":
		for command: BattleCommand in BattleMenu.in_category(_menu(), _category):
			_command_row(command)
		add_row(tr(BACK_KEY), _back)
		return
	# The first menu: the Boost selector, then commands and category rows in authored order.
	_boost_row()
	for entry: Variant in BattleMenu.top_level(_menu()):
		if entry is BattleCommand:
			_command_row(entry as BattleCommand)
		else:
			add_row(tr(entry as String), _open.bind(entry as String))


# Leaving the screen frees the fighter nodes and forgets the enemies' HP.
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


# A fighter with no authored commands gets Attack, Defend and Flee.
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


# One command's row: its label with cost or stance state, greyed out with a reason when the
# fighter cannot use it now. A greyed row has no action at all.
func _command_row(command: BattleCommand) -> void:
	var reason: String = BattleMenu.refusal(battle, command, _boost)
	var text: String = _label(command)
	var skill: Skill = command.skill
	if skill != null and skill.toggle_status != null:
		var on: bool = SkillUse.stance_on(battle.current(), skill)
		text = tr(STANCE_ON_KEY if on else STANCE_OFF_KEY).format({"label": text})
	if skill != null and skill.cost > 0 and not SkillUse.stance_on(battle.current(), skill):
		text = tr(COST_KEY).format({"label": text, "cost": skill.cost, "pool": String(skill.cost_pool).to_upper()})
	if reason != "":
		var pool: String = String(skill.cost_pool).to_upper() if skill != null else ""
		text = tr(UNAVAILABLE_KEY).format({"label": text, "reason": tr(reason).format({"pool": pool})})
	var button: Button = add_row(text, _choose.bind(command) if reason == "" else Callable())
	button.disabled = reason != ""


# The Boost selector, for a fighter with a Boost pool: pressing it steps the level up to what
# it can spend, then back to 0.
func _boost_row() -> void:
	var vitals: Vitals = Vitals.of(battle.current().get_parent())
	if vitals.maximum(battle.boost_pool) <= 0:
		return
	add_row(tr(BOOST_KEY).format({"level": _boost, "max": battle.boost_max}), _step_boost)


func _step_boost() -> void:
	var points: int = Vitals.of(battle.current().get_parent()).current(battle.boost_pool)
	_boost = _boost + 1 if _boost + 1 <= mini(battle.boost_max, points) else 0
	refresh()


func _open(category: String) -> void:
	_category = category
	_refused = false
	refresh()


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


# A one-target command asks for a target first; anything else acts immediately. A stance acts
# at once on its user.
func _choose(command: BattleCommand) -> void:
	if command.skill != null and command.skill.toggle_status != null:
		_act(command, [battle.current()])
		return
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


# Back from a target list returns to the menu it came from; back from a submenu, to the first.
func _back() -> void:
	if _pending != null:
		_pending = null
	else:
		_category = ""
	refresh()


func _act(command: BattleCommand, targets: Array[Combatant]) -> void:
	# If the battle refused (e.g. not enough MP), show a line saying so and keep the menu.
	_refused = not battle.act(command, targets, _boost)
	if not _refused:
		# The action happened: the next turn starts on the first menu with no Boost chosen.
		_boost = 0
		_category = ""
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


func _reward_notes() -> void:
	if rewards == null or battle.outcome() != Battle.Outcome.WON:
		return
	if rewards.experience > 0:
		add_note(tr(EXPERIENCE_KEY).format({"amount": rewards.experience}))
	for fighter: Combatant in battle.party:
		if rewards.levelled.has(fighter.combatant_id):
			add_note(tr(LEVEL_UP_KEY).format({"name": name_of(fighter),
					"level": Party.level_of(fighter.combatant_id)}))
	for item_id: StringName in rewards.items:
		add_note(tr(FOUND_KEY).format({"item": _item_name(item_id)}))
	for item_id: StringName in rewards.left_behind:
		add_note(tr(LEFT_KEY).format({"item": _item_name(item_id)}))


func _item_name(item_id: StringName) -> String:
	var definition: ItemDefinition = ItemDb.definition(item_id)
	return tr(definition.name_key) if definition != null else String(item_id)


func _outcome_key() -> String:
	match battle.outcome():
		Battle.Outcome.WON:
			return WON_KEY
		Battle.Outcome.LOST:
			return LOST_KEY
	return FLED_KEY
