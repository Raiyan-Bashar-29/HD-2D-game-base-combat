class_name CombatHud
extends Label
## The field combat readout (C3.9): the player's pools and statuses, and the locked target's
## name and hp. One Label under `UILayer`, beside the clock, the way every HUD readout here is
## its own node listening on `Events` (see `hud_clock.gd` for why there is no `Hud` parent).
##
## IN PLAIN WORDS: it shows nothing until the player is a fighter (the loadout fitted them,
## C3.4). Then it reads, at the bottom left:
##     HP 25 / 30   MP 8 / 10   ATB 1 / 2  40%   [Poisoned]
##     [1] Bolt   5 MP   [2] Gate  (ready in 3s)
##     Thorn Wisp   HP 12 / 20
## the ATB part only for a fighter with an ATB gauge (C4.4): whole bars ready out of all of them,
## then how full the next bar is. The slot line (C6.3b) only for a fighter with hero powers: each
## quick slot's key, its power's name, and its cost, or why it cannot be used now (the same words
## the command menu uses, from `PowerMenu`). The last line only while something is locked on.
## It redraws whenever a pool moves, a status starts or ends, the lock changes, or a cooldown's
## whole seconds tick down (`Events.power_cooldown_changed`), and never polls.
##
## OWNS: the rendering of the player's and the locked target's combat state.
## MUST NOT: change anything it shows, or find targets (it shows what `LockOn` announces).

const HP_KEY: String = "ui.combat_hud.hp"
const TARGET_KEY: String = "ui.combat_hud.target"
const ATB_KEY: String = "ui.combat_hud.atb"
const SLOT_KEY: String = "ui.combat_hud.slot"
const COST_KEY: String = "ui.battle.cost"
const UNAVAILABLE_KEY: String = "ui.battle.unavailable"
const POOL_KEY: String = "ui.battle.pool"
const STATUSES_KEY: String = "ui.battle.statuses"
const VARIATION: StringName = &"HudText"
const PALETTE: StringName = &"UiPalette"

## Whose state is shown. Null means the live player, `Director.player`; a test sets its own.
var subject: Node
## The combatant id of the locked target, or `&""` for none.
var target_id: StringName = &""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -132.0
	offset_bottom = -24.0
	offset_left = 32.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme_type_variation = VARIATION
	add_theme_color_override(&"font_color", get_theme_color(&"text", PALETTE))
	Events.vitals_changed.connect(func(_w: StringName, _p: StringName, _v: int, _m: int) -> void: refresh())
	Events.status_applied.connect(func(_w: StringName, _s: StringName, _n: int) -> void: refresh())
	Events.status_expired.connect(func(_w: StringName, _s: StringName) -> void: refresh())
	Events.lock_on_changed.connect(_on_lock_on_changed)
	Events.atb_changed.connect(func(_w: StringName, _v: float, _s: int) -> void: refresh())
	Events.power_cooldown_changed.connect(func(_w: StringName, _p: StringName, _l: int) -> void: refresh())
	# The fighter's parts are fitted a frame after the player spawns (C3.4), so look then.
	Events.player_spawned.connect(func(_p: Node3D) -> void: refresh.call_deferred())
	Events.player_despawned.connect(refresh)
	refresh()


## Redraws from what the subject holds now. Hidden when it is not a fighter.
func refresh() -> void:
	var who: Node = subject if subject != null else Director.player
	var fighter: Combatant = Combatant.of(who) if who != null and is_instance_valid(who) else null
	visible = fighter != null
	if fighter == null:
		text = ""
		return
	var lines: Array[String] = [_fighter_line(fighter)]
	var slots: String = slot_text(fighter)
	if slots != "":
		lines.append(slots)
	var target: Combatant = _target()
	if target != null:
		var vitals: Vitals = Vitals.of(target.get_parent())
		var line: String = tr(TARGET_KEY).format({"name": _name_of(target),
			"hp": vitals.current(&"hp"), "max": vitals.maximum(&"hp")})
		# The target's statuses too, so a pressured or staggered foe shows it (C4.6).
		var held: String = _statuses_text(target)
		lines.append(line if held == "" else line + "   " + held)
	text = "\n".join(lines)


