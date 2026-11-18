extends TestCase
## Names for pools, elements, tags and the break (C10.4): a pool with a `combat.pool.` row shows
## that name and one without shows its id in capitals; an element or tag reads its row, else its
## bare id; the default break status has a name; a fighter's line and a cost row use them.
##
## OWNS: assertions about `CombatNames` and the break status's name.
## MUST NOT: name a game's pools, elements or tags. The rows are a translation made here.

var _words: Translation


func run() -> void:
	plan(5)
	SaveFixture.activate()
	Flags.clear_all()
	_words = Translation.new()
	_words.locale = TranslationServer.get_locale()
	_words.add_message("combat.pool.fixture_rage", "Fury")
	_words.add_message("combat.element.fixture_spark", "Spark")
	_words.add_message("combat.tag.fixture_edge", "Edge")
	TranslationServer.add_translation(_words)
	equal("a pool reads its row, else its id in capitals",
		[CombatNames.pool(&"fixture_rage"), CombatNames.pool(&"fixture_dread")], ["Fury", "FIXTURE_DREAD"])
	equal("an element reads its element row, a tag its tag row, else the bare id",
		[CombatNames.mark(&"fixture_spark"), CombatNames.mark(&"fixture_edge"), CombatNames.mark(&"fixture_none")],
		["Spark", "Edge", "fixture_none"])
	var broken: StatusEffect = Weakness.broken_status()
	equal("the default break has a name of its own",
		[broken.name_key != "", tr(broken.name_key) != broken.name_key], [true, true])
	_a_fighters_line()
	TranslationServer.remove_translation(_words)
	Flags.clear_all()


func _a_fighters_line() -> void:
	var actor := Node.new()
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = &"fixture_named"
	fighter.base_stats = {&"max_hp": 20.0, &"max_fixture_rage": 6.0}
	fighter.weak_to = [&"fixture_spark", &"fixture_edge"]
	actor.add_child(fighter)
	attach(actor)
	Weakness.reveal_all(fighter)
	var line: String = BattleReadout.line(fighter, "x", null)
	equal("a fighter's line names its other pool and its found weaknesses",
		[line.contains(tr(BattleScreen.POOL_KEY).format({"pool": "Fury", "current": 6, "max": 6})),
			line.contains(tr(BattleScreen.WEAK_KEY).format({"list": "Spark, Edge"}))], [true, true])
	var skill := Skill.new()
	skill.cost_pool = &"fixture_rage"
	var command := BattleCommand.new()
	command.kind = BattleCommand.Kind.SKILL
	command.skill = skill
	equal("a cost's pool is named too", PowerMenu.reason_args(fighter, command)["pool"], "Fury")
	actor.free()
