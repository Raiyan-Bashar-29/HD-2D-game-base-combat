class_name OwnedFighter
extends ActionEnemy
## A fighter a power brought onto its user's side (C8.10a): a helper beside its maker, a
## raised soldier beside his. `scenes/objects/owned_fighter.tscn` is its prefab, and
## `SummonRun` is the only thing that makes one.
##
## IN PLAIN WORDS: it is an `ActionEnemy` in every way (body, brain, moves, hits, falls), with
## three differences:
## - its side is its owner's (`Combatant.side()` when it is made), so it fights the owner's
##   foes and is fought by them;
## - its home is wherever its owner stands, so with no foe near it follows the owner;
## - it gives no reward and leaves no flag when it falls.
## It knows its owner (`owner_body`) and the power that made it (`power_id`). An `untouchable`
## one takes its hurtbox out of play, so nothing hits it and no foe picks it. It counts the
## moves it has started (`moves_done`) for a run that sends it away after so many (C8.10c).
##
## OWNS: being on someone's side and following them.
## MUST NOT: decide when it leaves (`SummonRun` does), or be saved (C8.10e).

const GROUP: StringName = &"owned_fighters"

## The body of the fighter it fights for, and the power that made it.
var owner_body: Node3D
var power_id: StringName = &""
## Set before it enters the tree: nothing can hit it, and no foe picks it.
var untouchable: bool = false
## Moves it has started so far.
var moves_done: int = 0


func _ready() -> void:
	grants_reward = false
	remember_defeat = false
	super._ready()
	add_to_group(GROUP)
	var mine: Combatant = Combatant.of(self)
	var lord: Combatant = Combatant.of(owner_body) if is_instance_valid(owner_body) else null
	if mine != null and lord != null:
		mine.faction = lord.side()
	if untouchable:
		for child: Node in get_children():
			var hurtbox: Hurtbox = child as Hurtbox
			if hurtbox != null:
				hurtbox.remove_from_group(Hurtbox.GROUP)
				hurtbox.monitorable = false


## Home follows the owner before each think, so walking home is walking to the owner.
func act(delta: float) -> ActionDecider.State:
	if is_instance_valid(owner_body):
		home = owner_body.global_position
	var was_busy: bool = timeline.busy()
	var state: ActionDecider.State = super.act(delta)
	if not was_busy and timeline.busy():
		moves_done += 1
	return state


## True while no move is playing.
func idle() -> bool:
	return not timeline.busy()


## Every owned fighter in `tree` still standing and not leaving: the ones a battle that opens
## now takes along (C8.10d).
static func standing(tree: SceneTree) -> Array[OwnedFighter]:
	var out: Array[OwnedFighter] = []
	for node: Node in tree.get_nodes_in_group(GROUP):
		var one: OwnedFighter = node as OwnedFighter
		var vitals: Vitals = Vitals.of(one) if one != null else null
		if one != null and not one.is_queued_for_deletion() and vitals != null and not vitals.is_defeated():
			out.append(one)
	return out


## Sent away at once: its time ran out, its owner fell, or a newer one took its place.
func dismiss() -> void:
	if not is_queued_for_deletion():
		queue_free()
