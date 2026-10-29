extends TestCase
## `Vitals`: pools clamped to a sheet's maximum, the defeat edge, revive, and surviving a save.
##
## OWNS: assertions about one combatant's pools and its defeat edge.
## MUST NOT: name a game's pools beyond the default `hp`, or compute damage.

const WHO: StringName = &"fixture_combatant"
const POOL_B: StringName = &"pool_b"

var _changes: int = 0
var _defeats: int = 0
var _revives: int = 0


func run() -> void:
	plan(21)
	SaveFixture.activate()
	Flags.clear_all()
	Events.vitals_changed.connect(_on_changed)
	Events.combatant_defeated.connect(_on_defeated)
	Events.combatant_revived.connect(_on_revived)
	_an_unhurt_combatant_is_full()
	_values_clamp_and_only_real_changes_announce()
	_defeat_fires_once()
	_a_defeated_combatant_is_revived_not_healed()
	_vitals_survive_a_save()
	Events.vitals_changed.disconnect(_on_changed)
	Events.combatant_defeated.disconnect(_on_defeated)
	Events.combatant_revived.disconnect(_on_revived)
	Flags.clear_all()


func _vitals() -> Vitals:
	var made := Vitals.new()
	made.owner_id = WHO
	made.sheet.set_base(&"max_hp", 20.0)
	made.sheet.set_base(StringName("max_" + String(POOL_B)), 5.0)
	return made


func _an_unhurt_combatant_is_full() -> void:
	var vitals := _vitals()
	equal("an unset pool is at its maximum", vitals.current(&"hp"), 20)
	equal("and nothing was written to get there", Flags.has_flag(vitals.key(&"hp")), false)
	equal("the key is vital/<who>/<pool>", vitals.key(&"hp"), &"vital/fixture_combatant/hp")
	vitals.sheet.add(StatModifier.of(&"max_hp", StatModifier.Op.ADD, 10.0, &"fixture_source"))
	equal("the maximum is the sheet's, modifiers included", vitals.maximum(&"hp"), 30)
	vitals.free()


func _values_clamp_and_only_real_changes_announce() -> void:
	Flags.clear_all()
	var vitals := _vitals()
	_changes = 0
	equal("damage lowers the pool", vitals.change(&"hp", -7), 13)
	equal("healing past the maximum stops at it", vitals.change(&"hp", 100), 20)
	equal("a second pool is independent", vitals.change(POOL_B, -2), 3)
	equal("each real change announced once", _changes, 3)
	vitals.change(&"hp", 5)
	equal("a change that changes nothing says nothing", _changes, 3)
	equal("the value is the flag a gate reads", Flags.get_int(vitals.key(&"hp")), 20)
	vitals.free()


func _defeat_fires_once() -> void:
	Flags.clear_all()
	var vitals := _vitals()
	_defeats = 0
	equal("not defeated while above zero", vitals.is_defeated(), false)
	equal("overkill stops at zero", vitals.change(&"hp", -500), 0)
	equal("reaching zero is defeat", vitals.is_defeated(), true)
	vitals.change(&"hp", -5)
	equal("defeat is announced once, however hard it is hit", _defeats, 1)
	equal("draining another pool to zero is not defeat", vitals.change(POOL_B, -50) == 0
		and _defeats == 1, true)
	vitals.free()


func _a_defeated_combatant_is_revived_not_healed() -> void:
	Flags.clear_all()
	var vitals := _vitals()
	_revives = 0
	vitals.change(&"hp", -20)
	equal("a heal does not lift a defeated combatant", vitals.change(&"hp", 10), 0)
	equal("revive does", vitals.revive(5), true)
	equal("to the amount asked", vitals.current(&"hp"), 5)
	equal("and is announced", _revives, 1)
	equal("reviving the living is refused", vitals.revive(5), false)
	vitals.free()


func _vitals_survive_a_save() -> void:
	Flags.clear_all()
	var vitals := _vitals()
	vitals.change(&"hp", -8)
	var slot: int = 3
	SaveSystem.save_to_slot(slot)
	vitals.change(&"hp", 8)
	SaveSystem.load_from_slot(slot)
	equal("the hurt value came back from the save", vitals.current(&"hp"), 12)
	SaveSystem.delete_slot(slot)
	vitals.free()


func _on_changed(_who: StringName, _pool: StringName, _value: int, _maximum: int) -> void:
	_changes += 1


func _on_defeated(_who: StringName) -> void:
	_defeats += 1


func _on_revived(_who: StringName) -> void:
	_revives += 1
