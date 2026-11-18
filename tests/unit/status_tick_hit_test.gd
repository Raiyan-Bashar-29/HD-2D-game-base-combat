extends TestCase
## Status ticks that land like hits (C10.10): with `tick_as_hit` a poison tick grows by the
## holder's `damage_taken` and is announced as a hit by its applier; an invincible holder takes
## none; it wakes a sleeper; without the mark it is the plain change it always was.
##
## OWNS: assertions about `StatusEffect.tick_as_hit` and `StatusTicks`.
## MUST NOT: name a game's statuses or fighters. Every name here is made up.

var _actors: Array[Node] = []
var _heard: Array = []


func run() -> void:
	plan(4)
	SaveFixture.activate()
	Flags.clear_all()
	Events.combatant_damaged.connect(_on_damaged)
	_as_a_hit()
	_plain()
	Events.combatant_damaged.disconnect(_on_damaged)
	for actor: Node in _actors:
		actor.free()
	Flags.clear_all()


func _fighter(id: StringName, stats: Dictionary[StringName, float]) -> Combatant:
	var actor := Node.new()
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = id
	fighter.base_stats = stats
	actor.add_child(fighter)
	attach(actor)
	_actors.append(actor)
	return fighter


func _poison(as_hit: bool) -> StatusEffect:
	var made := StatusEffect.new()
	made.id = &"status/fixture_tick_poison"
	made.unit = StatusEffect.Unit.TURNS
	made.duration = 5.0
	made.tick_pool = &"hp"
	made.tick_change = -10
	made.tick_as_hit = as_hit
	return made


func _hp(fighter: Combatant) -> int:
	return Vitals.of(fighter.get_parent()).current(&"hp")


func _as_a_hit() -> void:
	var weak: Combatant = _fighter(&"fixture_tick_weak", {&"max_hp": 100.0, &"damage_taken": 0.5})
	var statuses: StatusSet = StatusSet.of(weak.get_parent())
	var nap := StatusEffect.new()
	nap.id = &"status/fixture_tick_nap"
	nap.unit = StatusEffect.Unit.TURNS
	nap.duration = 9.0
	nap.blocks = [StatusEffect.Block.SKIP_TURN]
	nap.breaks_on_hit = true
	statuses.apply(nap)
	statuses.apply(_poison(true), null, &"fixture_tick_caster")
	_heard.clear()
	statuses.tick_turn()
	equal("a tick as a hit grows by damage_taken and is announced as a hit by its applier",
		[_hp(weak), _heard], [85, [[&"fixture_tick_weak", &"fixture_tick_caster", 15]]])
	equal("and it wakes a sleeper", statuses.stacks(nap.id), 0)
	var shining: Combatant = _fighter(&"fixture_tick_shining", {&"max_hp": 100.0})
	var guard := StatusEffect.new()
	guard.id = &"status/fixture_tick_guard"
	guard.duration = 0.0
	guard.invincible = true
	StatusSet.of(shining.get_parent()).apply(guard)
	StatusSet.of(shining.get_parent()).apply(_poison(true))
	StatusSet.of(shining.get_parent()).tick_turn()
	equal("an invincible holder takes none of it", _hp(shining), 100)


func _plain() -> void:
	var plain: Combatant = _fighter(&"fixture_tick_plain", {&"max_hp": 100.0, &"damage_taken": 0.5})
	StatusSet.of(plain.get_parent()).apply(_poison(false), null, &"fixture_tick_caster")
	_heard.clear()
	StatusSet.of(plain.get_parent()).tick_turn()
	equal("without the mark a tick is the plain change it always was, unannounced", [_hp(plain), _heard], [90, []])


func _on_damaged(who: StringName, by: StringName, amount: int, _critical: bool) -> void:
	_heard.append([who, by, amount])
