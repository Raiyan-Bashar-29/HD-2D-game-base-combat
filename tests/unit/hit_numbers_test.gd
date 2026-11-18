extends TestCase
## Field feedback (C10.12): a hurt real-time fighter gets its amount floating above it, bigger
## and marked when critical, gone after its life; the body flashes and gets its colour back;
## a block, a miss and a dodge show their words; a timed press is graded and shown; a fighter
## that is not real-time shows nothing.
##
## OWNS: assertions about `HitNumbers`, `HitFlash` and `TimedWindow.grade`.
## MUST NOT: name a game's fighters, or wait for frames.

var _bodies: Array[Node] = []


func run() -> void:
	plan(6)
	SaveFixture.activate()
	var numbers := HitNumbers.new()
	attach(numbers)
	var hero: Node3D = _body(&"fixture_pop_hero", true, Vector3(2.0, 0.0, 0.0))
	var sprite: Sprite3D = hero.get_node(^"Visual/Sprite") as Sprite3D
	Events.combatant_damaged.emit(&"fixture_pop_hero", &"fixture_pop_foe", 7, false)
	var first: Label3D = numbers.shown.keys()[0]
	equal("a hurt fighter's amount floats above it, and its body flashes",
		[first.text, first.global_position.is_equal_approx(Vector3(2.0, HitNumbers.HEIGHT, 0.0)), sprite.modulate.r, sprite.modulate.g],
		[tr(HitNumbers.AMOUNT_KEY).format({"amount": 7}), true, HitFlash.TINT.r, HitFlash.TINT.g])
	numbers._process(HitNumbers.LIFE + 0.1)
	(hero.get_node(^"HitFlash") as HitFlash)._process(1.0)
	equal("after its life the number goes, and the body gets its own colour back",
		[first.is_queued_for_deletion(), numbers.shown.size(), sprite.modulate], [true, 0, Color(1, 1, 1, 0.5)])
	Events.combatant_damaged.emit(&"fixture_pop_hero", &"fixture_pop_foe", 30, true)
	var big: Label3D = numbers.shown.keys()[0]
	equal("a critical hit is bigger and marked",
		[big.text, big.font_size], [tr(HitNumbers.CRITICAL_KEY).format({"amount": 30}), HitNumbers.CRITICAL_SIZE])
	numbers._process(HitNumbers.LIFE + 0.1)
	Events.attack_blocked.emit(&"fixture_pop_hero", &"fixture_pop_foe")
	Events.attack_missed.emit(&"fixture_pop_hero", &"fixture_pop_foe")
	Events.attack_dodged.emit(&"fixture_pop_hero", &"fixture_pop_foe")
	Events.prompt_graded.emit(&"fixture_pop_hero", &"perfect")
	var words: Array[String] = []
	for label: Label3D in numbers.shown:
		words.append(label.text)
	equal("a block, a miss, a dodge and a graded press show their words", words,
		[tr("ui.combat.pop.blocked"), tr("ui.combat.pop.missed"), tr("ui.combat.pop.dodged"), tr("ui.combat.pop.grade.perfect")] as Array[String])
	numbers._process(HitNumbers.LIFE + 0.1)
	_body(&"fixture_pop_turns", false, Vector3.ZERO)
	Events.combatant_damaged.emit(&"fixture_pop_turns", &"fixture_pop_foe", 5, false)
	equal("a fighter that is not real-time shows nothing here", numbers.shown.size(), 0)
	_grades()
	numbers.free()
	for body: Node in _bodies:
		body.free()


func _grades() -> void:
	var window := TimedWindow.new()
	window.opens = 0.3
	window.closes = 0.5
	window.perfect = 0.06
	equal("a press is graded perfect in the centre, good in the window and a miss outside",
		[window.grade(0.4), window.grade(0.32), window.grade(0.6)], [&"perfect", &"good", &"miss"])


func _body(id: StringName, real_time: bool, at: Vector3) -> Node3D:
	var body := Node3D.new()
	body.add_child(Vitals.new())
	body.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = id
	fighter.real_time = real_time
	fighter.base_stats = {&"max_hp": 50.0}
	body.add_child(fighter)
	body.add_child(Hurtbox.new())
	var visual := Node3D.new()
	visual.name = "Visual"
	var sprite := Sprite3D.new()
	sprite.name = "Sprite"
	sprite.modulate = Color(1, 1, 1, 0.5)
	visual.add_child(sprite)
	body.add_child(visual)
	attach(body)
	body.global_position = at
	_bodies.append(body)
	return body
