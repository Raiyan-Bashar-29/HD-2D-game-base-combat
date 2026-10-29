extends TestCase
## `StrikeTarget` and `Combatant.base_stats`: an interaction that resolves one hit through the
## combat core, toasts the result, refuses a defeated target, and stands a dummy back up.
##
## OWNS: assertions about what striking a target does to it and what it reports.
## MUST NOT: name a game's targets, keys or stats. Every name here is made up for the case.

const STRUCK: String = "fixture.struck"
const CRITICAL: String = "fixture.critical"

var _keys: Array[String] = []
var _args: Array[Dictionary] = []


func run() -> void:
	plan(14)
	SaveFixture.activate()
	Flags.clear_all()
	Events.notify_requested.connect(_on_notify)
	_base_stats_fill_the_sheet()
	_a_bare_hand_strikes_with_power_alone()
	_an_attacker_combatant_adds_its_attack()
	_a_critical_hit_uses_its_own_line()
	_a_defeated_target_is_refused()
	_a_dummy_stands_back_up()
	_no_combatant_is_not_offered()
	Events.notify_requested.disconnect(_on_notify)
	Flags.clear_all()


func _target(id: StringName, max_hp: float, stages: Array[DamageStage]) -> StrikeTarget:
	var strike := StrikeTarget.new()
	strike.label_key = "fixture.label"
	strike.struck_key = STRUCK
	strike.power = 6.0
	strike.add_child(Vitals.new())
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.base_stats = {&"max_hp": max_hp}
	combatant.formula = DamageFormula.new()
	combatant.formula.stages = stages
	strike.add_child(combatant)
	attach(strike)
	return strike


func _plain() -> Array[DamageStage]:
	return [AttackDefenceStage.new()]


func _hand() -> Node3D:
	var hand := Node3D.new()
	attach(hand)
	return hand


func _base_stats_fill_the_sheet() -> void:
	var strike := _target(&"fixture_sheet", 20.0, _plain())
	equal("base_stats reach the sheet on ready", Vitals.of(strike).maximum(&"hp"), 20)
	equal("and an unhurt target is full", Vitals.of(strike).current(&"hp"), 20)
	strike.free()


func _a_bare_hand_strikes_with_power_alone() -> void:
	Flags.clear_all()
	_keys.clear()
	_args.clear()
	var strike := _target(&"fixture_bare", 20.0, _plain())
	var hand := _hand()
	equal("a strike is an interaction that succeeds", strike.attempt(hand), true)
	equal("power alone came off: 20 - 6", Vitals.of(strike).current(&"hp"), 14)
	equal("the result is toasted by key", _keys, [STRUCK])
	equal("with the amount, what is left and the maximum",
			_args.size() == 1 and _args[0] == {"amount": 6, "left": 14, "max": 20}, true)
	strike.free()
	hand.free()


func _an_attacker_combatant_adds_its_attack() -> void:
	Flags.clear_all()
	var strike := _target(&"fixture_struck", 20.0, _plain())
	var hand := _hand()
	var mine := Combatant.new()
	mine.combatant_id = &"fixture_hand"
	mine.base_stats = {&"attack": 4.0}
	mine.formula = DamageFormula.new()
	mine.formula.stages = _plain()
	hand.add_child(mine)
	strike.attempt(hand)
	equal("the attacker's sheet resolves the hit: 20 - (6 + 4)", Vitals.of(strike).current(&"hp"), 10)
	strike.free()
	hand.free()


func _a_critical_hit_uses_its_own_line() -> void:
	Flags.clear_all()
	_keys.clear()
	var crit := CritStage.new()
	crit.base_chance = 1.0
	var stages: Array[DamageStage] = [AttackDefenceStage.new(), crit]
	var strike := _target(&"fixture_crit", 20.0, stages)
	strike.critical_key = CRITICAL
	var hand := _hand()
	strike.attempt(hand)
	equal("a critical hit toasts the critical line", _keys, [CRITICAL])
	strike.free()
	hand.free()


func _a_defeated_target_is_refused() -> void:
	Flags.clear_all()
	var strike := _target(&"fixture_fallen", 6.0, _plain())
	var hand := _hand()
	strike.attempt(hand)
	equal("one hit of 6 defeats a target of 6", Vitals.of(strike).is_defeated(), true)
	equal("a defeated target is refused as already done", strike.refusal(hand), GameEnums.RefusalReason.ALREADY_DONE)
	equal("and a second strike does not happen", strike.attempt(hand), false)
	strike.free()
	hand.free()


func _a_dummy_stands_back_up() -> void:
	Flags.clear_all()
	_args.clear()
	var strike := _target(&"fixture_dummy", 6.0, _plain())
	strike.revive_when_defeated = true
	var hand := _hand()
	strike.attempt(hand)
	equal("the toast reports the defeating hit at zero", _args.size() == 1 and _args[0]["left"] == 0, true)
	equal("then a dummy revives to full", Vitals.of(strike).current(&"hp"), 6)
	strike.free()
	hand.free()


func _no_combatant_is_not_offered() -> void:
	var strike := StrikeTarget.new()
	strike.label_key = "fixture.label"
	attach(strike)
	equal("a strike target with no Combatant is not offered", strike.is_offerable(), false)
	strike.free()


func _on_notify(key: String, _seconds: float, args: Dictionary) -> void:
	_keys.append(key)
	_args.append(args)
