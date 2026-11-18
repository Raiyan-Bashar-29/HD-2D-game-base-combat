extends TestCase
## The party screen (C10.20): each member's row gives its level, experience to the next level and
## hp; pressing two members trades their places across the lines; a picked member in the fight
## may be sent to wait, but never the last one; the party key opens and closes it.
##
## OWNS: assertions about `PartyScreen` and `LoadoutHost.toggle_party`.
## MUST NOT: name a game's fighters. Every member here is made up for the case.

var _stack: UiRoot


func run() -> void:
	plan(5)
	SaveFixture.activate()
	Flags.clear_all()
	_stack = UiRoot.new()
	attach(_stack)
	var roster: Array[CombatantDef] = [_def(&"fixture_party_a"), _def(&"fixture_party_b"), _def(&"fixture_party_c")]
	Party.arrange([&"fixture_party_a", &"fixture_party_b"], [&"fixture_party_c"])
	Flags.set_flag(&"vital/fixture_party_b/hp", 12)
	var screen := PartyScreen.for_roster(roster, {} as Dictionary[StringName, Node])
	_stack.open(screen)
	equal("a row gives the member's level, experience to the next and hp",
		screen.row_texts().has(PartyScreen.member_line(roster[1], null)) and PartyScreen.member_line(roster[1], null) ==
			tr(PartyScreen.MEMBER_KEY).format({"name": tr("fixture.name.fixture_party_b"), "level": 1, "exp": 0,
				"next": roster[1].level_curve.exp_for(2), "hp": 12, "max": 30}), true)
	_press(screen, PartyScreen.member_line(roster[1], null))
	_press(screen, PartyScreen.member_line(roster[2], null))
	equal("pressing two members trades their places across the lines",
		[_ids(Party.active(roster)), _ids(Party.reserve(roster))],
		[[&"fixture_party_a", &"fixture_party_c"], [&"fixture_party_b"]])
	_press(screen, PartyScreen.member_line(roster[0], null))
	_press(screen, tr(PartyScreen.BENCH_KEY))
	equal("a picked member in the fight may be sent to wait", _ids(Party.reserve(roster)),
		[&"fixture_party_b", &"fixture_party_a"])
	_press(screen, PartyScreen.member_line(roster[2], null))
	equal("but the last one in the fight never", screen.row_texts().has(tr(PartyScreen.BENCH_KEY)), false)
	_stack.close_all()
	var host := LoadoutHost.new()
	attach(host)
	var opened: bool = host.toggle_party(_stack, null, roster)
	var shown: bool = _stack.top() is PartyScreen
	host.toggle_party(_stack, null, roster)
	equal("the party key opens the screen and closes it again", [opened, shown, _stack.depth()], [true, true, 0])
	host.free()
	_stack.free()
	Flags.clear_all()


func _def(id: StringName) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "fixture.name." + String(id)
	def.faction = &"player"
	def.base_stats = {&"max_hp": 30.0}
	def.level_curve = LevelCurve.new()
	return def


func _ids(defs: Array[CombatantDef]) -> Array[StringName]:
	var out: Array[StringName] = []
	for def: CombatantDef in defs:
		out.append(def.combatant_id)
	return out


func _press(screen: MenuScreen, text: String) -> void:
	for child: Node in screen.rows.get_children():
		var button: Button = child as Button
		if button != null and not button.is_queued_for_deletion() and button.text.ends_with(text):
			button.pressed.emit()
			return
