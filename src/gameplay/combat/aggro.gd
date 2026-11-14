class_name Aggro
extends Node
## Who a foe picks (C8.6): a threat table and taunts.
##
## IN PLAIN WORDS:
## - This node sits on a fighter's body (an `ActionEnemy` adds one). Each hit its owner takes
##   adds threat to the attacker: the damage times 1 plus the attacker's `threat` stat. Gear, a
##   passive or a status can raise that stat (a tank) or lower it (a sneak). Threat fades by
##   `fade` points a second.
## - A TAUNT is any status tagged `taunt` on a fighter. While it is held, every foe that could
##   attack the holder must pick the holder.
## - `pick` orders the choice in the field: a taunting fighter in reach first (the nearest of
##   them), then the one with the most threat, then the nearest.
## - `narrow` is the same taunt rule for a turn battle: a brain aiming at foes may only aim at
##   the taunting ones.
##
## OWNS: one fighter's threat table, and the two picking rules.
## MUST NOT: move the body, land a hit, or apply a status; a taunt is given by a skill's status.

## The stat that scales the threat a fighter's hits make. 0 is normal; -1 makes none.
const STAT: StringName = &"threat"
## The status tag that marks its holder as taunting.
const TAG: StringName = &"taunt"

## Threat points lost each second, by every attacker on the table.
var fade: float = 1.0
## Threat by attacker id.
var threat: Dictionary[StringName, float] = {}


func _ready() -> void:
	Events.combatant_damaged.connect(_on_damaged)


func _exit_tree() -> void:
	if Events.combatant_damaged.is_connected(_on_damaged):
		Events.combatant_damaged.disconnect(_on_damaged)


## The `Aggro` on `body`, or null.
static func of(body: Node) -> Aggro:
	if body == null:
		return null
	for child: Node in body.get_children():
		if child is Aggro:
			return child as Aggro
	return null


## `seconds` of fight time passed: every attacker's threat fades, and an empty row is dropped.
func pass_time(seconds: float) -> void:
	for id: StringName in threat.keys():
		threat[id] -= fade * seconds
		if threat[id] <= 0.0:
			threat.erase(id)


## The threat `id` holds on this fighter, 0 when none.
func toward(id: StringName) -> float:
	return threat.get(id, 0.0)


## True while `fighter` holds a status tagged `taunt`.
static func taunting(fighter: Combatant) -> bool:
	var statuses: StatusSet = StatusSet.of(fighter.get_parent()) if fighter != null else null
	if statuses == null:
		return false
	for effect: StatusEffect in statuses.held():
		if effect.tags.has(TAG):
			return true
	return false


## The standing hurtbox `body`'s fighter should attack, or null: within `reach` metres a
## taunting fighter first, then the most threat; failing both, the nearest at any distance.
static func pick(body: Node3D, reach: float = INF) -> Hurtbox:
	var me: Combatant = Combatant.of(body)
	if me == null or not body.is_inside_tree():
		return null
	var table: Aggro = Aggro.of(body)
	var best: Hurtbox = null
	var best_score: float = -INF
	for node: Node in body.get_tree().get_nodes_in_group(Hurtbox.GROUP):
		var hurtbox: Hurtbox = node as Hurtbox
		if hurtbox == null or not me.can_target(hurtbox.fighter(), FactionTable.Target.ENEMY):
			continue
		var vitals: Vitals = Vitals.of(hurtbox.get_parent())
		if vitals != null and vitals.is_defeated():
			continue
		var distance: float = body.global_position.distance_to(hurtbox.global_position)
		# Nearer always wins a tie; a rank of threat or a taunt outweighs any distance.
		var score: float = -distance
		if distance <= reach:
			if taunting(hurtbox.fighter()):
				score += 2000000.0
			elif table != null and table.toward(hurtbox.fighter().combatant_id) > 0.0:
				score = 1000000.0 + table.toward(hurtbox.fighter().combatant_id)
		if score > best_score:
			best = hurtbox
			best_score = score
	return best


## `legal` cut down to the taunting foes of `actor`, when there are any; otherwise `legal`.
static func narrow(actor: Combatant, legal: Array[Combatant]) -> Array[Combatant]:
	var taunters: Array[Combatant] = []
	for fighter: Combatant in legal:
		if actor != null and actor.can_target(fighter, FactionTable.Target.ENEMY) and taunting(fighter):
			taunters.append(fighter)
	return legal if taunters.is_empty() else taunters


func _on_damaged(who: StringName, by: StringName, amount: int, _critical: bool) -> void:
	var mine: Combatant = Combatant.of(get_parent())
	if mine == null or who != mine.combatant_id or by == &"" or amount <= 0:
		return
	var attacker: Combatant = Combatant.find(get_tree(), by)
	var rate: float = 1.0 + (attacker.sheet.value(STAT) if attacker != null else 0.0)
	if rate > 0.0:
		threat[by] = toward(by) + float(amount) * rate
