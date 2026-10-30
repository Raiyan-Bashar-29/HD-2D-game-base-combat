extends TestCase
## The ATB gauge (C4.2): it fills by the second up to its top, counts and spends whole bars and
## keeps the part-filled one; bad rules are reported; in the field, the meter fills on fight
## time, on hits its fighter lands and on attacks it dodges, announces only real changes, and
## exists only when the loadout asks for it.
##
## OWNS: assertions about `AtbRules`, `AtbGauge` and `AtbMeter`.
## MUST NOT: name a game's fighters, or wait for frames: `tick` is called by hand.

var _player: PlayerController
var _told: Array[int] = []


func run() -> void:
	plan(20)
	SaveFixture.activate()
	Flags.clear_all()
	_the_gauge()
	_the_rules()
	_player = build("res://scenes/characters/player.tscn") as PlayerController
	attach(_player)
	_the_meter()
	_player.free()
	_no_rules_no_meter()
	CombatClock.reset()
	Flags.clear_all()


func _rules() -> AtbRules:
	var rules := AtbRules.new()
	rules.segments = 2
	rules.segment_size = 100.0
	rules.per_second = 10.0
	rules.on_hit_dealt = 30.0
	rules.on_dodge = 20.0
	return rules


func _the_gauge() -> void:
	var gauge := AtbGauge.new(_rules())
	gauge.fill(5.0)
	equal("five seconds fill 50 points", gauge.value, 50.0)
	equal("which is no whole bar yet", gauge.full_segments(), 0)
	gauge.fill(10.0)
	equal("a bar and a half is one whole bar", gauge.full_segments(), 1)
	equal("one bar can be spent, not two", [gauge.can_spend(1), gauge.can_spend(2)], [true, false])
	gauge.gain(500.0)
	equal("it never fills past its top", gauge.value, 200.0)
	equal("full, it holds every bar", [gauge.full_segments(), gauge.fraction()], [2, 1.0])
	gauge.gain(-30.0)
	equal("spending one bar of 170 keeps the part-filled one", [gauge.spend(1), gauge.value], [true, 70.0])
	equal("spending a bar it lacks fails and takes nothing", [gauge.spend(1), gauge.value], [false, 70.0])
	gauge.gain(-500.0)
	equal("it never goes below empty", gauge.value, 0.0)


func _the_rules() -> void:
	equal("the default rules are sound", AtbRules.new().problems("fixture"), PackedStringArray())
	var bad := AtbRules.new()
	bad.segments = 0
	bad.on_dodge = -1.0
	equal("no bars and a negative rate are both reported", bad.problems("fixture").size(), 2)


func _the_meter() -> void:
	var loadout := _loadout()
	ActionHost.equip(_player, loadout)
	var meter: AtbMeter = AtbMeter.of(_player)
	Events.atb_changed.connect(_on_atb_changed)
	meter.tick(1.0)
	equal("a second of fight time fills the per-second points", meter.gauge.value, 10.0)
	CombatClock.set_scale(0.0)
	meter.tick(1.0)
	equal("a stopped fight fills nothing", meter.gauge.value, 10.0)
	CombatClock.reset()
	Events.combatant_damaged.emit(&"fixture_foe", &"fixture_hero", 5, false)
	equal("a hit it lands adds its reward", meter.gauge.value, 40.0)
	Events.combatant_damaged.emit(&"fixture_foe", &"fixture_other", 5, false)
	equal("someone else's hit adds nothing", meter.gauge.value, 40.0)
	Events.attack_dodged.emit(&"fixture_hero", &"fixture_foe")
	Events.attack_dodged.emit(&"fixture_hero", &"fixture_foe")
	Events.attack_dodged.emit(&"fixture_hero", &"fixture_foe")
	equal("each attack it dodges adds its reward", meter.gauge.value, 100.0)
	meter.tick(0.0)
	equal("a frame with no change says nothing more", _told, [10, 40, 60, 80, 100])
	equal("spending through the meter takes the bar", [meter.spend(1), meter.gauge.value], [true, 0.0])
	Events.atb_changed.disconnect(_on_atb_changed)
	equal("and the loadout's rules are the gauge's", meter.gauge.rules, loadout.atb)


func _no_rules_no_meter() -> void:
	var body := build("res://scenes/characters/player.tscn") as PlayerController
	attach(body)
	var loadout := _loadout()
	loadout.atb = null
	ActionHost.equip(body, loadout)
	equal("a loadout with no ATB rules gets no meter", AtbMeter.of(body), null)
	body.free()


func _on_atb_changed(_who: StringName, value: float, _segments: int) -> void:
	_told.append(floori(value))


func _loadout() -> ActionLoadout:
	var def := CombatantDef.new()
	def.combatant_id = &"fixture_hero"
	def.faction = &"player"
	def.base_stats = {&"max_hp": 40.0}
	var swing := ActionMove.new()
	var made := ActionLoadout.new()
	made.fighter = def
	made.moves = MoveSet.new()
	made.moves.attack_chain = [swing]
	made.atb = _rules()
	return made
