class_name AtbMeter
extends Node
## A fighter's ATB gauge, living in the field (C4.2): a child of the fighter's body, beside its
## `Vitals`, that fills the gauge as the fight goes on.
##
## IN PLAIN WORDS: every physics frame it adds the passive fill for that much FIGHT time, so a
## fight slowed or stopped by `CombatClock` fills slowly or not at all. When its fighter lands
## a hit (`combatant_damaged` names it as the attacker) or dodges one (`attack_dodged` names it
## as the target), it adds that reward. A fallen fighter gains nothing.
##
## IT ANNOUNCES ITSELF ONLY WHEN SOMETHING VISIBLE CHANGES: a whole point, or a whole bar. So a
## HUD redraws a few times a second, not every frame.
##
## OWNS: this fighter's `AtbGauge`, and when it fills.
## MUST NOT: open a menu or use a command. The hybrid's menu (C4.3) calls `spend`.

var gauge: AtbGauge = AtbGauge.new()
var _told_value: int = -1
var _told_bars: int = -1


## The meter under `who`, or null.
static func of(who: Node) -> AtbMeter:
	if who == null:
		return null
	for child: Node in who.get_children():
		var found: AtbMeter = child as AtbMeter
		if found != null:
			return found
	return null


func _ready() -> void:
	Events.combatant_damaged.connect(_on_damaged)
	Events.attack_dodged.connect(_on_dodged)


func _physics_process(delta: float) -> void:
	tick(delta)


## `delta` seconds of real time pass; the gauge fills for that much fight time.
func tick(delta: float) -> void:
	if not _down():
		gauge.fill(CombatClock.scaled(delta))
	_announce()


## Spends `bars` whole bars, for a command. False, and nothing spent, when there are not enough.
func spend(bars: int) -> bool:
	var spent: bool = gauge.spend(bars)
	_announce()
	return spent


func _on_damaged(_who: StringName, by: StringName, amount: int, _critical: bool) -> void:
	if amount > 0 and by != &"" and by == _id() and not _down():
		gauge.gain(gauge.rules.on_hit_dealt)
		_announce()


func _on_dodged(who: StringName, _by: StringName) -> void:
	if who != &"" and who == _id() and not _down():
		gauge.gain(gauge.rules.on_dodge)
		_announce()


func _id() -> StringName:
	var fighter: Combatant = Combatant.of(get_parent())
	return fighter.combatant_id if fighter != null else &""


func _down() -> bool:
	var vitals: Vitals = Vitals.of(get_parent())
	return vitals != null and vitals.is_defeated()


func _announce() -> void:
	var shown: int = floori(gauge.value)
	var bars: int = gauge.full_segments()
	if shown == _told_value and bars == _told_bars:
		return
	_told_value = shown
	_told_bars = bars
	Events.atb_changed.emit(_id(), gauge.value, bars)
