class_name CommandOverlay
extends MenuScreen
## The hybrid's command menu (C4.4): opened mid-fight, it lists the fighter's field commands and
## spends ATB bars on the one chosen, while the fight carries on in slow motion behind it.
##
## IN PLAIN WORDS: press the command key in a fight and this menu comes up over the world. The
## top line shows the ATB bars. Below are the commands from the loadout, grouped into categories
## the way the battle menu groups them (`BattleMenu.top_level`). Each row shows what it costs in
## bars and in mp. A row that cannot be used right now is greyed out with the reason beside it.
## Picking a usable row does it (`FieldCommands.use`) and closes the menu.
##
## THE WORLD KEEPS GOING, SLOWLY. `pauses_world` is false, so the area, the weather and the clock
## run as normal. Only the fight slows: `CombatClock` drops to `[combat] hybrid/slow` (0.1 by
## default; 0 is "wait mode", where the fight stops until the menu closes) when the menu opens,
## and goes back to full speed when it closes. While the menu is up, the stack holds the player's
## input, so they cannot swing or roll behind it.
##
## IT DECIDES NOTHING. Who a command lands on, why it is refused, and what it does all come from
## `FieldCommands`. This file turns a `FieldCommands.Reason` into the words a player reads.
##
## OWNS: which menu is up, drawing the rows, and slowing the fight while it is open.
## MUST NOT: aim, refuse or resolve a command itself, or leave the fight slowed after it closes.

const SCREEN_ID: StringName = &"field_command"
const TITLE_KEY: String = "ui.field_command.title"
const ATB_COST_KEY: String = "ui.field_command.atb_cost"
const ATB_REASON_KEY: String = "ui.field_command.reason.atb"
const COST_KEY: String = "ui.battle.cost"
const UNAVAILABLE_KEY: String = "ui.battle.unavailable"
const BACK_KEY: String = "ui.battle.back"
## How slow the fight runs while the menu is open, as a fraction of full speed.
const SLOW_SETTING: String = "combat/hybrid/slow"
const SLOW_DEFAULT: float = 0.1

## The fighter using the menu, and what it offers.
var user: Combatant
var commands: Array[BattleCommand] = []
## The open category's key; empty on the first menu.
var _category: String = ""
## The bar count the rows were last drawn with, so a bar filling redraws them.
var _bars: int = -1
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	screen_id = SCREEN_ID
	pauses_world = false
	closes_on_cancel = true
	title_key = TITLE_KEY
	opaque = false


## The one way to build the menu: for `fighter`, offering `offered`.
static func for_fighter(fighter: Combatant, offered: Array[BattleCommand]) -> CommandOverlay:
	var screen := CommandOverlay.new()
	screen.user = fighter
	screen.commands = offered
	return screen


## How slow the fight runs while a menu is open: the project setting, never below 0.
static func slow() -> float:
	var configured: float = ProjectSettings.get_setting(SLOW_SETTING, SLOW_DEFAULT)
	return maxf(0.0, configured)


## The words for `reason`, or "" for `Reason.NONE`. The battle menu's keys where the meaning is
## the same, so a player reads one phrase for one problem in both kinds of fight.
static func reason_key(reason: FieldCommands.Reason) -> String:
	match reason:
		FieldCommands.Reason.ATB:
			return ATB_REASON_KEY
		FieldCommands.Reason.BLOCKED:
			return BattleMenu.BLOCKED_REASON_KEY
		FieldCommands.Reason.COST:
			return BattleMenu.COST_REASON_KEY
		FieldCommands.Reason.ITEM:
			return BattleMenu.ITEM_REASON_KEY
		FieldCommands.Reason.TARGET:
			return BattleMenu.TARGET_REASON_KEY
	return ""


func _ready() -> void:
	_rng.randomize()
	super()
	# A bar filling while the menu is up makes a greyed row usable, so redraw then (and only
	# then: a redraw puts focus back on the first row).
	Events.atb_changed.connect(_on_atb_changed)


func _opened() -> void:
	super()
	CombatClock.set_scale(slow())


# Full speed again the moment the menu goes, however it went: a choice, cancel, or an area change.
func _closed() -> void:
	CombatClock.reset()


func _fill() -> void:
	if user == null:
		return
	var meter: AtbMeter = AtbMeter.of(user.get_parent())
	_bars = meter.gauge.full_segments() if meter != null else 0
	if meter != null:
		add_note(CombatHud.atb_text(meter.gauge))
	if _category != "":
		for command: BattleCommand in BattleMenu.in_category(commands, _category):
			_command_row(command)
		add_row(tr(BACK_KEY), _back)
		return
	for entry: Variant in BattleMenu.top_level(commands):
		if entry is BattleCommand:
			_command_row(entry as BattleCommand)
		else:
			add_row(tr(entry as String), _open.bind(entry as String))


# One command's row: its name, its cost in bars and mp, and the reason it is greyed out, if it is.
# A greyed row has no action at all.
func _command_row(command: BattleCommand) -> void:
	var skill: Skill = command.skill
	var text: String = tr(command.label_key) if command.label_key != "" else (tr(skill.name_key) if skill != null else "")
	if skill != null:
		text = tr(ATB_COST_KEY).format({"label": text, "bars": skill.atb_cost})
		if skill.cost > 0 and command.kind != BattleCommand.Kind.ITEM:
			text = tr(COST_KEY).format({"label": text, "cost": skill.cost, "pool": String(skill.cost_pool).to_upper()})
	var reason: String = reason_key(FieldCommands.refusal(user, command))
	if reason != "":
		var pool: String = String(skill.cost_pool).to_upper() if skill != null else ""
		text = tr(UNAVAILABLE_KEY).format({"label": text, "reason": tr(reason).format({"pool": pool})})
	var button: Button = add_row(text, _choose.bind(command) if reason == "" else Callable())
	button.disabled = reason != ""


func _choose(command: BattleCommand) -> void:
	# A fighter who fell while the menu was up does nothing; the menu just goes.
	var vitals: Vitals = Vitals.of(user.get_parent())
	if vitals == null or not vitals.is_defeated():
		FieldCommands.use(user, command, _rng)
	request_close()


func _open(category: String) -> void:
	_category = category
	refresh()


func _back() -> void:
	_category = ""
	refresh()


func _on_atb_changed(who: StringName, _value: float, segments: int) -> void:
	if user != null and who == user.combatant_id and segments != _bars:
		refresh()
