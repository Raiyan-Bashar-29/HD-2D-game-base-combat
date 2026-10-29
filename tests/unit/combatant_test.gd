extends TestCase
## `FactionTable` and `Combatant`: hostility, the four target filters, the shared sheet, and one
## request resolved and applied all the way to defeat.
##
## OWNS: assertions about who may target whom and what a hit does to its target.
## MUST NOT: name a game's factions, stats or combatants. Every name here is made up for the case.

var _damaged: int = 0
var _last_amount: int = 0
var _defeats: int = 0


func run() -> void:
	plan(24)
	SaveFixture.activate()
	Flags.clear_all()
	Events.combatant_damaged.connect(_on_damaged)
	Events.combatant_defeated.connect(_on_defeated)
	_hostility()
	_filters()
	_a_combatant_shares_its_sheet_and_id()
	_a_hit_runs_through_to_defeat()
	Events.combatant_damaged.disconnect(_on_damaged)
	Events.combatant_defeated.disconnect(_on_defeated)
	Flags.clear_all()


func _hostility() -> void:
	var table := FactionTable.new()
	equal("different factions are hostile by default", table.is_hostile(&"side_a", &"side_b"), true)
	equal("a faction is not hostile to itself", table.is_hostile(&"side_a", &"side_a"), false)
	table.exceptions = PackedStringArray(["side_a:side_b", "side_c:side_c"])
	equal("a listed pair is at peace", table.is_hostile(&"side_a", &"side_b"), false)
	equal("in both directions", table.is_hostile(&"side_b", &"side_a"), false)
	equal("a faction listed with itself fights itself", table.is_hostile(&"side_c", &"side_c"), true)
	var peaceful := FactionTable.new()
	peaceful.different_is_hostile = false
	peaceful.exceptions = PackedStringArray(["side_a:side_b"])
	equal("a peaceful table makes only listed pairs hostile",
		peaceful.is_hostile(&"side_a", &"side_b") and not peaceful.is_hostile(&"side_a", &"side_c"), true)


func _filters() -> void:
	var table := FactionTable.new()
	var t := FactionTable.Target
	equal("SELF allows the user", table.allows(t.SELF, &"user", &"side_a", &"user", &"side_a"), true)
	equal("SELF refuses an ally", table.allows(t.SELF, &"user", &"side_a", &"friend", &"side_a"), false)
	equal("ALLY allows the user", table.allows(t.ALLY, &"user", &"side_a", &"user", &"side_a"), true)
	equal("ALLY allows a friend", table.allows(t.ALLY, &"user", &"side_a", &"friend", &"side_a"), true)
	equal("ALLY refuses a foe", table.allows(t.ALLY, &"user", &"side_a", &"foe", &"side_b"), false)
	equal("ENEMY allows a foe", table.allows(t.ENEMY, &"user", &"side_a", &"foe", &"side_b"), true)
	equal("ENEMY refuses a friend", table.allows(t.ENEMY, &"user", &"side_a", &"friend", &"side_a"), false)
	equal("ENEMY never allows the user", table.allows(t.ENEMY, &"user", &"side_c", &"user", &"side_c"), false)
	equal("ANY allows a foe", table.allows(t.ANY, &"user", &"side_a", &"foe", &"side_b"), true)


func _actor(id: StringName, side: StringName) -> Node:
	var actor := Node.new()
	var vitals := Vitals.new()
	actor.add_child(vitals)
	var statuses := StatusSet.new()
	statuses.save_id = StringName("statuses/" + String(id))
	actor.add_child(statuses)
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = side
	combatant.formula = DamageFormula.new()
	combatant.formula.stages = [AttackDefenceStage.new()]
	actor.add_child(combatant)
	attach(actor)
	return actor


func _a_combatant_shares_its_sheet_and_id() -> void:
	var actor := _actor(&"fixture_one", &"side_a")
	var combatant := Combatant.of(actor)
	equal("its Vitals uses its sheet", Vitals.of(actor).sheet == combatant.sheet, true)
	equal("its StatusSet speaks with its id", StatusSet.of(actor).owner_id, &"fixture_one")
	actor.free()


func _a_hit_runs_through_to_defeat() -> void:
	Flags.clear_all()
	var striker := _actor(&"fixture_striker", &"side_a")
	var target := _actor(&"fixture_target", &"side_b")
	var attacker := Combatant.of(striker)
	var defender := Combatant.of(target)
	attacker.sheet.set_base(&"attack", 10.0)
	defender.sheet.set_base(&"max_hp", 30.0)
	var rng := RandomNumberGenerator.new()
	equal("the attacker may target the defender as an ENEMY", attacker.can_target(defender, FactionTable.Target.ENEMY), true)
	_damaged = 0
	_defeats = 0
	attacker.hit(defender, 5.0, &"", rng)
	equal("(5 + 10) came off the defender", Vitals.of(target).current(&"hp"), 15)
	equal("and was announced with its amount", _damaged == 1 and _last_amount == 15, true)
	var guard := StatusEffect.new()
	guard.id = &"status/fixture_guard"
	guard.modifiers = [StatModifier.of(&"defence", StatModifier.Op.ADD, 100.0, &"")]
	StatusSet.of(target).apply(guard)
	attacker.hit(defender, 5.0, &"", rng)
	equal("a status's defence on the shared sheet halves the next hit", Vitals.of(target).current(&"hp"), 7)
	StatusSet.of(target).cure(guard.id)
	attacker.hit(defender, 5.0, &"", rng)
	equal("the hit that reaches zero is defeat", Vitals.of(target).is_defeated() and _defeats == 1, true)
	var before: int = _damaged
	equal("a defeated combatant receives nothing", defender.receive(attacker.hit(defender, 5.0, &"", rng), &"fixture_striker"), 0)
	equal("and nothing is announced", _damaged, before)
	striker.free()
	target.free()


func _on_damaged(_who: StringName, _by: StringName, amount: int, _critical: bool) -> void:
	_damaged += 1
	_last_amount = amount


func _on_defeated(_who: StringName) -> void:
	_defeats += 1
