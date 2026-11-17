class_name CloneRun
extends PowerExecutor
## Runs a clone (C6.13a) on one fighter. Its settings are a `CloneMechanism`; read its header
## for what the fields mean.
##
## IN PLAIN WORDS: in the field, a use makes one `CloneGhost` as a sibling of the user's body
## (an old one goes first) and tells it each move the user starts (`moved`). The ghost goes by
## itself when its lifetime ends; this sends it away when the user falls, the kit comes off
## (`end`) or the area is left.
## IN A BATTLE (C6.13b): a use arms `actions` of the user's turns. Each of those turns (`tick`
## comes at the start of the user's turn there) is live, and while it is, each
## `combatant_damaged` the user causes is answered by `power_fraction` of it again on the same
## fighter, announced the same way. The echo does not echo.
##
## OWNS: the ghost this power has out.
## MUST NOT: play the ghost's moves (it does), or name a character.

var _ghost: CloneGhost
var _armed: int = 0
var _live: bool = false
var _echoing: bool = false


func use(user: Combatant, _targets: Array[Combatant], _rng: RandomNumberGenerator) -> void:
	var body: Node3D = user.get_parent() as Node3D
	if not user.real_time:
		_armed = (mechanism as CloneMechanism).actions
		_live = false
		if not Events.combatant_damaged.is_connected(_on_damaged):
			Events.combatant_damaged.connect(_on_damaged)
		return
	if body == null or not body.is_inside_tree():
		return
	_clear()
	var clone: CloneMechanism = mechanism as CloneMechanism
	var ghost := CloneGhost.new()
	ghost.source = body
	ghost.attacker = user
	ghost.delay = clone.delay
	ghost.lifetime = clone.lifetime
	ghost.power_fraction = clone.power_fraction
	ghost.tint = clone.tint
	body.get_parent().add_child(ghost)
	ghost.global_position = body.global_position
	_ghost = ghost
	if not Events.combatant_defeated.is_connected(_on_defeated):
		Events.combatant_defeated.connect(_on_defeated)
		Events.area_unloading.connect(_on_area_left)


## A turn of the user's started (in a battle): it is doubled while any armed turn is left.
func tick(_amount: float) -> void:
	if Battle.running == null:
		_live = false
		_armed = 0
		return
	_live = _armed > 0
	_armed = maxi(0, _armed - 1)


## The user started a move: the ghost plays it after its delay.
func moved(move: ActionMove) -> void:
	if is_instance_valid(_ghost) and not _ghost.is_queued_for_deletion():
		_ghost.echo(move)


## The kit came off: the ghost goes.
func end() -> void:
	_clear()
	_armed = 0
	_live = false


func _on_damaged(who: StringName, by: StringName, amount: int, _critical: bool) -> void:
	var me: Combatant = Combatant.of(holder.get_parent()) if is_instance_valid(holder) else null
	var battle: Battle = Battle.running
	if not _live or _echoing or me == null or by != me.combatant_id or amount <= 0 or battle == null:
		return
	var again: int = roundi(amount * (mechanism as CloneMechanism).power_fraction)
	for one: Combatant in battle.party + battle.enemies:
		if one.combatant_id == who and again > 0:
			_echoing = true
			Vitals.of(one.get_parent()).change(Vitals.of(one.get_parent()).defeat_pool, -again)
			Events.combatant_damaged.emit(who, by, again, false)
			_echoing = false
			return


func _clear() -> void:
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null


func _on_area_left(_area_id: StringName) -> void:
	_clear()


func _on_defeated(who: StringName) -> void:
	var me: Combatant = Combatant.of(holder.get_parent()) if is_instance_valid(holder) else null
	if me != null and who == me.combatant_id:
		_clear()
