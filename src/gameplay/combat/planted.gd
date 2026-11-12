class_name Planted
extends Hitbox
## One plant in the ground (C6.26): a `Hitbox` that waits, then goes off. `PlantRun` plants them
## for an M15 plant (`PlantMechanism`); read its header for the triggers.
##
## IN PLAIN WORDS: a plant lies still where it was put, striking nothing, until it is set off:
## by its owner (`set_off`, the REMOTE trigger), by a foe coming within `radius` (PROXIMITY), by
## its `seconds` running out (TIMER), or by a foe within `radius` being hit by anyone (ON_HIT).
## Set off, it waits its fuse (a ripple's delay), then plays its `eruption` move on a clock of
## its own, striking each fighter it overlaps once, exactly as a swing does (`Hurtbox.take`
## decides what the hit does). When the eruption is over it is gone. A plant left waiting past
## `life` seconds is lost without going off (0 waits for ever).
##
## It runs on fight time (`CombatClock`), so a stopped fight holds every plant and fuse.
##
## OWNS: one plant's waiting, its fuse and its eruption.
## MUST NOT: decide what a hit does (the `Hurtbox` does), or choose where plants go (`PlantRun`).

## Every plant joins this group, so a test or a debug overlay can find them.
const GROUP: StringName = &"combat_plants"

var trigger: PlantMechanism.Trigger = PlantMechanism.Trigger.REMOTE
## PROXIMITY and ON_HIT: how near a foe must be, in metres.
var radius: float = 1.5
## TIMER: seconds left before it goes off by itself.
var seconds: float = 0.0
## Seconds left before it is lost; 0 waits for ever.
var life: float = 0.0

var _eruption: ActionMove
## Seconds until it erupts once set off; below 0 while still waiting.
var _fuse: float = -1.0
var _gone: bool = false


func _ready() -> void:
	super._ready()
	add_to_group(GROUP)
	if not Events.combatant_damaged.is_connected(_on_damaged):
		Events.combatant_damaged.connect(_on_damaged)


func _exit_tree() -> void:
	if Events.combatant_damaged.is_connected(_on_damaged):
		Events.combatant_damaged.disconnect(_on_damaged)


func _physics_process(delta: float) -> void:
	watch(CombatClock.scaled(delta))


## Readies the plant to play `eruption` when it goes off, and shapes its box. Call before adding.
func plant(eruption: ActionMove) -> void:
	_eruption = eruption
	fit(eruption)


## Sets the plant off: it erupts after `delay` seconds. False when it is not waiting any more.
func set_off(delay: float = 0.0) -> bool:
	if not armed():
		return false
	_fuse = maxf(0.0, delay)
	return true


## True while it waits to be set off.
func armed() -> bool:
	return not _gone and _fuse < 0.0 and timeline == null


## True once it has erupted or been lost.
func gone() -> bool:
	return _gone


## `dt` seconds of fight time pass: a waiting plant watches its trigger and its life, a fuse
## burns, and an eruption plays and strikes what it overlaps.
func watch(dt: float) -> void:
	if _gone:
		return
	if timeline != null:
		timeline.step(dt)
		if not timeline.busy() or timeline.phase == MoveTimeline.Phase.RECOVERY:
			_end()
		else:
			sweep()
		return
	if _fuse >= 0.0:
		_fuse -= dt
		if _fuse <= 0.0:
			_erupt()
		return
	if life > 0.0:
		life -= dt
		if life <= 0.0:
			_end()
			return
	if trigger == PlantMechanism.Trigger.TIMER:
		seconds -= dt
		if seconds <= 0.0:
			_erupt()
	elif trigger == PlantMechanism.Trigger.PROXIMITY and _foe_near(null):
		_erupt()


# Starts the eruption at once.
func _erupt() -> void:
	_fuse = 0.0
	timeline = MoveTimeline.new()
	timeline.start(_eruption)


# True when a standing foe of the planter is within `radius`; with `only`, that foe alone.
func _foe_near(only: Combatant) -> bool:
	if attacker == null or not is_inside_tree():
		return false
	for node: Node in get_tree().get_nodes_in_group(Hurtbox.GROUP):
		var hurtbox: Hurtbox = node as Hurtbox
		var foe: Combatant = hurtbox.fighter() if hurtbox != null else null
		if foe == null or (only != null and foe != only):
			continue
		var vitals: Vitals = Vitals.of(hurtbox.get_parent())
		if vitals == null or vitals.is_defeated() or not attacker.can_target(foe, FactionTable.Target.ENEMY):
			continue
		var gap: Vector3 = hurtbox.global_position - global_position
		if Vector2(gap.x, gap.z).length() <= radius:
			return true
	return false


# ON_HIT: a foe within reach was hit by anyone, so this goes off.
func _on_damaged(who: StringName, _by: StringName, amount: int, _critical: bool) -> void:
	if trigger != PlantMechanism.Trigger.ON_HIT or amount <= 0 or not armed():
		return
	var struck: Combatant = Combatant.find(get_tree(), who)
	if struck != null and _foe_near(struck):
		_erupt()


func _end() -> void:
	_gone = true
	queue_free()
