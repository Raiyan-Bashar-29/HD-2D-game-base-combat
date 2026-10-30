extends TestCase
## The field HUD (C3.9): hidden for a body that is not a fighter; for a fighter, its hp, every
## other pool and its statuses; redrawn by events, never polled; and a second line for the
## locked target, gone when the lock is let go.
##
## OWNS: assertions about `CombatHud`.
## MUST NOT: name a game's fighters or statuses, or depend on a live player: `subject` is set.

var _actors: Array[Node] = []


func run() -> void:
	plan(8)
	SaveFixture.activate()
	Flags.clear_all()
	var hud := CombatHud.new()
	attach(hud)
	var plain := Node.new()
	attach(plain)
	_actors.append(plain)
	hud.subject = plain
	hud.refresh()
	equal("a body that is not a fighter shows nothing", [hud.visible, hud.text], [false, ""])
	var hero := _actor(&"fixture_hero", {&"max_hp": 30.0, &"max_mp": 10.0})
	hud.subject = hero
	hud.refresh()
	equal("a fighter shows its hp", [hud.visible, hud.text.begins_with(_hp(30, 30))], [true, true])
	equal("and every other pool", hud.text.contains(_pool("MP", 10, 10)), true)
	Vitals.of(hero).change(&"hp", -5)
	equal("a pool moving redraws it, with no call", hud.text.begins_with(_hp(25, 30)), true)
	var sting := StatusEffect.new()
	sting.id = &"status/fixture_sting"
	StatusSet.of(hero).apply(sting)
	equal("a status starting shows it", hud.text.contains("fixture_sting"), true)
	var foe := _actor(&"fixture_brute/one", {&"max_hp": 20.0})
	Combatant.of(foe).kind = &"fixture_brute"
	Vitals.of(foe).change(&"hp", -8)
	Events.lock_on_changed.emit(&"fixture_hero", &"fixture_brute/one")
	equal("locking on adds the target's name and hp", hud.text.get_slice("\n", 1),
		tr(CombatHud.TARGET_KEY).format({"name": "fixture_brute", "hp": 12, "max": 20}))
	Events.lock_on_changed.emit(&"fixture_hero", &"")
	equal("letting go removes it", hud.text.contains("\n"), false)
	hud.subject = plain
	hud.refresh()
	equal("and it hides again for a body that is not a fighter", hud.visible, false)
	hud.free()
	for actor: Node in _actors:
		actor.free()
	Flags.clear_all()


func _actor(id: StringName, stats: Dictionary[StringName, float]) -> Node3D:
	var actor := Node3D.new()
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.base_stats = stats
	actor.add_child(combatant)
	actor.add_child(Hurtbox.new())
	attach(actor)
	_actors.append(actor)
	return actor


func _hp(hp: int, most: int) -> String:
	return tr(CombatHud.HP_KEY).format({"hp": hp, "max": most})


func _pool(pool: String, current: int, most: int) -> String:
	return tr(CombatHud.POOL_KEY).format({"pool": pool, "current": current, "max": most})
