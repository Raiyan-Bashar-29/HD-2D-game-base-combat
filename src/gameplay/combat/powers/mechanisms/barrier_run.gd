class_name BarrierRun
extends FormRun
## Runs an M3 barrier (C6.6a) on one fighter, the same in the field and in a battle. Its settings
## are a `BarrierMechanism`; read its header for the rules, in order.
##
## IN PLAIN WORDS: it is a form (`FormRun` does the entering, leaving, group and upkeep), plus
## one thing: `intercept_incoming`, which `Combatant.receive` reaches through `PowerSet.guard`
## just before a hit lands on this fighter or on one of its allies. While the barrier is up it
## lets a bypassing hit through, drinks an absorbed element into a pool, pays its cost per block
## (and comes down when it cannot), and then nullifies or reduces the hit.
##
## A TIMED BLOCK (C6.6b) also counts how long the guard has been up (`_held`: seconds in the
## field, the guard's own turns in a battle), from 0 each time it is raised. A hit that arrives
## inside the mechanism's `timing` is stopped whole, free, and stored; a later one is a paid,
## reduced block.
##
## OWNS: what one barrier does to one incoming hit.
## MUST NOT: name a character, apply the hit itself, or guard an enemy.

# How long the guard has been up since it was last raised: seconds, or turns in a battle.
var _held: float = 0.0


func use(user: Combatant, targets: Array[Combatant], rng: RandomNumberGenerator) -> void:
	super.use(user, targets, rng)
	_held = 0.0


func tick(amount: float) -> void:
	super.tick(amount)
	if stage >= 0:
		_held += amount


## True while the barrier guards: its form is held, or it has no status and is always up.
func up() -> bool:
	var barrier: BarrierMechanism = mechanism as BarrierMechanism
	if barrier.status == null and barrier.cycle.is_empty():
		return true
	_sync()
	return stage >= 0


func intercept_incoming(target: Combatant, result: DamageResult, _from: StringName) -> void:
	var barrier: BarrierMechanism = mechanism as BarrierMechanism
	var body: Node = holder.get_parent() if holder != null else null
	var me: Combatant = Combatant.of(body)
	var vitals: Vitals = Vitals.of(body)
	# A heal, a hit already stopped, or a fallen guard: nothing to do.
	if me == null or vitals == null or vitals.is_defeated() or result.amount <= 0.0 or result.blocked:
		return
	if (target != me and barrier.scope != BarrierMechanism.Scope.ALLIES) or not up():
		return
	for tag: StringName in result.tags:
		if barrier.bypass_tags.has(tag):
			return
	if result.element != &"" and barrier.absorb_elements.has(result.element):
		vitals.change(barrier.store_pool, result.total())
		_stop(result)
		return
	if barrier.mode == BarrierMechanism.Mode.TIMED_BLOCK and _perfect(me):
		if barrier.store_pool != &"":
			vitals.change(barrier.store_pool, result.total())
		_stop(result)
		return
	if barrier.cost_per_block > 0:
		if vitals.current(barrier.cost_pool) < barrier.cost_per_block:
			# It cannot be paid for: the barrier comes down, and this hit lands whole.
			leave()
			return
		vitals.change(barrier.cost_pool, -barrier.cost_per_block)
	if barrier.mode == BarrierMechanism.Mode.NULLIFY:
		_stop(result)
	else:
		result.amount *= barrier.factor


# True when a timed block was raised just before this hit: inside `timing` in the field, and
# before the guard's own next turn in a battle.
func _perfect(me: Combatant) -> bool:
	var timing: TimedWindow = (mechanism as BarrierMechanism).timing
	if not me.real_time:
		return _held < 1.0
	return timing != null and timing.inside(_held)


func _stop(result: DamageResult) -> void:
	result.amount = 0.0
	result.blocked = true
