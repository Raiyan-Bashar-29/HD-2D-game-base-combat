extends TestCase
## A battlefield said aloud (C6.9g): the signals it sends as it rises, comes down, shatters and
## clashes, the battle log's lines for them, and the HUD's line naming it and its place.
##
## OWNS: assertions about `Events.battlefield_raised`, `battlefield_lowered`, `battlefield_clashed`,
## `BattleLog`'s battlefield lines and `CombatHud.field_text`.
## MUST NOT: name a game's places, powers or characters, or wait for frames.

const NOON: float = 12.0

var _world: Node3D
var _rng := RandomNumberGenerator.new()
var _me: Combatant
var _rival: Combatant
var _heard: Array[Array] = []
var _log: BattleLog
var _hud: CombatHud


func run() -> void:
	plan(12)
	Flags.clear_all()
	_rng.seed = 7
	_world = Node3D.new()
	attach(_world)
	_me = _fighter(&"fixture_news_me", &"player", Vector3.ZERO, _kit(&"me", true, 1.0))
	_rival = _fighter(&"fixture_news_rival", &"enemy", Vector3(0.0, 0.0, -3.0), _kit(&"rival", false, 2.0))
	_log = BattleLog.new(Battle.new([_me], [_rival]), func(who: Combatant) -> String: return String(who.combatant_id))
	_log.start()
	_hud = CombatHud.new()
	attach(_hud)
	_hud.subject = _me.get_parent()
	Events.battlefield_raised.connect(_on_raised)
	Events.battlefield_lowered.connect(_on_lowered)
	Events.battlefield_clashed.connect(_on_clashed)
	_rise_and_fade()
	_shatter()
	_clash()
	Events.battlefield_raised.disconnect(_on_raised)
	Events.battlefield_lowered.disconnect(_on_lowered)
	Events.battlefield_clashed.disconnect(_on_clashed)
	_log.stop()
	_world.free()
	Flags.clear_all()


# Rising says so with its place; running out says it faded, not shattered.
func _rise_and_fade() -> void:
	_use(_me)
	equal("a battlefield rising says so", _heard.back(), [&"raised", &"fixture_news_me", _power_id(&"me")])
	equal("the log names it and its place", _log.lines.back(), tr(BattleLog.FIELD_PLACE_KEY).format(
		{"name": "fixture_news_me", "power": tr("fixture.power"), "place": tr("fixture.place")}))
	equal("the HUD names it and its place", _hud.field_text(_me),
		tr(CombatHud.FIELD_PLACE_KEY).format({"power": tr("fixture.power"), "place": tr("fixture.place")}))
	PowerSet.of(_me.get_parent()).tick_seconds(11.0)
	equal("a battlefield running out comes down unbroken", _heard.back(),
		[&"lowered", &"fixture_news_me", _power_id(&"me"), false])
	equal("the log says it fades", _log.lines.back(), tr(BattleLog.FIELD_FADED_KEY).format(
		{"name": "fixture_news_me", "power": tr("fixture.power")}))
	equal("the HUD drops it", _hud.field_text(_me), "")


# A hit that breaks it shatters it.
func _shatter() -> void:
	PowerSet.of(_me.get_parent()).tick_seconds(60.0)
	_use(_me)
	_run(_me).break_down()
	equal("a broken battlefield comes down shattered", _heard.back(),
		[&"lowered", &"fixture_news_me", _power_id(&"me"), true])
	equal("the log says it shatters", _log.lines.back(), tr(BattleLog.FIELD_SHATTERED_KEY).format(
		{"name": "fixture_news_me", "power": tr("fixture.power")}))


# A stronger battlefield rising over one standing clashes with it and shatters it. One with no
# place is named alone.
func _clash() -> void:
	PowerSet.of(_me.get_parent()).tick_seconds(60.0)
	_use(_me)
	_heard.clear()
	_use(_rival)
	equal("a rising battlefield clashes with the one standing", _heard[0],
		[&"clashed", &"fixture_news_rival", &"fixture_news_me"])
	equal("the weaker one shatters", _heard[1], [&"lowered", &"fixture_news_me", _power_id(&"me"), true])
	# The log keeps the newest few lines, and the statuses the fields put on are among them.
	equal("the log says they clashed", _log.lines.has(tr(BattleLog.FIELD_CLASHED_KEY)
		.format({"name": "fixture_news_rival", "rival": "fixture_news_me"})), true)
	equal("a battlefield with no place is named alone", _log.lines.has(tr(BattleLog.FIELD_RAISED_KEY)
		.format({"name": "fixture_news_rival", "power": tr("fixture.power")})), true)


# --- fixtures -----------------------------------------------------------------------------------

func _on_raised(who: StringName, power_id: StringName) -> void:
	_heard.append([&"raised", who, power_id])


func _on_lowered(who: StringName, power_id: StringName, broken: bool) -> void:
	_heard.append([&"lowered", who, power_id, broken])


func _on_clashed(who: StringName, rival: StringName) -> void:
	_heard.append([&"clashed", who, rival])


func _use(who: Combatant) -> void:
	PowerUse.use(who, PowerSet.of(who.get_parent()).kits()[0].powers[0], [], _rng, NOON)


func _power_id(tag: StringName) -> StringName:
	return StringName("power/fixture_news_" + String(tag))


# A kit of one battlefield 5 m across standing 10 seconds, with a place look when `placed`.
func _kit(tag: StringName, placed: bool, refinement: float) -> PowerKit:
	var field := BattlefieldMechanism.new()
	var status := StatusEffect.new()
	status.id = StringName("status/fixture_news_" + String(tag))
	status.name_key = "fixture.status"
	status.duration = 0.0
	field.status = status
	field.effects = [BattlefieldEffect.new()]
	field.radius = 5.0
	field.seconds = 10.0
	field.refinement = refinement
	if placed:
		field.place = PlaceLook.new()
		field.place.id = &"place/fixture_news"
		field.place.name_key = "fixture.place"
	var power := Power.new()
	power.power_id = _power_id(tag)
	power.name_key = "fixture.power"
	power.mechanism = field
	var kit := PowerKit.new()
	kit.kit_id = StringName("kit/fixture_news_" + String(tag))
	kit.name_key = "fixture.kit"
	kit.powers = [power]
	return kit


func _run(who: Combatant) -> BattlefieldRun:
	return BattlefieldNews.field_of(who, _power_id(&"me"))


func _fighter(id: StringName, faction: StringName, at: Vector3, kit: PowerKit) -> Combatant:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = id
	fighter.faction = faction
	fighter.real_time = true
	fighter.base_stats = {&"max_hp": 100.0, &"max_mp": 10.0, &"attack": 6.0, &"defence": 1.0}
	fighter.formula = DamageFormula.new()
	fighter.formula.stages = [AttackDefenceStage.new()]
	actor.add_child(fighter)
	actor.add_child(PowerSet.new())
	_world.add_child(actor)
	PowerSet.of(actor).equip(kit)
	return fighter