func _fighter_line(fighter: Combatant) -> String:
	var vitals: Vitals = Vitals.of(fighter.get_parent())
	var parts: Array[String] = [tr(HP_KEY).format({"hp": vitals.current(&"hp"), "max": vitals.maximum(&"hp")})]
	for stat: StringName in fighter.sheet.mentioned(Vitals.MAX_PREFIX):
		var pool := StringName(String(stat).trim_prefix(Vitals.MAX_PREFIX))
		if pool != fighter.damage_pool and vitals.maximum(pool) > 0:
			parts.append(tr(POOL_KEY).format({"pool": String(pool).to_upper(),
				"current": vitals.current(pool), "max": vitals.maximum(pool)}))
	var meter: AtbMeter = AtbMeter.of(fighter.get_parent())
	if meter != null:
		parts.append(atb_text(meter.gauge))
	var held: String = _statuses_text(fighter)
	if held != "":
		parts.append(held)
	# The form held now leads the line (C6.5d).
	var form: String = LookSwap.form_name_key(fighter.get_parent())
	if form != "":
		parts.push_front(tr(form))
	return "   ".join(parts)


## The quick-slot line: for each slotted power, its key, its name, and its cost or the reason it
## is refused ("ready in 3s"). "" for a fighter with no powers. Public so a test reads it.
func slot_text(fighter: Combatant) -> String:
	var parts: Array[String] = []
	var slotted: Array[Power] = PowerSlots.powers(fighter)
	for slot: int in slotted.size():
		var power: Power = slotted[slot]
		var label: String = tr(power.name_key)
		if power.skill != null and power.skill.cost > 0:
			label = tr(COST_KEY).format({"label": label, "cost": SkillUse.cost_of(fighter, power.skill),
				"pool": String(power.skill.cost_pool).to_upper()})
		var reason: String = PowerMenu.reason_key(fighter, power)
		if reason != "":
			var args: Dictionary = PowerMenu.reason_args(fighter, BattleCommand.for_power(power))
			label = tr(UNAVAILABLE_KEY).format({"label": label, "reason": tr(reason).format(args)})
		parts.append(tr(SLOT_KEY).format({"key": KeyBindings.text_for(CombatActions.SLOTS[slot], false),
			"label": label}))
	return "   ".join(parts)


## The statuses `fighter` holds, as one translated line, or "" when it holds none.
func _statuses_text(fighter: Combatant) -> String:
	var names: Array[String] = []
	var statuses: StatusSet = StatusSet.of(fighter.get_parent())
	for effect: StatusEffect in statuses.held() if statuses != null else []:
		names.append(tr(effect.name_key) if effect.name_key != "" else _tail(effect.id))
	return "" if names.is_empty() else tr(STATUSES_KEY).format({"list": ", ".join(names)})


## The ATB readout: whole bars ready out of all of them, and how full the next one is (100 when
## every bar is full). The command menu's top line is the same text.
static func atb_text(gauge: AtbGauge) -> String:
	var bars: int = gauge.full_segments()
	var size: float = gauge.rules.segment_size
	var part: int = 100 if bars >= gauge.rules.segments else floori((gauge.value - bars * size) / size * 100.0)
	return TranslationServer.translate(ATB_KEY).format({"bars": bars, "max": gauge.rules.segments, "part": part})


## The locked target's combatant, found among the hurtboxes; null when nothing is locked.
func _target() -> Combatant:
	if target_id == &"" or not is_inside_tree():
		return null
	for node: Node in get_tree().get_nodes_in_group(Hurtbox.GROUP):
		var hurtbox: Hurtbox = node as Hurtbox
		if hurtbox != null and hurtbox.fighter() != null and hurtbox.fighter().combatant_id == target_id:
			return hurtbox.fighter()
	return null


## A real-time enemy's translated name, or the last part of its id.
func _name_of(target: Combatant) -> String:
	var enemy: ActionEnemy = target.get_parent() as ActionEnemy
	if enemy != null and enemy.fighter != null and enemy.fighter.name_key != "":
		return tr(enemy.fighter.name_key)
	return _tail(target.kind if target.kind != &"" else target.combatant_id)


func _on_lock_on_changed(_who: StringName, target: StringName) -> void:
	target_id = target
	refresh()


static func _tail(id: StringName) -> String:
	var text_id: String = String(id)
	return text_id.get_slice("/", text_id.get_slice_count("/") - 1)
