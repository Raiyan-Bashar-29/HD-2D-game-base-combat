extends TestCase
## The HUD says more (C10.13): the locked target's line shows its shield; a deadly status shows
## its count; a steal, a capture and a broken piece each send their event and a toast; the
## battle log names a steal.
##
## OWNS: assertions about the HUD's target pools and doom count, `CombatNotes`, and the steal,
## capture and break events.
## MUST NOT: name a game's fighters or items. Every name here is made up for the case.

var _actors: Array[Node] = []
var _toasts: Array[String] = []


func run() -> void:
	plan(4)
	SaveFixture.activate()
	Fixtures.activate()
	Flags.clear_all()
	var hud := CombatHud.new()
	attach(hud)
	var hero: Node3D = _actor(&"fixture_more_hero", {&"max_hp": 30.0})
	var foe: Node3D = _actor(&"fixture_more_foe", {&"max_hp": 20.0, &"max_shield": 4.0})
	Vitals.of(foe).change(&"shield", -2)
	hud.subject = hero
	Events.lock_on_changed.emit(&"fixture_more_hero", &"fixture_more_foe")
	equal("the target's line shows its shield", hud.text.get_slice("\n", 1).contains(
		tr(CombatHud.POOL_KEY).format({"pool": CombatNames.pool(&"shield"), "current": 2, "max": 4})), true)
	var doom := StatusEffect.new()
	doom.id = &"status/fixture_more_doom"
	doom.name_key = "fixture.doom"
	doom.unit = StatusEffect.Unit.TURNS
	doom.duration = 3.0
	doom.fatal = true
	StatusSet.of(hero).apply(doom)
	equal("a deadly status shows its count", hud.text.contains(tr(CombatHud.DOOM_KEY).format({"name": tr("fixture.doom"), "left": 3})), true)
	_notes(hero, foe)
	hud.free()
	for actor: Node in _actors:
		actor.free()
	Flags.clear_all()


func _notes(hero: Node3D, foe: Node3D) -> void:
	var notes := CombatNotes.new()
	attach(notes)
	Events.notify_requested.connect(_on_toast)
	var thief: Combatant = Combatant.of(hero)
	var mark: Combatant = Combatant.of(foe)
	var line := LootEntry.new()
	line.item_id = FixtureContent.STACK_ITEM
	mark.steal_table = LootTable.new()
	mark.steal_table.entries = [line]
	mark.capture_item = FixtureContent.UNIQUE_ITEM
	var rng := RandomNumberGenerator.new()
	Pilfer.steal(thief, mark, 1.0, rng)
	Vitals.of(foe).change(&"hp", -19)
	# Twice the chance, so the roll always lands on a foe at 1 hp.
	Pilfer.capture(thief, mark, 2.0, rng)
	Events.gear_broke.emit(thief.combatant_id, FixtureContent.WORN_ITEM)
	Events.notify_requested.disconnect(_on_toast)
	equal("a steal, a capture and a broken piece each get a toast", _toasts, [
		tr(CombatNotes.STOLEN_KEY).format({"item": _name(FixtureContent.STACK_ITEM)}),
		tr(CombatNotes.CAPTURED_KEY).format({"item": _name(FixtureContent.UNIQUE_ITEM)}),
		tr(CombatNotes.BROKE_KEY).format({"item": _name(FixtureContent.WORN_ITEM)})] as Array[String])
	notes.free()
	var battle := Battle.new([thief], [mark], null, rng)
	var log := BattleLog.new(battle, func(fighter: Combatant) -> String: return String(fighter.combatant_id))
	log.start()
	Events.item_stolen.emit(&"fixture_more_hero", &"fixture_more_foe", FixtureContent.STACK_ITEM)
	log.stop()
	equal("the battle log names a steal", log.lines, [tr(BattleLog.STOLEN_KEY).format({"name": "fixture_more_hero",
		"from": "fixture_more_foe", "item": _name(FixtureContent.STACK_ITEM)})] as Array[String])


func _name(item_id: StringName) -> String:
	return tr(ItemDb.definition(item_id).name_key)


func _actor(id: StringName, stats: Dictionary[StringName, float]) -> Node3D:
	var actor := Node3D.new()
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	actor.add_child(Inventory.new())
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.base_stats = stats
	actor.add_child(combatant)
	actor.add_child(Hurtbox.new())
	attach(actor)
	_actors.append(actor)
	return actor


func _on_toast(key: String, _seconds: float, args: Dictionary) -> void:
	_toasts.append(tr(key).format(args))
